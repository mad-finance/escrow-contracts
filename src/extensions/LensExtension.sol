// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface DataTypes {
    struct EIP712Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 deadline;
    }

    struct PostWithSigData {
        uint256 profileId;
        string contentURI;
        address collectModule;
        bytes collectModuleInitData;
        address referenceModule;
        bytes referenceModuleInitData;
        EIP712Signature sig;
    }
}

interface ILensHub is DataTypes {
    function postWithSig(PostWithSigData calldata vars)
        external
        returns (uint256);
}

contract LensExtension is DataTypes {
    address internal lensHubAddress;

    constructor(address _lensHub) {
        lensHubAddress = _lensHub;
    }

    function postWithSigBatch(PostWithSigData[] calldata posts) internal {
        ILensHub lensHub = ILensHub(lensHubAddress);
        for (uint256 i = 0; i < posts.length; ++i) {
            lensHub.postWithSig(posts[i]);
        }
    }
}
