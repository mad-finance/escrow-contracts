// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "madfi-protocol/interfaces/IMadSBT.sol";

/**
 * Mock MADSBT for testing
 */
contract MockMadSBT {
    mapping(address => uint128) public points;

    address public rewardsToken;

    constructor(address _rewardsToken) {
        rewardsToken = _rewardsToken;
    }

    function handleRewardsUpdate(address account, uint256, uint8 actionEnum) external {
        if (actionEnum == 3) {
            points[account] += 100;
        } else if (actionEnum == 4) {
            points[account] += 25;
        }
    }

    function distributeRewards(uint256 collectionId, uint256 revShareAmount) external {
        // do nothing
    }
}
