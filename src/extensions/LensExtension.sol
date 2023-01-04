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

    struct CollectWithSigData {
        address collector;
        uint256 profileId;
        uint256 pubId;
        bytes data;
        EIP712Signature sig;
    }
}

interface ILensHub is DataTypes {
    function postWithSig(PostWithSigData calldata vars) external returns (uint256);

    function mirrorWithSig(MirrorWithSigData calldata vars) external returns (uint256);

    function commentWithSig(CommentWithSigData calldata vars) external returns (uint256);

    function followWithSig(FollowWithSigData calldata vars) external returns (uint256);

    function collectWithSig(CollectWithSigData calldata vars) external returns (uint256);
}

contract LensExtension is DataTypes {
    ILensHub internal lensHub;

    constructor(address _lensHub) {
        lensHub = ILensHub(_lensHub);
    }

    function postWithSigBatch(PostWithSigData[] calldata data) public {
        uint256 length = data.length;
        for (uint256 i = 0; i < length;) {
            lensHub.postWithSig(data[i]);
            unchecked {
                ++i;
            }
        }
    }

    function mirrorWithSigBatch(MirrorWithSigData[] calldata data) public {
        uint256 length = data.length;
        for (uint256 i = 0; i < length;) {
            lensHub.mirrorWithSig(data[i]);
            unchecked {
                ++i;
            }
        }
    }

    function commentWithSigBatch(CommentWithSigData[] calldata data) public {
        uint256 length = data.length;
        for (uint256 i = 0; i < length;) {
            lensHub.commentWithSig(data[i]);
            unchecked {
                ++i;
            }
        }
    }

    function followWithSigBatch(FollowWithSigData[] calldata data) public {
        uint256 length = data.length;
        for (uint256 i = 0; i < length;) {
            lensHub.followWithSig(data[i]);
            unchecked {
                ++i;
            }
        }
    }

    function collectWithSigBatch(CollectWithSigData[] calldata data) public {
        uint256 length = data.length;
        for (uint256 i = 0; i < length;) {
            lensHub.collectWithSig(data[i]);
            unchecked {
                ++i;
            }
        }
    }
}
