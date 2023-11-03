// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "lens/interfaces/ILensProtocol.sol";
import {Typehash} from "lens/libraries/constants/TypeHash.sol";

contract LensHelper is Test {
    address lensHub = 0xC1E77eE73403B8a7478884915aA599932A677870; // lens hub proxy v2 preview

    string constant EIP712_DOMAIN_VERSION = "2";
    bytes32 constant EIP712_DOMAIN_VERSION_HASH = keccak256(bytes(EIP712_DOMAIN_VERSION));

    function _toAddressArray(address a) internal pure returns (address[] memory) {
        address[] memory ret = new address[](1);
        ret[0] = a;
        return ret;
    }

    function _toBytesArray(bytes memory b) internal pure returns (bytes[] memory) {
        bytes[] memory ret = new bytes[](1);
        ret[0] = b;
        return ret;
    }

    function _toBytesArray(bytes memory b0, bytes memory b1) internal pure returns (bytes[] memory) {
        bytes[] memory ret = new bytes[](2);
        ret[0] = b0;
        ret[1] = b1;
        return ret;
    }

    function _getSigStruct(uint256 pKey, bytes32 digest, uint256 deadline)
        internal
        pure
        returns (Types.EIP712Signature memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pKey, digest);
        return Types.EIP712Signature(vm.addr(pKey), v, r, s, deadline);
    }

    function _getPostTypedDataHash(Types.PostParams memory postParams, uint256 nonce, uint256 deadline)
        internal
        view
        returns (bytes32)
    {
        return _calculateDigest(
            keccak256(
                abi.encode(
                    Typehash.POST,
                    postParams.profileId,
                    _encodeUsingEip712Rules(postParams.contentURI),
                    _encodeUsingEip712Rules(postParams.actionModules),
                    _encodeUsingEip712Rules(postParams.actionModulesInitDatas),
                    postParams.referenceModule,
                    _encodeUsingEip712Rules(postParams.referenceModuleInitData),
                    nonce,
                    deadline
                )
            )
        );
    }

    function _calculateDigest(bytes32 structHash) internal view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                Typehash.EIP712_DOMAIN,
                keccak256("Lens Protocol Profiles"),
                EIP712_DOMAIN_VERSION_HASH,
                block.chainid,
                lensHub
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

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
        return _encodeUsingEip712Rules(bytesArrayEncodedElements);
    }

    function _encodeUsingEip712Rules(bool[] memory boolArray) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(boolArray));
    }

    function _encodeUsingEip712Rules(address[] memory addressArray) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(addressArray));
    }

    function _encodeUsingEip712Rules(uint256[] memory uint256Array) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(uint256Array));
    }

    function _encodeUsingEip712Rules(bytes32[] memory bytes32Array) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(bytes32Array));
    }

    function _encodeUsingEip712Rules(string memory stringValue) internal pure returns (bytes32) {
        return keccak256(bytes(stringValue));
    }

    function _encodeUsingEip712Rules(bytes memory bytesValue) internal pure returns (bytes32) {
        return keccak256(bytesValue);
    }
}
