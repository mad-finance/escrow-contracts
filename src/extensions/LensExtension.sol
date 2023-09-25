// SPDX-License-Identifier: MIT
/*

__/\\\______________/\\\\\\\\\\\\\\\__/\\\\\_____/\\\_____/\\\\\\\\\\\______________/\\\________/\\\____/\\\\\\\\\_____        
 _\/\\\_____________\/\\\///////////__\/\\\\\\___\/\\\___/\\\/////////\\\___________\/\\\_______\/\\\__/\\\///////\\\___       
  _\/\\\_____________\/\\\_____________\/\\\/\\\__\/\\\__\//\\\______\///____________\//\\\______/\\\__\///______\//\\\__      
   _\/\\\_____________\/\\\\\\\\\\\_____\/\\\//\\\_\/\\\___\////\\\____________________\//\\\____/\\\_____________/\\\/___     
    _\/\\\_____________\/\\\///////______\/\\\\//\\\\/\\\______\////\\\__________________\//\\\__/\\\___________/\\\//_____    
     _\/\\\_____________\/\\\_____________\/\\\_\//\\\/\\\_________\////\\\________________\//\\\/\\\_________/\\\//________   
      _\/\\\_____________\/\\\_____________\/\\\__\//\\\\\\__/\\\______\//\\\________________\//\\\\\________/\\\/___________  
       _\/\\\\\\\\\\\\\\\_\/\\\\\\\\\\\\\\\_\/\\\___\//\\\\\_\///\\\\\\\\\\\/__________________\//\\\________/\\\\\\\\\\\\\\\_ 
        _\///////////////__\///////////////__\///_____\/////____\///////////_____________________\///________\///////////////__
*/

pragma solidity ^0.8.10;

import "lens/interfaces/ILensProtocol.sol";

contract LensExtension {
    ILensProtocol internal lensHub;

    // follow data isn't organized as a struct on the lens hub so I'm doing it here
    struct FollowWithSigData {
        uint256 followerProfileId;
        uint256[] idsOfProfilesToFollow;
        uint256[] followTokenIds;
        bytes[] datas;
    }

    constructor(address _lensHub) {
        lensHub = ILensProtocol(_lensHub);
    }

    function postWithSigBatch(Types.PostParams[] calldata postParams, Types.EIP712Signature[] calldata signatures)
        public
    {
        require(postParams.length == signatures.length, "LensExtension: invalid length");
        uint256 length = signatures.length;
        for (uint256 i = 0; i < length;) {
            lensHub.postWithSig(postParams[i], signatures[i]);
            unchecked {
                ++i;
            }
        }
    }

    function mirrorWithSigBatch(Types.MirrorParams[] calldata mirrorParams, Types.EIP712Signature[] calldata signatures)
        public
    {
        require(mirrorParams.length == signatures.length, "LensExtension: invalid length");
        uint256 length = signatures.length;
        for (uint256 i = 0; i < length;) {
            lensHub.mirrorWithSig(mirrorParams[i], signatures[i]);
            unchecked {
                ++i;
            }
        }
    }

    function commentWithSigBatch(
        Types.CommentParams[] calldata commentParams,
        Types.EIP712Signature[] calldata signatures
    ) public {
        require(commentParams.length == signatures.length, "LensExtension: invalid length");
        uint256 length = signatures.length;
        for (uint256 i = 0; i < length;) {
            lensHub.commentWithSig(commentParams[i], signatures[i]);
            unchecked {
                ++i;
            }
        }
    }

    function followWithSigBatch(FollowWithSigData[] calldata followParams, Types.EIP712Signature[] calldata signatures)
        public
    {
        require(followParams.length == signatures.length, "LensExtension: invalid length");
        uint256 length = signatures.length;
        for (uint256 i = 0; i < length;) {
            lensHub.followWithSig(
                followParams[i].followerProfileId,
                followParams[i].idsOfProfilesToFollow,
                followParams[i].followTokenIds,
                followParams[i].datas,
                signatures[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    function collectWithSigBatch(
        Types.CollectParams[] calldata collectParams,
        Types.EIP712Signature[] calldata signatures
    ) public {
        require(collectParams.length == signatures.length, "LensExtension: invalid length");
        uint256 length = signatures.length;
        for (uint256 i = 0; i < length;) {
            lensHub.collectWithSig(collectParams[i], signatures[i]);
            unchecked {
                ++i;
            }
        }
    }
}
