// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "madfi-protocol/interfaces/IMadSBT.sol";

/**
 * Mock MADSBT for testing
 */
contract MockMadSBT {
    mapping(address => uint128) public points;

    function handleRewardsUpdate(
        address account,
        uint256, // collectionId
        uint256, // profileId
        IMadSBT.Action rewardEnum
    ) external {
        if (rewardEnum == IMadSBT.Action.CREATE_BOUNTY) {
            points[account] += 100;
        } else if (rewardEnum == IMadSBT.Action.ACCEPTED_BID) {
            points[account] += 25;
        }
    }
}
