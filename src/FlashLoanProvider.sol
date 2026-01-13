// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IFlashLoanReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

/**
 * @title FlashLoanProvider
 * @notice Provides flash loans for composable DeFi strategies
 * Follows Aave-like flash loan pattern for compatibility
 */
contract FlashLoanProvider is ReentrancyGuard {
    IERC20 public immutable USDT;
    
    uint256 public constant FLASH_LOAN_PREMIUM_TOTAL = 9; 
    event FlashLoan(
        address indexed receiver,
        address indexed token,
        uint256 amount,
        uint256 premium,
        uint256 timestamp
    );

    constructor(address _usdt) {
        require(_usdt != address(0), "Invalid USDT address");
        USDT = IERC20(_usdt);
    }

    /**
     * @notice Initiates a flash loan
     * @param receiver The contract receiving the flash loan
     * @param amount Amount of USDT to borrow
     * @param params Additional parameters to pass to receiver
     */
    function flashLoan(
        address receiver,
        uint256 amount,
        bytes calldata params
    ) external nonReentrant {
        require(receiver != address(0), "Invalid receiver");
        require(amount > 0, "Amount must be > 0");
        
        uint256 balanceBefore = USDT.balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient liquidity");
        
        uint256 premium = (amount * FLASH_LOAN_PREMIUM_TOTAL) / 10000;
        
        require(
            USDT.transfer(receiver, amount),
            "Flash loan transfer failed"
        );
        
        bool success = IFlashLoanReceiver(receiver).executeOperation(
            address(USDT),
            amount,
            premium,
            msg.sender,
            params
        );
        
        require(success, "Flash loan execution failed");
        
        uint256 balanceAfter = USDT.balanceOf(address(this));
        require(
            balanceAfter >= balanceBefore + premium,
            "Flash loan not repaid with premium"
        );
        
        emit FlashLoan(receiver, address(USDT), amount, premium, block.timestamp);
    }

    /**
     * @notice Returns max flash loan amount
     */
    function maxFlashLoan(address token) external view returns (uint256) {
        if (token == address(USDT)) {
            return USDT.balanceOf(address(this));
        }
        return 0;
    }

    /**
     * @notice Returns flash loan fee
     */
    function flashLoanFee(address token, uint256 amount) external pure returns (uint256) {
        if (token == address(0)) return 0;
        return (amount * FLASH_LOAN_PREMIUM_TOTAL) / 10000;
    }
}
