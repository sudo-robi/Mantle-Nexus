// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MCVault} from "../src/MCVault.sol";
import {VaultIntegrator} from "../src/VaultIntegrator.sol";
import {USDTMock} from "../src/USDTMock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VaultComposabilityTest is Test {
    MCRWAVault vault;
    VaultIntegrator integrator;
    USDTMock usdt;
    ERC20 collateral;

    address user = address(0xABC);
    address owner = address(0x123);

    function setUp() public {
        vm.startPrank(owner);
        usdt = new USDTMock();
        vault = new MCRWAVault(address(usdt), owner);
        integrator = new VaultIntegrator(address(vault), address(usdt));
        collateral = new USDTMock(); 
        vault.setERC20Price(address(collateral), 1); 
        vault.addBorrowToken(address(usdt), 18);
        vm.stopPrank();
    }

    function testIntegratorFlow() public {
        uint256 depositAmount = 1000e18;
        deal(address(collateral), user, depositAmount);
        vm.startPrank(user);
        collateral.approve(address(integrator), depositAmount);
        integrator.automatedLeverage(address(collateral), depositAmount);
        uint256 vUSDTBal = vault.balanceOf(address(integrator));
        assertEq(vUSDTBal, depositAmount);
        console.log("vUSDT Minted to Integrator:", vUSDTBal);
        uint256 userUSDT = usdt.balanceOf(user);
        assertEq(userUSDT, depositAmount / 2);
        console.log("USDT Borrowed by User via Integrator:", userUSDT);
        vm.stopPrank();
    }
}