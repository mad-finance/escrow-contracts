// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

contract Constants {
    uint8 internal constant BOUNTY_CREATE_REWARD_ENUM = 3; // to give XP on madfi badge
    uint8 internal constant BID_ACCEPT_REWARD_ENUM = 4;

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant RANKED_SETTLE_INPUT_TYPEHASH = keccak256(
        "RankedSettleInput(uint256 bountyId,uint256 bid,address recipient,uint256 revShare,PostParams postParams,MirrorParams mirrorParams,FollowParams followParams)FollowParams(bytes[] datas,uint256[] followTokenIds,uint256 followerProfileId,uint256[] idsOfProfilesToFollow)MirrorParams(uint256 profileId,string metadataURI,uint256 pointedProfileId,uint256 pointedPubId,uint256[] referrerProfileIds,uint256[] referrerPubIds,bytes referenceModuleData)PostParams(uint256 profileId,string contentURI,address[] actionModules,bytes[] actionModulesInitDatas,address referenceModule,bytes referenceModuleInitData)"
    );
    bytes32 internal constant NFT_SETTLE_INPUT_TYPEHASH = keccak256(
        "NftSettleInput(uint256 bountyId,uint256 nonce,address recipient,PostParams postParams,MirrorParams mirrorParams,FollowParams followParams)FollowParams(bytes[] datas,uint256[] followTokenIds,uint256 followerProfileId,uint256[] idsOfProfilesToFollow)MirrorParams(uint256 profileId,string metadataURI,uint256 pointedProfileId,uint256 pointedPubId,uint256[] referrerProfileIds,uint256[] referrerPubIds,bytes referenceModuleData)PostParams(uint256 profileId,string contentURI,address[] actionModules,bytes[] actionModulesInitDatas,address referenceModule,bytes referenceModuleInitData)"
    );
    bytes32 internal constant PAY_ONLY_INPUT_TYPEHASH =
        keccak256("Bid(uint256 bountyId,uint256 bid,address recipient,uint256 revShare)");
    bytes32 internal constant POST_PARAMS_TYPEHASH = keccak256(
        "PostParams(uint256 profileId,string contentURI,address[] actionModules,bytes[] actionModulesInitDatas,address referenceModule,bytes referenceModuleInitData)"
    );
    bytes32 internal constant MIRROR_PARAMS_TYPEHASH = keccak256(
        "MirrorParams(uint256 profileId,string metadataURI,uint256 pointedProfileId,uint256 pointedPubId,uint256[] referrerProfileIds,uint256[] referrerPubIds,bytes referenceModuleData)"
    );
    bytes32 internal constant FOLLOW_PARAMS_TYPEHASH = keccak256(
        "FollowParams(bytes[] datas,uint256[] followTokenIds,uint256 followerProfileId,uint256[] idsOfProfilesToFollow)"
    );

    bytes32 internal immutable domainSeparator = keccak256(
        abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            keccak256(bytes("MadFi Bounties")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        )
    );
}
