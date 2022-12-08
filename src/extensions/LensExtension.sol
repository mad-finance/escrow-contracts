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

    struct MirrorWithSigData {
        uint256 profileId;
        uint256 profileIdPointed;
        uint256 pubIdPointed;
        bytes referenceModuleData;
        address referenceModule;
        bytes referenceModuleInitData;
        EIP712Signature sig;
    }

    struct CommentWithSigData {
        uint256 profileId;
        string contentURI;
        uint256 profileIdPointed;
        uint256 pubIdPointed;
        bytes referenceModuleData;
        address collectModule;
        bytes collectModuleInitData;
        address referenceModule;
        bytes referenceModuleInitData;
        EIP712Signature sig;
    }

    struct FollowWithSigData {
        address follower;
        uint256[] profileIds;
        bytes[] datas;
        EIP712Signature sig;
    }
}

interface ILensHub is DataTypes {
    function postWithSig(PostWithSigData calldata vars)
        external
        returns (uint256);

    function mirrorWithSig(DataTypes.MirrorWithSigData calldata vars)
        external
        returns (uint256);

    function commentWithSig(DataTypes.CommentWithSigData calldata vars)
        external
        returns (uint256);

    function followWithSig(DataTypes.FollowWithSigData calldata vars)
        external
        returns (uint256);
}

contract LensExtension is DataTypes {
    ILensHub internal lensHub;

    constructor(address _lensHub) {
        lensHub = ILensHub(_lensHub);
    }

    function postWithSigBatch(PostWithSigData[] calldata posts) internal {
        for (uint256 i = 0; i < posts.length; ++i) {
            lensHub.postWithSig(posts[i]);
        }
    }

    function mirrorWithSigBatch(MirrorWithSigData[] calldata posts) internal {
        for (uint256 i = 0; i < posts.length; ++i) {
            lensHub.mirrorWithSig(posts[i]);
        }
    }

    function commentWithSigBatch(CommentWithSigData[] calldata posts) internal {
        for (uint256 i = 0; i < posts.length; ++i) {
            lensHub.commentWithSig(posts[i]);
        }
    }

    function followWithSigBatch(FollowWithSigData[] calldata posts) internal {
        for (uint256 i = 0; i < posts.length; ++i) {
            lensHub.followWithSig(posts[i]);
        }
    }
}
