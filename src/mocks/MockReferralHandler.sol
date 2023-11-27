// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/**
 * Simple token contract for running tests
 */
contract MockReferralHandler {
    function processBountyWithBadgeCreator(address bidder, uint256 protocolFeeAmount, address token)
        external
        returns (address referrer, uint256 referralAmount)
    {
        return (address(0), 0);
    }
}
