// SPDX-License-Identifier: MIT

import "lens/libraries/DataTypes.sol";

pragma solidity ^0.8.10;

interface ILensHub {
    function postWithSig(DataTypes.PostWithSigData calldata vars) external returns (uint256);

    function mirrorWithSig(DataTypes.MirrorWithSigData calldata vars) external returns (uint256);

    function commentWithSig(DataTypes.CommentWithSigData calldata vars) external returns (uint256);

    function followWithSig(DataTypes.FollowWithSigData calldata vars) external returns (uint256);

    function collectWithSig(DataTypes.CollectWithSigData calldata vars) external returns (uint256);
}

contract LensExtension {
    ILensHub internal lensHub;

    constructor(address _lensHub) {
        lensHub = ILensHub(_lensHub);
    }

    function postWithSigBatch(DataTypes.PostWithSigData[] calldata data) public {
        uint256 length = data.length;
        for (uint256 i = 0; i < length;) {
            lensHub.postWithSig(data[i]);
            unchecked {
                ++i;
            }
        }
    }

    function mirrorWithSigBatch(DataTypes.MirrorWithSigData[] calldata data) public {
        uint256 length = data.length;
        for (uint256 i = 0; i < length;) {
            lensHub.mirrorWithSig(data[i]);
            unchecked {
                ++i;
            }
        }
    }

    function commentWithSigBatch(DataTypes.CommentWithSigData[] calldata data) public {
        uint256 length = data.length;
        for (uint256 i = 0; i < length;) {
            lensHub.commentWithSig(data[i]);
            unchecked {
                ++i;
            }
        }
    }

    function followWithSigBatch(DataTypes.FollowWithSigData[] calldata data) public {
        uint256 length = data.length;
        for (uint256 i = 0; i < length;) {
            lensHub.followWithSig(data[i]);
            unchecked {
                ++i;
            }
        }
    }

    function collectWithSigBatch(DataTypes.CollectWithSigData[] calldata data) public {
        uint256 length = data.length;
        for (uint256 i = 0; i < length;) {
            lensHub.collectWithSig(data[i]);
            unchecked {
                ++i;
            }
        }
    }
}
