// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MCVault} from "../src/MCVault.sol";
import {USDTMock} from "../src/USDTMock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Comprehensive Test Suite for MC Vault
/// @notice Tests core functionality respecting rate limiting (max 1 action per block)
contract MCRWAVaultComprehensiveTest is Test {
    MCRWAVault vault;
    USDTMock usdt;
    
    address owner = address(0x123);
    address user1 = address(0x111);
    address user2 = address(0x222);
    address liquidator = address(0x333);
    
    uint256 initialBlock;

    function setUp() public {
        vm.startPrank(owner);
        usdt = new USDTMock();
        vault = new MCRWAVault(address(usdt), owner);
        
        vault.setERC20Price(address(usdt), 1e18); 
        
        vault.addBorrowToken(address(usdt), 18);

        usdt.mint(user1, 50000e18);
        usdt.mint(user2, 50000e18);
        usdt.mint(liquidator, 50000e18);
        
        vm.stopPrank();

        vm.prank(user1);
        usdt.approve(address(vault), type(uint256).max);
        
        vm.prank(user2);
        usdt.approve(address(vault), type(uint256).max);
        
        vm.prank(liquidator);
        usdt.approve(address(vault), type(uint256).max);
        
        initialBlock = block.number;
    }

    function test_DepositERC20() public {
        uint256 depositAmount = 1000e18;
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), depositAmount);
        
        assertEq(vault.getUserCollateralValue(user1), depositAmount);
        assertEq(vault.balanceOf(user1), depositAmount);
    }

    function test_DepositMultipleTimes() public {
        uint256 firstDeposit = 500e18;
        uint256 secondDeposit = 300e18;
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), firstDeposit);
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), secondDeposit);
        
        assertEq(vault.getUserCollateralValue(user1), firstDeposit + secondDeposit);
    }

    function test_DepositRevertsOnZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.depositERC20(address(usdt), 0);
    }

    function test_DepositRevertsWhenPaused() public {
        vm.prank(owner);
        vault.togglePause();
        
        vm.prank(user1);
        vm.expectRevert();
        vault.depositERC20(address(usdt), 100e18);
    }

    function test_BorrowBasic() public {
        uint256 collateralAmount = 1000e18;
        uint256 borrowAmount = 500e18; 
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.borrow(address(usdt), borrowAmount);
        
        assertEq(vault.getVaultDebt(user1), borrowAmount);
    }

    function test_BorrowMultipleTimes() public {
        uint256 collateralAmount = 1000e18;
        uint256 firstBorrow = 200e18;
        uint256 secondBorrow = 200e18;
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.borrow(address(usdt), firstBorrow);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.borrow(address(usdt), secondBorrow);
        
        assertEq(vault.getVaultDebt(user1), firstBorrow + secondBorrow);
    }

    function test_BorrowRevertsWithoutCollateral() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.borrow(address(usdt), 100e18);
    }

    function test_BorrowRevertsExceedsLTV() public {
        uint256 collateralAmount = 1000e18;
        uint256 excessiveBorrow = 600e18; 
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vm.expectRevert();
        vault.borrow(address(usdt), excessiveBorrow);
    }

    function test_RepayFullDebt() public {
        uint256 collateralAmount = 1000e18;
        uint256 borrowAmount = 500e18;
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.borrow(address(usdt), borrowAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.repay(borrowAmount);
        
        assertEq(vault.getVaultDebt(user1), 0);
    }

    function test_HealthFactorWhenNoDebt() public {
        uint256 collateralAmount = 1000e18;
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        
        uint256 healthFactor = vault.getHealthFactor(user1);
        assertEq(healthFactor, type(uint256).max);
    }

    function test_HealthFactorCalculation() public {
        uint256 collateralAmount = 1000e18;
        uint256 borrowAmount = 400e18;
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.borrow(address(usdt), borrowAmount);
        
        uint256 healthFactor = vault.getHealthFactor(user1);
        assertEq(healthFactor, 1.25e18);
    }


    function test_IsLiquidatableWhenNotUnderwater() public {
        uint256 collateralAmount = 1000e18;
        uint256 borrowAmount = 400e18;
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.borrow(address(usdt), borrowAmount);
        
        bool isLiquidatable = vault.isLiquidatable(user1);
        assertFalse(isLiquidatable);
    }

    function test_IsLiquidatableWhenUnderwater() public {
        uint256 collateralAmount = 1000e18;
        uint256 borrowAmount = 500e18; 
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.borrow(address(usdt), borrowAmount);
        
        vm.prank(owner);
        vault.setERC20Price(address(usdt), 6e17);

        bool isLiquidatable = vault.isLiquidatable(user1);
        assertTrue(isLiquidatable);
    }

    function test_LiquidationBasic() public {
        uint256 collateralAmount = 1000e18;
        uint256 borrowAmount = 500e18;
        uint256 repayAmount = 100e18;
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.borrow(address(usdt), borrowAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(owner);
        vault.setERC20Price(address(usdt), 6e17);

        vm.prank(liquidator);
        vault.liquidate(user1, repayAmount);
        
        assertEq(vault.getVaultDebt(user1), borrowAmount - repayAmount);
    }

    function test_LiquidationRevertsNotLiquidatable() public {
        uint256 collateralAmount = 1000e18;
        uint256 borrowAmount = 400e18;
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.borrow(address(usdt), borrowAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(liquidator);
        vm.expectRevert();
        vault.liquidate(user1, 100e18);
    }

    function test_GetUserCollateralValue() public {
        uint256 depositAmount = 1000e18;
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), depositAmount);
        
        assertEq(vault.getUserCollateralValue(user1), depositAmount);
    }

    function test_GetVaultDebt() public {
        uint256 collateralAmount = 1000e18;
        uint256 borrowAmount = 500e18;
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.borrow(address(usdt), borrowAmount);
        
        assertEq(vault.getVaultDebt(user1), borrowAmount);
    }

    function test_SetLiquidationThreshold() public {
        vm.prank(owner);
        vault.setLiquidationThreshold(75);
        
        uint256 collateralAmount = 1000e18;
        uint256 borrowAmount = 500e18; 
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.borrow(address(usdt), borrowAmount);
        vm.prank(owner);
        vault.setERC20Price(address(usdt), 65e16); 
        bool isLiquidatable = vault.isLiquidatable(user1);
        assertTrue(isLiquidatable);
    }

    function test_MultipleUsersIndependentPositions() public {
        uint256 collateralAmount = 1000e18;
        uint256 borrowAmount = 400e18;
        
        // User1
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user1);
        vault.borrow(address(usdt), borrowAmount);
        
        vm.roll(block.number + 1);
        
        // User2
        vm.prank(user2);
        vault.depositERC20(address(usdt), collateralAmount);
        
        vm.roll(block.number + 1);
        
        vm.prank(user2);
        vault.borrow(address(usdt), borrowAmount + 100e18);
        
        assertEq(vault.getVaultDebt(user1), borrowAmount);
        assertEq(vault.getVaultDebt(user2), borrowAmount + 100e18);
        assertEq(vault.getUserCollateralValue(user1), collateralAmount);
        assertEq(vault.getUserCollateralValue(user2), collateralAmount);
    }

    function test_RateLimitingPreventsMultipleActionsPerBlock() public {
        uint256 collateralAmount = 1000e18;
        
        vm.prank(user1);
        vault.depositERC20(address(usdt), collateralAmount);
        vm.startPrank(user1, user1);
        vm.expectRevert();
        vault.borrow(address(usdt), 500e18);
    }
}
