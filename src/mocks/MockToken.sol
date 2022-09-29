// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/ERC20.sol";

/**
 * Simple token contract for running tests
 */
contract MockToken is ERC20 {
    constructor() ERC20("MockToken", "MT") {
        mint(msg.sender, 100 ether);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}