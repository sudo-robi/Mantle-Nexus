// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./USDTMock.sol";

interface ICreditScore {
    function getAdjustedLTV(address user) external view returns (uint256);
}

/// @title MC-RWA Vault MVP
/// @notice Multi-Collateral Vault accepting ERC20/ERC721 as collateral, borrowing USDT
// ADDED: Inheriting ERC20Burnable for Option 3 (vUSDT)
contract MCRWAVault is Ownable, ERC20Burnable {

    uint256 public constant LTV_PERCENT = 50; 
    USDTMock public immutable usdt;

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
        uint256 totalCollateralUSD; 
    }
    bool public paused;
    mapping(address => uint256) public lastActionBlock;

    error ProtocolPaused();
    error ActionTooFast(); // Prevents same-block manipulation 
    mapping(address => uint256) public erc20PricesUSD;
    mapping(address => uint256) public erc721PricesUSD;
    mapping(address => UserVault) internal vaults;
    modifier whenNotPaused() {
      if(paused) revert ProtocolPaused();
             _;
        }

    modifier rateLimit() {
            if(lastActionBlock[msg.sender] == block.number) revert ActionTooFast();
        _;
        lastActionBlock[msg.sender] = block.number;
    }
    address public creditScoreAddress;
    ICreditScore public creditScoreContract; 

    event CollateralERC20Deposited(address indexed user, address token, uint256 amount);
    event CollateralERC721Deposited(address indexed user, address token, uint256 tokenId);
    event Borrowed(address indexed user, uint256 amountUSDT);
    event Repaid(address indexed user, uint256 amountUSDT);
    event CollateralWithdrawnERC20(address indexed user, address token, uint256 amount);
    event CollateralWithdrawnERC721(address indexed user, address token, uint256 tokenId);

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

    function depositERC20(address token, uint256 amount) external whenNotPaused rateLimit {
        if(amount == 0) revert InvalidAmount();
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        UserVault storage vault = vaults[msg.sender];
        vault.erc20Collateral[token].amount += amount;
        uint256 addedValue = erc20PricesUSD[token] * amount;
        vault.erc20Collateral[token].valueUSD += addedValue;
        vault.totalCollateralUSD += addedValue;

        _mint(msg.sender, amount);

        emit CollateralERC20Deposited(msg.sender, token, amount);
    }

    function depositERC721(address token, uint256 tokenId) external {
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);

        UserVault storage vault = vaults[msg.sender];
        uint256 value = erc721PricesUSD[token];
        vault.erc721Collateral[token].push(CollateralERC721(tokenId, value));
        vault.totalCollateralUSD += value;

        emit CollateralERC721Deposited(msg.sender, token, tokenId);
    }

    // Borrowing 
    function borrow(uint256 amountUSDT) external whenNotPaused rateLimit {
        if(amountUSDT == 0) revert InvalidAmount();

        UserVault storage vault = vaults[msg.sender];
        uint256 userLTV = _getUserLTV(msg.sender);
        uint256 maxBorrow = (vault.totalCollateralUSD * userLTV) / 100;
        if(vault.debtUSDT + amountUSDT > maxBorrow) revert ExceedsMaxBorrow();

        vault.debtUSDT += amountUSDT;
        usdt.mint(msg.sender, amountUSDT);

        emit Borrowed(msg.sender, amountUSDT);
    }

    // Repay 
    function repay(uint256 amountUSDT) external {
        if(amountUSDT == 0) revert InvalidAmount();

        UserVault storage vault = vaults[msg.sender];
        if(vault.debtUSDT < amountUSDT) revert RepayExceedsDebt();

        IERC20(usdt).transferFrom(msg.sender, address(this), amountUSDT);
        vault.debtUSDT -= amountUSDT;

        emit Repaid(msg.sender, amountUSDT);
    }

    // Withdraw Collateral 
    function withdrawERC20(address token, uint256 amount) external {
        UserVault storage vault = vaults[msg.sender];
        CollateralERC20 storage col = vault.erc20Collateral[token];

        if(amount == 0 || col.amount < amount) revert InsufficientCollateral();
        _burn(msg.sender, amount);

        uint256 valueRemoved = erc20PricesUSD[token] * amount;
        col.amount -= amount;
        col.valueUSD -= valueRemoved;
        vault.totalCollateralUSD -= valueRemoved;

        uint256 userLTV = _getUserLTV(msg.sender);
        if((vault.totalCollateralUSD * userLTV) / 100 < vault.debtUSDT) revert CollateralTooLow();

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

        uint256 valueRemoved = collaterals[index].valueUSD;
        vault.totalCollateralUSD -= valueRemoved;

        collaterals[index] = collaterals[collaterals.length - 1];
        collaterals.pop();

        uint256 userLTV = _getUserLTV(msg.sender);
        if((vault.totalCollateralUSD * userLTV) / 100 < vault.debtUSDT) revert CollateralTooLow();

        IERC721(token).transferFrom(address(this), msg.sender, tokenId);
        emit CollateralWithdrawnERC721(msg.sender, token, tokenId);
    }

    // Admin functions
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
        require(_creditScore != address(0), "MCRWAVault: Invalid address");
        creditScoreAddress = _creditScore;
        creditScoreContract = ICreditScore(_creditScore); 
    }

    // View Functions 
    function getUserCollateralValue(address user) external view returns (uint256) {
        return vaults[user].totalCollateralUSD;
    }

    // Fixed mapping visibility for local testing
    function getVaultDebt(address user) external view returns (uint256) {
        return vaults[user].debtUSDT;
    }
}