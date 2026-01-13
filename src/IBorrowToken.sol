// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBorrowToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function decimals() external view returns (uint8);
}
