// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "openzeppelin/utils/cryptography/ECDSA.sol";

import "./Structs.sol";
import "./Constants.sol";

/**
 * @dev This contract contains functions for verifying signatures
 */
contract VerifySignatures is Constants {
    using ECDSA for bytes32;

    error InvalidSignature(address recoveredAddress);

    /**
     * @dev This is an internal function that verifies the signatures of the recipients
     * @param bountyId The ID of the bounty
     * @param data The array of RankedSettleInput structs
     */
    function _verifySignatures(uint256 bountyId, Structs.RankedSettleInput[] calldata data) internal view {
        for (uint256 i = 0; i < data.length;) {
            _recoverAddress(hashRankedSettleInput(bountyId, data[i]), data[i].recipient, data[i].signature);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev This is an internal function that verifies the signatures of the recipients
     * @param bountyId The ID of the bounty
     * @param data The array of BidFromAction structs
     */
    function _verifySignatures(uint256 bountyId, Structs.RankedSettleInputQuote[] calldata data) internal view {
        for (uint256 i = 0; i < data.length;) {
            _recoverAddress(hashRankedSettleInput(bountyId, data[i]), data[i].recipient, data[i].signature);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev This is an internal function that verifies the signatures of the recipients
     * @param bountyId The ID of the bounty
     * @param data The array of NftSettleInput structs
     */
    function _verifySignatures(uint256 bountyId, Structs.NftSettleInput[] calldata data) internal view {
        for (uint256 i = 0; i < data.length;) {
            _recoverAddress(hashNftSettleInput(bountyId, data[i]), data[i].recipient, data[i].signature);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev This is an internal function that verifies the signatures of the recipients
     * @param bountyId The ID of the bounty
     * @param data The array of NftSettleInputQuote structs
     */
    function _verifySignatures(uint256 bountyId, Structs.NftSettleInputQuote[] calldata data) internal view {
        for (uint256 i = 0; i < data.length;) {
            _recoverAddress(hashNftSettleInput(bountyId, data[i]), data[i].recipient, data[i].signature);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev This is an internal function that verifies the signatures of the recipients
     * @param bountyId The ID of the bounty
     * @param data The array of BidFromAction structs
     * @param signatures The array of signatures
     */
    function _verifySignatures(uint256 bountyId, Structs.BidFromAction[] calldata data, bytes[] calldata signatures)
        internal
        view
    {
        for (uint256 i = 0; i < data.length;) {
            _recoverAddress(hashBidFromActionInput(bountyId, data[i]), data[i].recipient, signatures[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev This is an internal function that recovers the address of the signer
     * @param messageHash The hash of the message
     * @param recipient The address of the recipient
     * @param signature The signature of the recipient
     */
    function _recoverAddress(bytes32 messageHash, address recipient, bytes memory signature) internal view {
        bytes32 typedDataHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, messageHash));
        address recoveredAddress = ECDSA.recover(typedDataHash, signature);
        if (recipient != recoveredAddress) {
            revert InvalidSignature(recoveredAddress);
        }
    }

    function hashLensInputs(Types.PostParams memory postParams) private pure returns (bytes32 postParamsHash) {
        postParamsHash = keccak256(
            abi.encode(
                POST_PARAMS_TYPEHASH,
                postParams.profileId,
                keccak256(bytes(postParams.contentURI)),
                keccak256(abi.encodePacked(postParams.actionModules)),
                _encodeUsingEip712Rules(postParams.actionModulesInitDatas),
                postParams.referenceModule,
                keccak256(postParams.referenceModuleInitData)
            )
        );
    }

    function hashLensInputs(Types.QuoteParams memory quoteParams) private pure returns (bytes32 quoteParamsHash) {
        quoteParamsHash = keccak256(
            abi.encode(
                QUOTE_PARAMS_TYPEHASH,
                quoteParams.profileId,
                keccak256(bytes(quoteParams.contentURI)),
                quoteParams.pointedProfileId,
                quoteParams.pointedPubId,
                keccak256(abi.encodePacked(quoteParams.referrerProfileIds)),
                keccak256(abi.encodePacked(quoteParams.referrerPubIds)),
                keccak256(quoteParams.referenceModuleData),
                keccak256(abi.encodePacked(quoteParams.actionModules)),
                _encodeUsingEip712Rules(quoteParams.actionModulesInitDatas),
                quoteParams.referenceModule,
                keccak256(quoteParams.referenceModuleInitData)
            )
        );
    }

    function hashLensInputs(Types.MirrorParams memory mirrorParams, Structs.FollowParams memory followParams)
        private
        pure
        returns (bytes32 mirrorParamsHash, bytes32 followParamsHash)
    {
        mirrorParamsHash = keccak256(
            abi.encode(
                MIRROR_PARAMS_TYPEHASH,
                mirrorParams.profileId,
                keccak256(bytes(mirrorParams.metadataURI)),
                mirrorParams.pointedProfileId,
                mirrorParams.pointedPubId,
                keccak256(abi.encodePacked(mirrorParams.referrerProfileIds)),
                keccak256(abi.encodePacked(mirrorParams.referrerPubIds)),
                keccak256(mirrorParams.referenceModuleData)
            )
        );

        followParamsHash = keccak256(
            abi.encode(
                FOLLOW_PARAMS_TYPEHASH,
                _encodeUsingEip712Rules(followParams.datas),
                keccak256(abi.encodePacked(followParams.followTokenIds)),
                followParams.followerProfileId,
                keccak256(abi.encodePacked(followParams.idsOfProfilesToFollow))
            )
        );
    }

    function hashRankedSettleInput(uint256 bountyId, Structs.RankedSettleInput memory input)
        private
        pure
        returns (bytes32)
    {
        (bytes32 postParamsHash) = hashLensInputs(input.postParams);
        (bytes32 mirrorParamsHash, bytes32 followParamsHash) = hashLensInputs(input.mirrorParams, input.followParams);
        return keccak256(
            abi.encode(
                RANKED_SETTLE_INPUT_TYPEHASH,
                bountyId,
                input.bid,
                input.bidderCollectionId,
                input.recipient,
                input.revShare,
                postParamsHash,
                mirrorParamsHash,
                followParamsHash
            )
        );
    }

    function hashRankedSettleInput(uint256 bountyId, Structs.RankedSettleInputQuote memory input)
        private
        pure
        returns (bytes32)
    {
        (bytes32 quoteParamsHash) = hashLensInputs(input.quoteParams);
        (bytes32 mirrorParamsHash, bytes32 followParamsHash) = hashLensInputs(input.mirrorParams, input.followParams);
        return keccak256(
            abi.encode(
                RANKED_SETTLE_INPUT_QUOTE_TYPEHASH,
                bountyId,
                input.bid,
                input.bidderCollectionId,
                input.recipient,
                input.revShare,
                quoteParamsHash,
                mirrorParamsHash,
                followParamsHash
            )
        );
    }

    function hashNftSettleInput(uint256 bountyId, Structs.NftSettleInput memory input) private pure returns (bytes32) {
        (bytes32 postParamsHash) = hashLensInputs(input.postParams);
        (bytes32 mirrorParamsHash, bytes32 followParamsHash) = hashLensInputs(input.mirrorParams, input.followParams);
        return keccak256(
            abi.encode(
                NFT_SETTLE_INPUT_TYPEHASH,
                bountyId,
                input.nonce,
                input.recipient,
                postParamsHash,
                mirrorParamsHash,
                followParamsHash
            )
        );
    }

    function hashNftSettleInput(uint256 bountyId, Structs.NftSettleInputQuote memory input)
        private
        pure
        returns (bytes32)
    {
        (bytes32 quoteParamsHash) = hashLensInputs(input.quoteParams);
        (bytes32 mirrorParamsHash, bytes32 followParamsHash) = hashLensInputs(input.mirrorParams, input.followParams);
        return keccak256(
            abi.encode(
                NFT_SETTLE_INPUT_QUOTE_TYPEHASH,
                bountyId,
                input.nonce,
                input.recipient,
                quoteParamsHash,
                mirrorParamsHash,
                followParamsHash
            )
        );
    }

    function hashBidFromActionInput(uint256 bountyId, Structs.BidFromAction memory input)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                PAY_ONLY_INPUT_TYPEHASH, bountyId, input.bid, input.bidderCollectionId, input.recipient, input.revShare
            )
        );
    }

    /**
     * @dev This is an internal function that encodes an array of `bytes` using EIP712 rules.
     * @param bytesArray The array of `bytes` to encode.
     */
    function _encodeUsingEip712Rules(bytes[] memory bytesArray) internal pure returns (bytes32) {
        bytes32[] memory bytesArrayEncodedElements = new bytes32[](bytesArray.length);
        uint256 i;
        while (i < bytesArray.length) {
            // A `bytes` type is encoded as its keccak256 hash.
            bytesArrayEncodedElements[i] = keccak256(bytesArray[i]);
            unchecked {
                ++i;
            }
        }
        // An array is encoded as the keccak256 hash of the concatenation of their encoded elements.
        return keccak256(abi.encodePacked(bytesArrayEncodedElements));
    }
}
