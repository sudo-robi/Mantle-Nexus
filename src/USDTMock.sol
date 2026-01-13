// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IBorrowToken.sol";

contract USDTMock is ERC20, Ownable, IBorrowToken {
    constructor() ERC20("USDT", "USDT") Ownable(msg.sender) {}

    function mint(address to, uint256 amount) external override {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external override {
        _burn(from, amount);
    }

    function decimals() public view override(ERC20, IBorrowToken) returns (uint8) {
        return 18;
    }
}
