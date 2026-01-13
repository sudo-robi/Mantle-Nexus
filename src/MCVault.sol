// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./USDTMock.sol";
import "./PriceOracle.sol";
import "./IBorrowToken.sol";

/// @notice Chainlink admin interface for oracle configuration
interface IChainlinkPriceOracle {
    function setAggregator(address asset, address aggregator, uint8 assetDecimals) external;
    function setFallbackPrice(address asset, uint256 price) external;
}

interface ICreditScore {
    function getAdjustedLTV(address user) external view returns (uint256);
}

/// @title MC Vault MVP
/// @notice Multi-Collateral Vault accepting ERC20/ERC721 as collateral, borrowing USDT
/// @dev Supports optional Chainlink oracle for decentralized pricing
contract MCVault is Ownable, ERC20Burnable, ReentrancyGuard {

    uint256 public constant LTV_PERCENT = 50; 
    USDTMock public immutable usdt;
    IPriceOracle public priceOracle;
    // Mapping of allowed borrow tokens and their decimals
    mapping(address => bool) public allowedBorrowTokens;
    mapping(address => uint8) public borrowTokenDecimals;

    error InvalidAmount();
    error ExceedsMaxBorrow();
    error RepayExceedsDebt();
    error InsufficientCollateral();
    error CollateralTooLow();
    error TokenNotFound();
    error InvalidUSDTAddress();

    struct CollateralERC20 {
        uint256 amount;
        uint256 valueUSD;
    }

    struct CollateralERC721 {
        uint256 tokenId;
        uint256 valueUSD;
    }

    struct UserVault {
        uint256 debtUSDT;
        mapping(address => CollateralERC20) erc20Collateral;
        mapping(address => CollateralERC721[]) erc721Collateral;
        address[] erc20TokenList;
        address[] erc721TokenList;
    }
    bool public paused;
    mapping(address => uint256) public lastActionBlock;

    error ProtocolPaused();
    error ActionTooFast(); 
    mapping(address => uint256) public erc20PricesUSD;
    mapping(address => uint256) public erc721PricesUSD;
    mapping(address => UserVault) internal vaults;
    modifier whenNotPaused() {
      if(paused) revert ProtocolPaused();
             _;
        }

    modifier rateLimit() {
            if (msg.sender.code.length == 0) {
                if (lastActionBlock[msg.sender] == block.number) revert ActionTooFast();
                _;
                lastActionBlock[msg.sender] = block.number;
            } else {
                _;
            }
    }
    address public creditScoreAddress;
    ICreditScore public creditScoreContract; 

    event CollateralERC20Deposited(address indexed user, address token, uint256 amount);
    event CollateralERC721Deposited(address indexed user, address token, uint256 tokenId);
    event Borrowed(address indexed user, uint256 amountUSDT);
    event Repaid(address indexed user, uint256 amountUSDT);
    event CollateralWithdrawnERC20(address indexed user, address token, uint256 amount);
    event CollateralWithdrawnERC721(address indexed user, address token, uint256 tokenId);
    event UserLiquidated(address indexed user, address indexed liquidator, uint256 debtRepaid, uint256 collateralSeized);
    event CollateralSeized(address indexed user, address indexed token, uint256 amount);
    event RepaidWithBorrowToken(address indexed user, address indexed token, uint256 amountToken, uint256 amountUSDT);
    
    uint256 public liquidationThreshold = 80; 
    uint256 public liquidationBonus = 10; 
    uint256 public totalLiquidations;
    mapping(address => uint256) public userLiquidationCount;

    constructor(address _usdt, address _owner) 
        ERC20("Mantle RWA Receipt USDT", "mRWA-USDT") 
        Ownable(_owner) 
    {
        if(_usdt == address(0)) revert InvalidUSDTAddress();
        usdt = USDTMock(_usdt);
    }

    function _getUserLTV(address user) internal view returns (uint256) {
        if (address(creditScoreContract) == address(0)) {
            return LTV_PERCENT;
        }
        return creditScoreContract.getAdjustedLTV(user);
    }

    function _getAssetPrice(address asset) internal view returns (uint256) {
        if (address(priceOracle) != address(0)) {
            // Use view getter with fallback support so that oracle fallback prices can be used
            try priceOracle.getPriceUnsafeView(asset) returns (uint256 p, bool ok) {
                if (ok && p > 0) return p;
            } catch {}
        }
        return erc20PricesUSD[asset];
    }

    function _calculateCollateralValue(address user) internal view returns (uint256) {
        UserVault storage vault = vaults[user];
        uint256 totalValue = 0;
        
        for(uint i=0; i<vault.erc20TokenList.length; i++) {
            address token = vault.erc20TokenList[i];
            uint256 amount = vault.erc20Collateral[token].amount;
            if(amount > 0) {
                uint256 price = _getAssetPrice(token);
                totalValue += (price * amount) / 1e18;
            }
        }
        
        for(uint i=0; i<vault.erc721TokenList.length; i++) {
            address token = vault.erc721TokenList[i];
            CollateralERC721[] storage nfts = vault.erc721Collateral[token];
            if(nfts.length > 0) {
                // Prefer oracle price (18 decimals); fallback to manual price mapping
                uint256 price = _getAssetPrice(token);
                if(price == 0) {
                    price = erc721PricesUSD[token];
                }
                // Normalize to USD value
                if(price > 0) {
                    totalValue += (price * nfts.length) / 1e18;
                }
            }
        }
        return totalValue;
    }

    function depositERC20(address token, uint256 amount) external whenNotPaused rateLimit nonReentrant {
        if(amount == 0) revert InvalidAmount();
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        UserVault storage vault = vaults[msg.sender];
        if (vault.erc20Collateral[token].amount == 0) {
            vault.erc20TokenList.push(token);
        }
        vault.erc20Collateral[token].amount += amount;

        _mint(msg.sender, amount);

        emit CollateralERC20Deposited(msg.sender, token, amount);
    }

    function depositERC721(address token, uint256 tokenId) external {
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);

        UserVault storage vault = vaults[msg.sender];
        if (vault.erc721Collateral[token].length == 0) {
            vault.erc721TokenList.push(token);
        }
        uint256 value = erc721PricesUSD[token];
        vault.erc721Collateral[token].push(CollateralERC721(tokenId, value));

        emit CollateralERC721Deposited(msg.sender, token, tokenId);
    }
 
    function borrow(address borrowToken, uint256 amount) external whenNotPaused rateLimit nonReentrant {
        if(amount == 0) revert InvalidAmount();
        require(allowedBorrowTokens[borrowToken], "Token not allowed");

        UserVault storage vault = vaults[msg.sender];
        uint256 userLTV = _getUserLTV(msg.sender);
        uint256 tokenPrice = _getAssetPrice(borrowToken);
        uint256 amountUSDT = (amount * tokenPrice) / 1e18;
        uint256 collateralValue = _calculateCollateralValue(msg.sender);
        uint256 maxBorrow = (collateralValue * userLTV) / 100;
        if(vault.debtUSDT + amountUSDT > maxBorrow) revert ExceedsMaxBorrow();

        vault.debtUSDT += amountUSDT;
        IBorrowToken(borrowToken).mint(msg.sender, amount);

        emit Borrowed(msg.sender, amountUSDT);
    }

    function repay(uint256 amountUSDT) external nonReentrant {
        if(amountUSDT == 0) revert InvalidAmount();

        UserVault storage vault = vaults[msg.sender];
        if(vault.debtUSDT < amountUSDT) revert RepayExceedsDebt();

        IERC20(usdt).transferFrom(msg.sender, address(this), amountUSDT);
        vault.debtUSDT -= amountUSDT;

        emit Repaid(msg.sender, amountUSDT);
    }

    /// @notice Repay debt using a borrow token (multi-token repay support)
    /// @param borrowToken The ERC20 token to use for repayment (must be an allowed borrow token)
    /// @param amountToken The amount of the borrow token to repay
    function repayWithBorrowToken(address borrowToken, uint256 amountToken) external nonReentrant {
        if(amountToken == 0) revert InvalidAmount();
        require(allowedBorrowTokens[borrowToken], "Token not allowed for borrowing");

        UserVault storage vault = vaults[msg.sender];
        if(vault.debtUSDT == 0) revert RepayExceedsDebt();

        uint8 tokenDecimals = borrowTokenDecimals[borrowToken];
        require(tokenDecimals > 0, "Token decimals not configured");

        uint256 tokenPrice = _getAssetPrice(borrowToken);
        require(tokenPrice > 0, "No price available for token");

        // Convert token amount to USDT-equivalent (normalized to 18 decimals)
        uint256 amountUSDT = (amountToken * tokenPrice) / (10 ** tokenDecimals);
        if(amountUSDT == 0) revert InvalidAmount();

        // Burn the exact token amount needed to cover the debt (or all of amountToken if partial)
        if(amountUSDT <= vault.debtUSDT) {
            IBorrowToken(borrowToken).burn(msg.sender, amountToken);
            vault.debtUSDT -= amountUSDT;
            emit RepaidWithBorrowToken(msg.sender, borrowToken, amountToken, amountUSDT);
        } else {
            // Overpayment: calculate exact token amount to clear remaining debt
            uint256 debtRemaining = vault.debtUSDT;
            // tokenAmount = (debt * 10^decimals) / price
            uint256 amountTokenNeeded = (debtRemaining * (10 ** tokenDecimals)) / tokenPrice;
            // Round up if needed
            if((amountTokenNeeded * tokenPrice) / (10 ** tokenDecimals) < debtRemaining) {
                amountTokenNeeded += 1;
            }
            IBorrowToken(borrowToken).burn(msg.sender, amountTokenNeeded);
            vault.debtUSDT = 0;
            emit RepaidWithBorrowToken(msg.sender, borrowToken, amountTokenNeeded, debtRemaining);
        }
    }

    function withdrawERC20(address token, uint256 amount) external {
        UserVault storage vault = vaults[msg.sender];
        CollateralERC20 storage col = vault.erc20Collateral[token];

        if(amount == 0 || col.amount < amount) revert InsufficientCollateral();
        _burn(msg.sender, amount);
        uint256 valueRemoved;
        valueRemoved = (erc20PricesUSD[token] * amount) / 1e18;
        col.amount -= amount;
       if (col.amount == 0) {
            for (uint i = 0; i < vault.erc20TokenList.length; i++) {
                if (vault.erc20TokenList[i] == token) {
                    vault.erc20TokenList[i] = vault.erc20TokenList[vault.erc20TokenList.length - 1];
                    vault.erc20TokenList.pop();
                    break;
                }
            }
        }

        uint256 userLTV = _getUserLTV(msg.sender);
        uint256 collateralValue = _calculateCollateralValue(msg.sender);
        if((collateralValue * userLTV) / 100 < vault.debtUSDT) revert CollateralTooLow();

        IERC20(token).transfer(msg.sender, amount);
        emit CollateralWithdrawnERC20(msg.sender, token, amount);
    }

    function withdrawERC721(address token, uint256 tokenId) external {
        UserVault storage vault = vaults[msg.sender];
        CollateralERC721[] storage collaterals = vault.erc721Collateral[token];

        uint256 index = type(uint256).max;
        for(uint i=0; i<collaterals.length; i++){
            if(collaterals[i].tokenId == tokenId){
                index = i;
                break;
            }
        }
        if(index == type(uint256).max) revert TokenNotFound();
         uint256 valueRemoved;
         valueRemoved = collaterals[index].valueUSD;

        collaterals[index] = collaterals[collaterals.length - 1];
        collaterals.pop();
        if (collaterals.length == 0) {
            for (uint i = 0; i < vault.erc721TokenList.length; i++) {
                if (vault.erc721TokenList[i] == token) {
                    vault.erc721TokenList[i] = vault.erc721TokenList[vault.erc721TokenList.length - 1];
                    vault.erc721TokenList.pop();
                    break;
                }
            }
        }

        uint256 userLTV = _getUserLTV(msg.sender);
        uint256 collateralValue = _calculateCollateralValue(msg.sender);
        if((collateralValue * userLTV) / 100 < vault.debtUSDT) revert CollateralTooLow();

        IERC721(token).transferFrom(address(this), msg.sender, tokenId);
        emit CollateralWithdrawnERC721(msg.sender, token, tokenId);
    }

    function setERC20Price(address token, uint256 priceUSD) external onlyOwner {
        erc20PricesUSD[token] = priceUSD;
    }

    function setERC721Price(address token, uint256 priceUSD) external onlyOwner {
        erc721PricesUSD[token] = priceUSD;
    }
    function togglePause() external onlyOwner {
        paused = !paused;
    }
    
    function setCreditScoreContract(address _creditScore) public onlyOwner {
        require(_creditScore != address(0), "MCVault: Invalid address");
        creditScoreAddress = _creditScore;
        creditScoreContract = ICreditScore(_creditScore); 
    }
    
    /// @notice Set price oracle (optional, for Chainlink integration)
    function setPriceOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle");
        priceOracle = IPriceOracle(_oracle);
    }

    /// @notice Register a Chainlink aggregator for an asset (requires oracle to support IChainlinkPriceOracle)
    function registerChainlinkAggregator(address asset, address aggregator, uint8 assetDecimals) external onlyOwner {
        require(address(priceOracle) != address(0), "Oracle not set");
        require(asset != address(0) && aggregator != address(0), "Invalid addresses");
        IChainlinkPriceOracle(address(priceOracle)).setAggregator(asset, aggregator, assetDecimals);
    }

    /// @notice Set a fallback price in the oracle for circuit breaker resilience
    function setChainlinkFallbackPrice(address asset, uint256 priceUSD) external onlyOwner {
        require(address(priceOracle) != address(0), "Oracle not set");
        require(asset != address(0), "Invalid asset");
        IChainlinkPriceOracle(address(priceOracle)).setFallbackPrice(asset, priceUSD);
    }

    function addBorrowToken(address token, uint8 decimals) external onlyOwner {
        require(token != address(0), "Invalid token");
        allowedBorrowTokens[token] = true;
        borrowTokenDecimals[token] = decimals;
    }

    function removeBorrowToken(address token) external onlyOwner {
        allowedBorrowTokens[token] = false;
    }
    
    /// @notice Get health factor for a user
    function getHealthFactor(address user) external view returns (uint256) {
        UserVault storage vault = vaults[user];
        if (vault.debtUSDT == 0) return type(uint256).max;
        uint256 userLTV = _getUserLTV(user);
        uint256 collateralValue = _calculateCollateralValue(user);
        uint256 maxBorrow = (collateralValue * userLTV) / 100;
        if (maxBorrow == 0) return 0;
        return (maxBorrow * 1e18) / vault.debtUSDT;
    }
    
    /// @notice Check if user is liquidatable
    function isLiquidatable(address user) external view returns (bool) {
        UserVault storage vault = vaults[user];
        if (vault.debtUSDT == 0) return false;
        uint256 collateralValue = _calculateCollateralValue(user);
        if (collateralValue == 0) return true;
        uint256 currentLTV = (vault.debtUSDT * 100) / collateralValue;
        return currentLTV >= liquidationThreshold;
    }
    
    /// @notice Liquidate an underwater position
    function liquidate(address user, uint256 repayAmount) external nonReentrant whenNotPaused {
        UserVault storage vault = vaults[user];
        require(vault.debtUSDT > 0, "User has no debt");
        require(repayAmount > 0, "Invalid repay amount");
        require(repayAmount <= vault.debtUSDT, "Repay exceeds debt");
        
      
        uint256 collateralValue = _calculateCollateralValue(user);
        require(collateralValue > 0, "No collateral");
        uint256 currentLTV = (vault.debtUSDT * 100) / collateralValue;
        require(currentLTV >= liquidationThreshold, "Not liquidatable");
        
        IERC20(usdt).transferFrom(msg.sender, address(this), repayAmount);
        vault.debtUSDT -= repayAmount;
        
        uint256 bonusUSD = (repayAmount * liquidationBonus) / 100;
        uint256 toSeize = repayAmount + bonusUSD;
        
        uint256 actualSeized = _seizeCollateral(user, toSeize, collateralValue);
        
        totalLiquidations++;
        userLiquidationCount[user]++;
        
        emit UserLiquidated(user, msg.sender, repayAmount, actualSeized);
    }

    function _seizeCollateral(address user, uint256 toSeize, uint256 collateralValue) internal returns (uint256) {
        UserVault storage vault = vaults[user];
        uint256 remainingToSeize = toSeize > collateralValue ? collateralValue : toSeize;
        uint256 actualSeized = 0;
        address[] memory tokens;
        tokens = vault.erc20TokenList; 
        
        for(uint i=0; i<vault.erc20TokenList.length; i++) {
            address token = vault.erc20TokenList[i];
            uint256 amount = vault.erc20Collateral[token].amount;
             if(amount > 0 && remainingToSeize > 0) {
                uint256 price = _getAssetPrice(token);
                uint256 value = (amount * price) / 1e18;
                if(value > 0) {
                    uint256 takeValue = value > remainingToSeize ? remainingToSeize : value;
                    uint256 takeAmount = (takeValue * 1e18) / price; 
                    
                    vault.erc20Collateral[token].amount -= takeAmount;
                    IERC20(token).transfer(msg.sender, takeAmount);
                    emit CollateralSeized(user, token, takeAmount);
                    
                       if (vault.erc20Collateral[token].amount == 0) {
                        for (uint j = 0; j < vault.erc20TokenList.length; j++) {
                            if (vault.erc20TokenList[j] == token) {
                                vault.erc20TokenList[j] = vault.erc20TokenList[vault.erc20TokenList.length - 1];
                                vault.erc20TokenList.pop();
                                break;
                            }
                        }
                    }

                    remainingToSeize -= takeValue;
                    actualSeized += takeValue;
                }
             }
        }
        return actualSeized;
    }

    function getUserERC20TokenList(address user) external view returns (address[] memory) {
        return vaults[user].erc20TokenList;
    }

    function getUserERC721TokenList(address user) external view returns (address[] memory) {
        return vaults[user].erc721TokenList;
    }
    
    /// @notice Set liquidation threshold
    function setLiquidationThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold > 0 && newThreshold <= 100, "Invalid threshold");
        liquidationThreshold = newThreshold;
    }
 
    function getUserCollateralValue(address user) external view returns (uint256) {
        return _calculateCollateralValue(user);
    }

    function getVaultDebt(address user) external view returns (uint256) {
        return vaults[user].debtUSDT;
    }
}