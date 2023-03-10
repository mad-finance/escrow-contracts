// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IMadSBT {
    function handleRewardsUpdate(
        address account,
        uint256 collectionId,
        uint256 profileId,
        uint128 amount
    ) external;
}
