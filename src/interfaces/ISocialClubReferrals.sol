// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface ISocialClubReferrals {
    function processBountyWithBadgeCreator(
        address bidder,
        uint256 protocolFeeAmount,
        address token
    ) external returns (address referrer, uint256 referralAmount);
}
