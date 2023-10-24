// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

contract Constants {
    uint8 public immutable BOUNTY_CREATE_REWARD_ENUM = 3; // to give XP on madfi badge

    uint8 public immutable BID_ACCEPT_REWARD_ENUM = 4;

    bytes32 immutable DOMAIN_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 immutable NAME_HASH = keccak256(bytes("MadFi Bounties"));

    bytes32 immutable VERSION_HASH = keccak256(bytes("1"));

    bytes32 immutable PARAMS_HASH =
        keccak256("PaymentParams(uint256 bountyId,address recipient,uint256 bid,uint256 revShare)");
}
