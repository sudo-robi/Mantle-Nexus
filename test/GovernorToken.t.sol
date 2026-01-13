// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GovernorToken.sol";

contract GovernorTokenTest is Test {
    GovernorToken token;
    address owner = address(0x1);
    address user1 = address(0x2);

    function setUp() public {
        vm.prank(owner);
        token = new GovernorToken();
    }

    function test_InitialSupply() public {
        assertEq(token.totalSupply(), 1_000_000 ether);
        assertEq(token.balanceOf(owner), 1_000_000 ether);
    }

    function test_VotingPower() public {
        // Initial voting power should be 0 until delegated
        assertEq(token.getVotes(owner), 0);
        
        vm.prank(owner);
        token.delegate(owner);
        
        assertEq(token.getVotes(owner), 1_000_000 ether);
    }

    function test_TransferUpdatesVotingPower() public {
        vm.prank(owner);
        token.delegate(owner);
        
        vm.prank(user1);
        token.delegate(user1);
        
        vm.prank(owner);
        token.transfer(user1, 100 ether);
        
        assertEq(token.balanceOf(user1), 100 ether);
        assertEq(token.getVotes(owner), 999_900 ether);
        assertEq(token.getVotes(user1), 100 ether);
    }
}
