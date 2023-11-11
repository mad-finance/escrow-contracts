// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./MockToken.sol";

contract MockSuperToken is MockToken {
    address public underlying;

    constructor(address _underlying) MockToken() {
        underlying = _underlying;
    }

    function getUnderlyingToken() external view returns (address) {
        return underlying;
    }

    function upgrade(uint256 amount) external {
        MockToken(underlying).transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }
}
