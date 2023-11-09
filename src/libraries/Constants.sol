// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

contract Constants {
    uint8 internal constant BOUNTY_CREATE_REWARD_ENUM = 3; // to give XP on madfi badge
    uint8 internal constant BID_ACCEPT_REWARD_ENUM = 4;

    // EIP-712 type definitions
    string private constant EIP712_DOMAIN =
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)";
    string private constant RANKED_SETTLE_INPUT_TYPE =
        "RankedSettleInput(uint256 bountyId,uint256 bid,address recipient,uint256 revShare,PostParams postParams,MirrorParams mirrorParams,FollowParams followParams)";
    string private constant NFT_SETTLE_INPUT_TYPE =
        "NftSettleInput(uint256 bountyId,uint256 nonce,address recipient,PostParams postParams,MirrorParams mirrorParams,FollowParams followParams)";
    string private constant PAY_ONLY_INPUT_TYPE = "Bid(uint256 bountyId,uint256 bid,address recipient,uint256 revShare)";

    string private constant POST_PARAMS_TYPE =
        "PostParams(uint256 profileId,string contentURI,address[] actionModules,bytes[] actionModulesInitDatas,address referenceModule,bytes referenceModuleInitData)";
    string private constant MIRROR_PARAMS_TYPE =
        "MirrorParams(uint256 profileId,string metadataURI,uint256 pointedProfileId,uint256 pointedPubId,uint256[] referrerProfileIds,uint256[] referrerPubIds,bytes referenceModuleData)";
    string private constant FOLLOW_PARAMS_TYPE =
        "FollowParams(bytes[] datas,uint256[] followTokenIds,uint256 followerProfileId,uint256[] idsOfProfilesToFollow)";

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH = keccak256(abi.encodePacked(EIP712_DOMAIN));
    bytes32 internal constant RANKED_SETTLE_INPUT_TYPEHASH = keccak256(abi.encodePacked(RANKED_SETTLE_INPUT_TYPE));
    bytes32 internal constant NFT_SETTLE_INPUT_TYPEHASH = keccak256(abi.encodePacked(NFT_SETTLE_INPUT_TYPE));
    bytes32 internal constant PAY_ONLY_INPUT_TYPEHASH = keccak256(abi.encodePacked(PAY_ONLY_INPUT_TYPE));
    bytes32 internal constant POST_PARAMS_TYPEHASH = keccak256(abi.encodePacked(POST_PARAMS_TYPE));
    bytes32 internal constant MIRROR_PARAMS_TYPEHASH = keccak256(abi.encodePacked(MIRROR_PARAMS_TYPE));
    bytes32 internal constant FOLLOW_PARAMS_TYPEHASH = keccak256(abi.encodePacked(FOLLOW_PARAMS_TYPE));

    bytes32 internal immutable domainSeparator = keccak256(
        abi.encode(EIP712_DOMAIN_TYPEHASH, keccak256("MadFi Bounties"), keccak256("1"), block.chainid, address(this))
    );
}
