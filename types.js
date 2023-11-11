// for figuring out eip-712

const typedMessage = {
  primaryType: "RankedSettleInput",
  domain: {
    name: "MadFi Bounties",
    version: "1",
  },

  types: {
    EIP712Domain: [
      { name: "name", type: "string" },
      { name: "version", type: "string" },
      { name: "chainId", type: "uint256" },
      { name: "verifyingContract", type: "address" },
    ],
    RankedSettleInput: [
      { name: "bountyId", type: "uint256" },
      { name: "bid", type: "uint256" },
      { name: "recipient", type: "address" },
      { name: "revShare", type: "uint256" },
      { name: "postParams", type: "PostParams" },
      { name: "mirrorParams", type: "MirrorParams" },
      { name: "followParams", type: "FollowParams" },
    ],
    PostParams: [
      { name: "profileId", type: "uint256" },
      { name: "contentURI", type: "string" },
      { name: "actionModules", type: "address[]" },
      { name: "actionModulesInitDatas", type: "bytes[]" },
      { name: "referenceModule", type: "address" },
      { name: "referenceModuleInitData", type: "bytes" },
    ],
    MirrorParams: [
      { name: "profileId", type: "uint256" },
      { name: "metadataURI", type: "string" },
      { name: "pointedProfileId", type: "uint256" },
      { name: "pointedPubId", type: "uint256" },
      { name: "referrerProfileIds", type: "uint256[]" },
      { name: "referrerPubIds", type: "uint256[]" },
      { name: "referenceModuleData", type: "bytes" },
    ],
    FollowParams: [
      { name: "datas", type: "bytes[]" },
      { name: "followTokenIds", type: "uint256[]" },
      { name: "followerProfileId", type: "uint256" },
      { name: "idsOfProfilesToFollow", type: "uint256[]" },
    ],
  },
};

module.exports = typedMessage;
