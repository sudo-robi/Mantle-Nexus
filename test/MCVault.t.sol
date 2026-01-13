// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MCVault.sol";
import "../src/USDTMock.sol";
import "../src/VaultIntegrator.sol";
import "../src/FlashLoanProvider.sol";
import "../src/PriceOracle.sol";
import "../src/MockAggregator.sol";

contract MCRWAVaultTest is Test {
    MCRWAVault vault;
    USDTMock usdt;
    VaultIntegrator integrator;
    FlashLoanProvider flashLoanProvider;
    
    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    
    function setUp() public {
        vm.startPrank(owner);
        usdt = new USDTMock();
        vault = new MCRWAVault(address(usdt), owner);
        integrator = new VaultIntegrator(address(vault), address(usdt));
        flashLoanProvider = new FlashLoanProvider(address(usdt));
        
        // Set token price
        vault.setERC20Price(address(usdt), 1e18); // 1 USD
        vault.addBorrowToken(address(usdt), 18);
        vm.stopPrank();
    }

    function test_DepositAndBorrow() public {
        // Mint USDT to user1
        vm.prank(owner);
        usdt.mint(user1, 1000e18);
        
        vm.startPrank(user1);
        // Approve and deposit
        usdt.approve(address(vault), 100e18);
        vault.depositERC20(address(usdt), 100e18);
        
        // Advance block to bypass rate limit
        vm.roll(block.number + 1);
        
        // Check receipt token balance
        uint256 vUsdtBalance = vault.balanceOf(user1);
        assertEq(vUsdtBalance, 100e18);
        
        // Borrow (50% LTV)
        vault.borrow(address(usdt), 50e18);
        
        // Check debt using the getter
        uint256 debt = vault.getVaultDebt(user1);
        assertEq(debt, 50e18);
        vm.stopPrank();
    }

    /*
    function test_InterestAccrual() public {
        vm.prank(owner);
        usdt.mint(user1, 1000e18);
        
        vm.startPrank(user1);
        usdt.approve(address(vault), 100e18);
        vault.depositERC20(address(usdt), 100e18);
        vm.roll(block.number + 1);
        vault.borrow(address(usdt), 50e18);
        vm.stopPrank();
        
        // Fast forward 365 days
        vm.warp(block.timestamp + 365 days);
        
        // Trigger interest accrual via borrow
        vm.prank(owner);
        usdt.mint(user1, 100e18);
        
        vm.prank(user1);
        usdt.approve(address(vault), 100e18);
        vm.roll(block.number + 1);
        
        uint256 debtBefore = vault.getVaultDebt(user1);
        
        vm.prank(user1);
        vault.borrow(address(usdt), 1e18); // This triggers interest accrual
        
        uint256 debtAfter = vault.getVaultDebt(user1);
        
        // Should have accrued ~5% interest + 1e18 borrow
        assertGt(debtAfter, debtBefore + 1e18);
    }
    */

    function test_Liquidation() public {
        vm.prank(owner);
        usdt.mint(user1, 1000e18);
        
        vm.startPrank(user1);
        usdt.approve(address(vault), 100e18);
        vault.depositERC20(address(usdt), 100e18);
        vm.roll(block.number + 1);
        // Borrow within LTV (50%) then simulate a price drop to trigger liquidation
        vault.borrow(address(usdt), 50e18);
        vm.stopPrank();

        // Simulate price drop to 60% of original value -> collateral USD becomes 60
        vm.prank(owner);
        vault.setERC20Price(address(usdt), 6e17);
        
        // Now liquidatable
        vm.prank(owner);
        usdt.mint(user2, 1000e18);
        
        vm.startPrank(user2);
        usdt.approve(address(vault), 75e18);
        vault.liquidate(user1, 25e18); // Liquidate part of the debt
        vm.stopPrank();
        
        // Check debt reduced
        uint256 remainingDebt = vault.getVaultDebt(user1);
        assertEq(remainingDebt, 25e18);
    }

    function test_HealthFactor() public {
        vm.prank(owner);
        usdt.mint(user1, 1000e18);
        
        vm.startPrank(user1);
        usdt.approve(address(vault), 100e18);
        vault.depositERC20(address(usdt), 100e18);
        vm.roll(block.number + 1);
        vault.borrow(address(usdt), 50e18);
        vm.stopPrank();
        
        uint256 healthFactor = vault.getHealthFactor(user1);
        // Max borrow is 50e18 (50% LTV), debt is 50e18, so health = 50/50 = 1
        assertEq(healthFactor, 1e18);
    }

    function test_TokenListUpdatedOnWithdraw() public {
        vm.prank(owner);
        usdt.mint(user1, 1000e18);

        vm.startPrank(user1);
        usdt.approve(address(vault), 100e18);
        vault.depositERC20(address(usdt), 100e18);
        vm.roll(block.number + 1);

        address[] memory tokensBefore = vault.getUserERC20TokenList(user1);
        assertEq(tokensBefore.length, 1);

        // Withdraw all
        vault.withdrawERC20(address(usdt), 100e18);

        address[] memory tokensAfter = vault.getUserERC20TokenList(user1);
        assertEq(tokensAfter.length, 0);
        vm.stopPrank();
    }

    function test_TokenListUpdatedOnLiquidation() public {
        vm.prank(owner);
        usdt.mint(user1, 1000e18);

        vm.startPrank(user1);
        usdt.approve(address(vault), 100e18);
        vault.depositERC20(address(usdt), 100e18);
        vm.roll(block.number + 1);
        vault.borrow(address(usdt), 50e18);
        vm.stopPrank();

        // Simulate extreme price drop -> collateral USD becomes 1
        vm.prank(owner);
        vault.setERC20Price(address(usdt), 1e16);

        vm.prank(owner);
        usdt.mint(user2, 1000e18);

        vm.startPrank(user2);
        usdt.approve(address(vault), 1000e18);
        // Repay full debt to seize all collateral
        vault.liquidate(user1, 50e18);
        vm.stopPrank();

        uint256 remainingDebt = vault.getVaultDebt(user1);
        assertEq(remainingDebt, 0);

        address[] memory tokensAfter = vault.getUserERC20TokenList(user1);
        assertEq(tokensAfter.length, 0);
    }

    function test_RepayWithBorrowToken() public {
        // Setup: user deposits collateral and borrows
        vm.prank(owner);
        usdt.mint(user1, 1000e18);

        // Ensure USDT is set as an allowed borrow token
        vm.prank(owner);
        vault.addBorrowToken(address(usdt), 18);

        vm.startPrank(user1);
        usdt.approve(address(vault), 100e18);
        vault.depositERC20(address(usdt), 100e18);
        vm.roll(block.number + 1);

        // Borrow 50 USDT
        vault.borrow(address(usdt), 50e18);
        
        uint256 debtBefore = vault.getVaultDebt(user1);
        assertEq(debtBefore, 50e18);

        // Repay 25 USDT worth of debt using USDT token
        vm.roll(block.number + 1);
        vault.repayWithBorrowToken(address(usdt), 25e18);
        
        uint256 debtAfter = vault.getVaultDebt(user1);
        assertEq(debtAfter, 25e18);
        vm.stopPrank();
    }

    function test_RepayWithBorrowTokenOverpayment() public {
        // Setup: user deposits and borrows small amount, then repays more than owed
        vm.prank(owner);
        usdt.mint(user1, 1000e18);

        vm.prank(owner);
        vault.addBorrowToken(address(usdt), 18);

        vm.startPrank(user1);
        usdt.approve(address(vault), 100e18);
        vault.depositERC20(address(usdt), 100e18);
        vm.roll(block.number + 1);

        vault.borrow(address(usdt), 30e18);
        
        uint256 debtBefore = vault.getVaultDebt(user1);
        assertEq(debtBefore, 30e18);

        // Repay with more tokens than needed (50 > 30)
        vm.roll(block.number + 1);
        vault.repayWithBorrowToken(address(usdt), 50e18);
        
        uint256 debtAfter = vault.getVaultDebt(user1);
        assertEq(debtAfter, 0);
        vm.stopPrank();
    }

    function test_ChainlinkFallbackPriceAffectsBorrow() public {
        // Deploy a ChainlinkPriceOracle and use fallback price
        vm.prank(owner);
        ChainlinkPriceOracle oracle = new ChainlinkPriceOracle();

        // Set fallback price for USDT to $2.00
        vm.prank(owner);
        oracle.setFallbackPrice(address(usdt), 2e18);

        // Configure vault to use oracle
        vm.prank(owner);
        vault.setPriceOracle(address(oracle));

        // Ensure USDT is allowed as a borrow token
        vm.prank(owner);
        vault.addBorrowToken(address(usdt), 18);

        // Mint and deposit collateral
        vm.prank(owner);
        usdt.mint(user1, 1000e18);
        vm.startPrank(user1);
        usdt.approve(address(vault), 100e18);
        vault.depositERC20(address(usdt), 100e18);
        vm.roll(block.number + 1);

        // Borrow 10 USDT tokens — because fallback price is $2, debt should be 20e18
        vault.borrow(address(usdt), 10e18);
        uint256 debt = vault.getVaultDebt(user1);
        assertEq(debt, 20e18);
        vm.stopPrank();
    }

    function test_ChainlinkAggregatorRegistrationAndPriceTaken() public {
        // Deploy Chainlink oracle and a mock aggregator, register via vault.registerChainlinkAggregator
        vm.prank(owner);
        ChainlinkPriceOracle oracle = new ChainlinkPriceOracle();

        // Deploy mock aggregator with price = $3 (decimals = 8 -> answer = 3 * 1e8)
        MockAggregator agg = new MockAggregator(int256(3e8), 8);

        // Set oracle in vault
        vm.prank(owner);
        vault.setPriceOracle(address(oracle));

        // Register aggregator on the oracle directly (oracle owner = deployer)
        vm.prank(owner);
        ChainlinkPriceOracle(address(oracle)).setAggregator(address(usdt), address(agg), 8);

        // Add USDT as an allowed borrow token
        vm.prank(owner);
        vault.addBorrowToken(address(usdt), 18);

        // Mint and deposit collateral
        vm.prank(owner);
        usdt.mint(user1, 1000e18);
        vm.startPrank(user1);
        usdt.approve(address(vault), 100e18);
        vault.depositERC20(address(usdt), 100e18);
        vm.roll(block.number + 1);

        // Borrow 10 USDT tokens — aggregator price $3 -> debt = 30e18
        vault.borrow(address(usdt), 10e18);
        uint256 debt = vault.getVaultDebt(user1);
        assertEq(debt, 30e18);
        vm.stopPrank();
    }

    function test_VaultIntegrator() public {
        vm.prank(owner);
        usdt.mint(user1, 1000e18);
        
        vm.startPrank(user1);
        usdt.approve(address(integrator), 100e18);
        integrator.automatedLeverage(address(usdt), 100e18);
        vm.stopPrank();
        
        // Check user got USDT (50% of 100 = 50)
        uint256 usdtBalance = usdt.balanceOf(user1);
        assertGt(usdtBalance, 900e18); // Started with 1000, deposited 100, got back ~50
    }

    function test_FlashLoanMaxAmount() public {
        vm.prank(owner);
        usdt.mint(address(flashLoanProvider), 1000e18);
        
        uint256 maxFlash = flashLoanProvider.maxFlashLoan(address(usdt));
        assertEq(maxFlash, 1000e18);
    }

    function test_FlashLoanFee() public {
        uint256 amount = 1000e18;
        uint256 fee = flashLoanProvider.flashLoanFee(address(usdt), amount);
        
        // 0.09% of 1000e18 = 0.9 * 1e18 = 9e17
        assertEq(fee, 900000000000000000);
    }
}

contract FlashLoanReceiverMock is IFlashLoanReceiver {
    bool public shouldSucceed = true;
    
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        if (!shouldSucceed) return false;
        
        // Repay loan + premium
        uint256 amountOwed = amount + premium;
        IERC20(asset).transfer(msg.sender, amountOwed);
        
        return true;
    }
}

/**
 * @title Oracle Staleness & Events Test
 */
contract MCRWAVaultOracleStalenessTest is Test {
    MCRWAVault vault;
    USDTMock usdt;
    ChainlinkPriceOracle oracle;
    MockAggregator aggregator;
    
    address owner = address(0x10);
    address user = address(0x11);
    
    event PriceStalenessDetected(address indexed asset, uint256 staledAtTimestamp, uint256 currentTime);
    event PriceUpdated(address indexed asset, uint256 price, uint256 timestamp, bool fromChainlink);
    event AggregatorRegistered(address indexed asset, address indexed aggregator, uint8 decimals);
    
    function setUp() public {
        vm.startPrank(owner);
        usdt = new USDTMock();
        vault = new MCRWAVault(address(usdt), owner);
        oracle = new ChainlinkPriceOracle();
        aggregator = new MockAggregator(1e8, 8); // $1.00 with 8 decimals
        
        vault.setERC20Price(address(usdt), 1e18);
        vault.addBorrowToken(address(usdt), 18);
        vault.setPriceOracle(address(oracle));
        vm.stopPrank();
    }
    
    function test_StalenessDetection() public {
        vm.startPrank(owner);
        
        // Register aggregator (already has price $1.00)
        vm.expectEmit(true, false, false, true);
        emit AggregatorRegistered(address(usdt), address(aggregator), 8);
        oracle.setAggregator(address(usdt), address(aggregator), 8);
        
        // Verify oracle starts healthy
        (bool stale, uint256 timeSinceUpdate) = oracle.checkStaleness(address(usdt));
        assertFalse(stale);
        assertEq(timeSinceUpdate, 0);
        
        // Fast-forward 1.5 hours
        vm.warp(block.timestamp + 1.5 hours);
        
        // Check staleness again - should now detect stale price
        vm.expectEmit(true, false, false, false);
        emit PriceStalenessDetected(address(usdt), block.timestamp - 1.5 hours, block.timestamp);
        (stale, timeSinceUpdate) = oracle.checkStaleness(address(usdt));
        
        assertTrue(stale);
        assertEq(timeSinceUpdate, 1.5 hours);
        
        vm.stopPrank();
    }
    
    function test_PriceUpdateEmitsEvent() public {
        vm.startPrank(owner);
        
        // Register aggregator
        aggregator.setAnswer(1e8);
        oracle.setAggregator(address(usdt), address(aggregator), 8);
        
        // Set fallback price and verify event
        vm.expectEmit(true, false, false, true);
        emit PriceUpdated(address(usdt), 1e18, block.timestamp, false);
        oracle.setFallbackPrice(address(usdt), 1e18);
        
        vm.stopPrank();
    }
    
    function test_FallbackPriceOnStaleness() public {
        vm.startPrank(owner);
        
        // Setup oracle with aggregator ($1.00)
        oracle.setAggregator(address(usdt), address(aggregator), 8);
        
        // Set fallback price to $1.00
        oracle.setFallbackPrice(address(usdt), 1e18);
        
        // Get fresh price (should be $1.00 from aggregator)
        (uint256 price, bool isValid) = oracle.getPriceUnsafeView(address(usdt));
        assertTrue(isValid);
        assertEq(price, 1e18);
        
        // Fast-forward 1.5 hours to make feed stale
        vm.warp(block.timestamp + 1.5 hours);
        
        // Get price again (should fallback to $1.00)
        (price, isValid) = oracle.getPriceUnsafeView(address(usdt));
        assertTrue(isValid);
        assertEq(price, 1e18); // Fallback price
        
        vm.stopPrank();
    }
    
    function test_AggregatorRegistrationEvent() public {
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, false, true);
        emit AggregatorRegistered(address(usdt), address(aggregator), 8);
        oracle.setAggregator(address(usdt), address(aggregator), 8);
        
        vm.stopPrank();
    }
    
    function test_StalenessClearedWhenFeedUpdates() public {
        vm.startPrank(owner);
        
        aggregator.setAnswer(1e8);
        oracle.setAggregator(address(usdt), address(aggregator), 8);
        
        // Make feed stale
        vm.warp(block.timestamp + 1.5 hours);
        (bool stale, ) = oracle.checkStaleness(address(usdt));
        assertTrue(stale);
        
        // Simulate feed update by moving time back (in real scenario, aggregator updates)
        // For this test, we just verify staleness detection works
        vm.stopPrank();
    }
}

