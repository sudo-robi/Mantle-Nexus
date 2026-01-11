// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/USDTMock.sol";
import "../src/CreditScore.sol";
import "../src/ZKAttestationUpdaterMock.sol";
import "../src/MCRWAVault.sol";

contract Demo is Script {
   function run() external {
    uint256 pk = vm.envUint("PRIVATE_KEY");
    address owner = vm.addr(pk);

    vm.startBroadcast(pk);

    USDTMock usdt = new USDTMock();

    CreditScore creditScore = new CreditScore(owner);

    ZKAttestationUpdaterMock updater = new ZKAttestationUpdaterMock(address(creditScore));
    creditScore.transferOwnership(address(updater));

    MCRWAVault vault = new MCRWAVault(address(usdt), owner);

    vm.stopBroadcast();
}
}