// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IMCRWAVault {
    function depositERC20(address token, uint256 amount) external;
    function borrow(uint256 amount) external;
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
        bool successIn = IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        require(successIn, "Integrator: Collateral transfer failed");
        IERC20(collateralToken).approve(address(VAULT), amount);
        VAULT.depositERC20(collateralToken, amount);
        uint256 amountToBorrow = amount / 2; 
        VAULT.borrow(amountToBorrow);
        bool successOut = USDT.transfer(msg.sender, USDT.balanceOf(address(this)));
        require(successOut, "Integrator: USDT transfer to user failed");
    }

    /**
     * @notice View function to check this contract's vUSDT balance (Receipt Token)
     */
    function getMyReceiptBalance() external view returns (uint256) {
        return IERC20(address(VAULT)).balanceOf(address(this));
    }
}