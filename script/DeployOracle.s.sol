// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PriceOracle.sol";
import "../src/MCVault.sol";

contract DeployOracle is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address usdt = vm.envAddress("USDT_ADDRESS");
        address vaultAddr = vm.envAddress("VAULT_ADDRESS");

        vm.startBroadcast(pk);

        ChainlinkPriceOracle oracle = new ChainlinkPriceOracle();

        oracle.setFallbackPrice(usdt, 1e18);

        MCRWAVault(vaultAddr).setPriceOracle(address(oracle));

        console.log("Deployed ChainlinkPriceOracle:", address(oracle));
        console.log("Set fallback price for USDT and configured vault oracle");

        vm.stopBroadcast();
    }
}
