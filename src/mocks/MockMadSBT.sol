// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../interfaces/IMadSBT.sol";

/**
 * Mock MADSBT for testing
 */
contract MockMadSBT is IMadSBT {
    mapping(address => uint128) public points;

    function handleRewardsUpdate(
        address account,
        uint256 collectionId,
        uint256 profileId,
        uint128 amount
    ) external {
        points[account] += amount;
    }
}
