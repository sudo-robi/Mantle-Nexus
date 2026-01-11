// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MCRWAVault} from "../src/MCRWAVault.sol";
import {VaultIntegrator} from "../src/VaultIntegrator.sol";
import {USDTMock} from "../src/USDTMock.sol";

contract DeployVaultSystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        USDTMock usdt = new USDTMock();
        console.log("USDTMock deployed at:", address(usdt));
        MCRWAVault vault = new MCRWAVault(address(usdt), owner);
        console.log("MCRWAVault deployed at:", address(vault));
        VaultIntegrator integrator = new VaultIntegrator(address(vault), address(usdt));
        console.log("VaultIntegrator deployed at:", address(integrator));
        vm.stopBroadcast();
        console.log("--- DEPLOYMENT COMPLETE ---");
        console.log("Vault Receipt Token (vUSDT) is now active.");
    }
}