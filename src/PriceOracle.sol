// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PriceOracle
 * @notice Price oracle interface for real-world asset pricing
 * Ready for Chainlink integration
 */
interface IPriceOracle {
    function getPrice(address asset) external returns (uint256);
    function getPriceUnsafe(address asset) external returns (uint256, bool);
    function getPriceUnsafeView(address asset) external view returns (uint256, bool);
}

/**
 * @title MockPriceOracle
 * @notice Mock oracle for testing and demonstration
 * Can be replaced with Chainlink oracle in production
 */
contract MockPriceOracle is IPriceOracle {
    mapping(address => uint256) private prices;
    mapping(address => bool) private isPriceSet;
    
    address public owner;
    
    event PriceUpdated(address indexed asset, uint256 price);
    
    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /**
     * @notice Set price for an asset
     * In production, this would be called by Chainlink keeper
     */
    function setPrice(address asset, uint256 price) external onlyOwner {
        require(asset != address(0), "Invalid asset");
        require(price > 0, "Invalid price");
        prices[asset] = price;
        isPriceSet[asset] = true;
        emit PriceUpdated(asset, price);
    }

    /**
     * @notice Get price with safety check
     */
    function getPrice(address asset) external view override returns (uint256) {
        require(isPriceSet[asset], "Price not set");
        return prices[asset];
    }

    /**
     * @notice Get price with flag indicating if set
     */
    function getPriceUnsafe(address asset) external view override returns (uint256, bool) {
        return (prices[asset], isPriceSet[asset]);
    }

    /**
     * @notice View version of getPriceUnsafe for read-only calls
     */
    function getPriceUnsafeView(address asset) external view override returns (uint256, bool) {
        return (prices[asset], isPriceSet[asset]);
    }

    /**
     * @notice Batch set prices (useful for keeper operations)
     */
    function setPrices(address[] calldata assets, uint256[] calldata priceValues) external onlyOwner {
        require(assets.length == priceValues.length, "Array length mismatch");
        for (uint256 i = 0; i < assets.length; i++) {
            prices[assets[i]] = priceValues[i];
            isPriceSet[assets[i]] = true;
            emit PriceUpdated(assets[i], priceValues[i]);
        }
    }
}

/**
 * @title ChainlinkPriceOracle
 * @notice Production-ready Chainlink integration
 * Implements fallback pricing and multi-source support
 */
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    
    function decimals() external view returns (uint8);
}

contract ChainlinkPriceOracle is IPriceOracle {
    mapping(address => address) public aggregators;
    mapping(address => uint8) public decimals;
    mapping(address => uint256) public fallbackPrices;
    mapping(address => uint256) public lastPriceTTL;
    mapping(address => bool) public isStale;
    
    address public owner;
    uint256 public constant PRICE_STALENESS_THRESHOLD = 1 hours;
    
    event AggregatorSet(address indexed asset, address aggregator, uint8 decimals);
    event FallbackPriceUpdated(address indexed asset, uint256 price);
    event PriceUpdated(address indexed asset, uint256 price, uint256 timestamp, bool fromChainlink);
    event PriceStalenessDetected(address indexed asset, uint256 staledAtTimestamp, uint256 currentTime);
    event AggregatorRegistered(address indexed asset, address indexed aggregator, uint8 decimals);
    
    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /**
     * @notice Register Chainlink aggregator for asset
     */
    function setAggregator(address asset, address aggregator, uint8 assetDecimals) external onlyOwner {
        require(asset != address(0) && aggregator != address(0), "Invalid addresses");
        aggregators[asset] = aggregator;
        decimals[asset] = assetDecimals;
        emit AggregatorSet(asset, aggregator, assetDecimals);
        emit AggregatorRegistered(asset, aggregator, assetDecimals);
    }

    /**
     * @notice Set fallback price for circuit breaker
     */
    function setFallbackPrice(address asset, uint256 price) external onlyOwner {
        require(asset != address(0), "Invalid asset");
        fallbackPrices[asset] = price;
        lastPriceTTL[asset] = block.timestamp;
        emit FallbackPriceUpdated(asset, price);
        emit PriceUpdated(asset, price, block.timestamp, false);
    }

    /**
     * @notice Check staleness of aggregator feed
     * Returns (isStale, timeSinceUpdate)
     */
    function checkStaleness(address asset) external returns (bool staleness, uint256 timeSinceUpdate) {
        address aggregator = aggregators[asset];
        if (aggregator == address(0)) {
            return (false, 0);
        }
        
        try AggregatorV3Interface(aggregator).latestRoundData() returns (
            uint80,
            int256 answer,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            uint256 timeElapsed = block.timestamp - updatedAt;
            bool stale = timeElapsed > PRICE_STALENESS_THRESHOLD;
            
            if (stale && !isStale[asset]) {
                isStale[asset] = true;
                emit PriceStalenessDetected(asset, updatedAt, block.timestamp);
            } else if (!stale && isStale[asset]) {
                isStale[asset] = false;
            }
            
            return (stale, timeElapsed);
        } catch {
            return (true, 0);
        }
    }

    /**
     * @notice Get latest price from Chainlink
     */
    function getPrice(address asset) external override returns (uint256) {
        address aggregator = aggregators[asset];
        require(aggregator != address(0), "No aggregator for asset");
        
        AggregatorV3Interface oracle = AggregatorV3Interface(aggregator);
        (, int256 answer, , uint256 updatedAt, ) = oracle.latestRoundData();
        
        uint256 timeElapsed = block.timestamp - updatedAt;
        if (timeElapsed > PRICE_STALENESS_THRESHOLD) {
            if (!isStale[asset]) {
                isStale[asset] = true;
                emit PriceStalenessDetected(asset, updatedAt, block.timestamp);
            }
            revert("Price too stale");
        }
        
        require(answer > 0, "Invalid price");
        uint8 oracleDecimals = oracle.decimals();
        uint256 normalizedPrice = oracleDecimals < 18
            ? uint256(answer) * (10 ** (18 - oracleDecimals))
            : uint256(answer) / (10 ** (oracleDecimals - 18));
        
        isStale[asset] = false;
        emit PriceUpdated(asset, normalizedPrice, block.timestamp, true);
        
        return normalizedPrice;
    }

    /**
     * @notice Get price with staleness tolerance
     * Falls back to cached price if Chainlink is stale
     */
    function getPriceUnsafe(address asset) external override returns (uint256, bool) {
        address aggregator = aggregators[asset];
        if (aggregator == address(0)) {
            return (fallbackPrices[asset], fallbackPrices[asset] > 0);
        }
        
        try AggregatorV3Interface(aggregator).latestRoundData() returns (
            uint80,
            int256 answer,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            uint256 timeElapsed = block.timestamp - updatedAt;
            
            if (answer > 0 && timeElapsed <= PRICE_STALENESS_THRESHOLD) {
                uint8 oracleDecimals = AggregatorV3Interface(aggregator).decimals();
                uint256 normalizedPrice = oracleDecimals < 18 
                    ? uint256(answer) * (10 ** (18 - oracleDecimals))
                    : uint256(answer) / (10 ** (oracleDecimals - 18));
                
                isStale[asset] = false;
                emit PriceUpdated(asset, normalizedPrice, block.timestamp, true);
                return (normalizedPrice, true);
            } else if (timeElapsed > PRICE_STALENESS_THRESHOLD) {
                if (!isStale[asset]) {
                    isStale[asset] = true;
                    emit PriceStalenessDetected(asset, updatedAt, block.timestamp);
                }
            }
        } catch {}
        
        // Fallback to cached price
        if (fallbackPrices[asset] > 0) {
            emit PriceUpdated(asset, fallbackPrices[asset], block.timestamp, false);
        }
        return (fallbackPrices[asset], fallbackPrices[asset] > 0);
    }

    /**
     * @notice View version of getPriceUnsafe for read-only calls (no events)
     */
    function getPriceUnsafeView(address asset) external view override returns (uint256, bool) {
        address aggregator = aggregators[asset];
        if (aggregator == address(0)) {
            return (fallbackPrices[asset], fallbackPrices[asset] > 0);
        }
        
        try AggregatorV3Interface(aggregator).latestRoundData() returns (
            uint80,
            int256 answer,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            uint256 timeElapsed = block.timestamp - updatedAt;
            
            if (answer > 0 && timeElapsed <= PRICE_STALENESS_THRESHOLD) {
                uint8 oracleDecimals = AggregatorV3Interface(aggregator).decimals();
                uint256 normalizedPrice = oracleDecimals < 18 
                    ? uint256(answer) * (10 ** (18 - oracleDecimals))
                    : uint256(answer) / (10 ** (oracleDecimals - 18));
                
                return (normalizedPrice, true);
            }
        } catch {}
        
        return (fallbackPrices[asset], fallbackPrices[asset] > 0);
    }
}
