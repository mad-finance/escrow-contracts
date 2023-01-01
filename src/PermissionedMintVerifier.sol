// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "openzeppelin/utils/cryptography/ECDSA.sol";
import "openzeppelin/access/Ownable.sol";

interface IZKEditions {
    function zkClaim(address recipient) external;
}

contract PermissionedMintVerifier is Ownable {
    address public notary;

    mapping(uint256 => bool) public usedNonces;
    mapping(uint256 => address) public groupIdCollections;

    event GroupCreated(
        uint256 groupId,
        address collection,
        uint256 lensPubId,
        uint256 lensProfileId
    );

    event NonceUsed(uint256 indexed nonce);

    constructor() Ownable() {
        setNotary(_msgSender());
    }

    function createGroup(
        uint256 groupId,
        address dcntCollection,
        uint256 lensPubId,
        uint256 lensProfileId
    ) external {
        require(
            groupIdCollections[groupId] == address(0),
            "group already exists"
        );

        groupIdCollections[groupId] = dcntCollection;

        emit GroupCreated(groupId, dcntCollection, lensPubId, lensProfileId);
    }

    /// @notice allows a user to mint an nft
    function mint(
        address recipient,
        uint256 nonce,
        uint256 groupId,
        bytes memory signature
    ) public {
        bytes32 hash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encode(address(this), recipient, nonce))
        );

        if (notary != ECDSA.recover(hash, signature)) {
            revert InvalidNotarization();
        }
        if (usedNonces[nonce]) {
            revert NonceReused();
        }

        usedNonces[nonce] = true;
        IZKEditions(groupIdCollections[groupId]).zkClaim(recipient);

        emit NonceUsed(nonce);
    }

    // ADMIN FUNCTIONS
    function setNotary(address _notary) public onlyOwner {
        notary = _notary;
    }

    // ERRORS
    error InvalidNotarization();
    error NonceReused();
}
