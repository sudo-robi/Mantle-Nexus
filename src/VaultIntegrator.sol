// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IMCRWAVault {
    function depositERC20(address token, uint256 amount) external;
    function borrow(address token, uint256 amount) external;
    function getUserCollateralValue(address user) external view returns (uint256);
}

/**
 * @title VaultIntegrator
 * @notice Proves Option 1 (Composability) by allowing a contract to 
 * automate interactions with the MC-RWA Vault.
 */
contract VaultIntegrator {
    IMCRWAVault public immutable VAULT;
    IERC20 public immutable USDT;

    event DebugLog(string message);
    event DebugLogAddress(string message, address value);
    event DebugLogUint(string message, uint256 value);
    event DebugLogBool(string message, bool value);

    constructor(address _vault, address _usdt) {
        VAULT = IMCRWAVault(_vault);
        USDT = IERC20(_usdt);
    }

    /**
     * @notice Performs a "Leveraged Deposit" (Option 1).
     * Proves that a third-party contract can manage assets in the vault.
     * @param collateralToken The ERC20 address used as collateral (e.g., a tokenized RWA).
     * @param amount The amount of collateral to deposit.
     */
    function automatedLeverage(address collateralToken, uint256 amount) external {
        emit DebugLog("=== automatedLeverage START ===");
        emit DebugLogAddress("Caller:", msg.sender);
        emit DebugLogAddress("Collateral Token:", collateralToken);
        emit DebugLogUint("Amount:", amount);
        
        if (amount == 0) {
            emit DebugLog("ERROR: Amount is zero");
            require(amount > 0, "Integrator: Amount must be greater than zero");
        }
        
        if (collateralToken == address(0)) {
            emit DebugLog("ERROR: Collateral token is zero address");
            require(collateralToken != address(0), "Integrator: Invalid collateral token address");
        }
        
        if (address(VAULT) == address(0)) {
            emit DebugLog("ERROR: Vault not initialized");
            require(address(VAULT) != address(0), "Integrator: Vault not initialized");
        }
        
        emit DebugLog("Step 1: Attempting to transfer collateral from user to integrator");
        bool successIn = IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        emit DebugLogBool("Collateral transfer success:", successIn);
        if (!successIn) {
            emit DebugLog("ERROR: Failed to transfer collateral - check user balance and approval to integrator");
            require(successIn, "Integrator: Collateral transfer failed - insufficient balance or allowance");
        }
        
        emit DebugLog("Step 2: Approving vault to spend collateral");
        bool approvalSuccess = IERC20(collateralToken).approve(address(VAULT), amount);
        emit DebugLogBool("Approval to vault success:", approvalSuccess);
        if (!approvalSuccess) {
            emit DebugLog("ERROR: Failed to approve vault to spend collateral");
            require(approvalSuccess, "Integrator: Approval to vault failed");
        }
        
        emit DebugLog("Step 3: Depositing collateral to vault");
        try VAULT.depositERC20(collateralToken, amount) {
            emit DebugLog("Deposit successful");
        } catch Error(string memory reason) {
            emit DebugLog(string(abi.encodePacked("ERROR in depositERC20: ", reason)));
            revert(string(abi.encodePacked("Deposit failed: ", reason)));
        }
        
        uint256 amountToBorrow = amount / 2;
        emit DebugLogUint("Amount to borrow (50% of collateral):", amountToBorrow);
        
        emit DebugLog("Step 4: Borrowing USDT from vault");
        try VAULT.borrow(address(USDT), amountToBorrow) {
            emit DebugLog("Borrow successful");
        } catch Error(string memory reason) {
            emit DebugLog(string(abi.encodePacked("ERROR in borrow: ", reason)));
            revert(string(abi.encodePacked("Borrow failed: ", reason)));
        }
        
        uint256 usdtBalance = USDT.balanceOf(address(this));
        emit DebugLogUint("USDT balance after borrow:", usdtBalance);
        
        if (usdtBalance == 0) {
            emit DebugLog("ERROR: No USDT available after borrow - borrow may have failed silently");
            require(usdtBalance > 0, "Integrator: No USDT available after borrow");
        }
        
        emit DebugLog("Step 5: Transferring USDT to caller");
        bool successOut = USDT.transfer(msg.sender, usdtBalance);
        emit DebugLogBool("USDT transfer to user success:", successOut);
        if (!successOut) {
            emit DebugLog("ERROR: Failed to transfer USDT to user");
            require(successOut, "Integrator: USDT transfer to user failed");
        }
        
        emit DebugLog("=== automatedLeverage SUCCESS ===");
    }

    /**
     * @notice View function to check this contract's vUSDT balance (Receipt Token)
     */
    function getMyReceiptBalance() external view returns (uint256) {
        return IERC20(address(VAULT)).balanceOf(address(this));
    }
}