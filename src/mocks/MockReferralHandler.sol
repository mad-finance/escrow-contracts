// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract MockReferralHandler {
    function processBountyWithBadgeCreator(address, uint256 protocolFeeAmount, address)
        external
        pure
        returns (address referrer, uint256 referralAmount)
    {
        referralAmount = protocolFeeAmount / 2;
        referrer = address(123123);
    }
}
