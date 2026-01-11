// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/CreditScore.sol";
import "../src/ZKAttestationUpdaterMock.sol";
import "../src/MCRWAVault.sol";
import "../src/VaultIntegrator.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // This is your previous USDT address with the 1000k balance
        address oldUSDT = 0x915cC86fE0871835e750E93e025080FFf9927A3f; 

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Logic
        CreditScore creditScore = new CreditScore(deployer);
        
        // 2. Deploy Vault linked to the OLD USDT
        MCRWAVault vault = new MCRWAVault(oldUSDT, deployer);

        // 3. Deploy Integrator linked to the NEW Vault and OLD USDT
        VaultIntegrator integrator = new VaultIntegrator(address(vault), oldUSDT);
        
        // 4. Deploy Updater
        ZKAttestationUpdaterMock updater = new ZKAttestationUpdaterMock(address(creditScore));

        // 5. Configuration
        creditScore.transferOwnership(address(updater));
        updater.configureAttester();
        vault.setCreditScoreContract(address(creditScore));

        console.log("=== MANTLE-NEXUS RESTORED DEPLOYMENT ===");
        console.log("Using USDT: ", oldUSDT);
        console.log("New Vault: ", address(vault));
        console.log("New Integrator: ", address(integrator));
        
        vm.stopBroadcast();
    }
}