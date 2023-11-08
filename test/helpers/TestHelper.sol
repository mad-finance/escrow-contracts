// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "lens/interfaces/ILensProtocol.sol";
import {Typehash} from "lens/libraries/constants/TypeHash.sol";

import "openzeppelin/utils/cryptography/ECDSA.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

import "madfi-protocol/interfaces/ISuperToken.sol";

import "../../src/Bounties.sol";
import "../../src/RewardNft.sol";
import "../../src/extensions/Constants.sol";

import "../../src/mocks/MockMadSBT.sol";
import "../../src/mocks/MockRouter.sol";
import "../../src/mocks/MockSuperToken.sol";

interface ILensHubTest {
    function changeDelegatedExecutorsConfig(
        uint256 delegatorProfileId,
        address[] calldata delegatedExecutors,
        bool[] calldata approvals
    ) external;
}

contract TestHelper is Test, Constants {
    using ECDSA for bytes32;

    uint256 polygonFork;

    Bounties bounties;
    RewardNft rewardNft;
    MockMadSBT mockMadSBT;

    address swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // uniswap swap router

    ERC20 usdc = ERC20(0xbe49ac1EadAc65dccf204D4Df81d650B50122aB2);
    ERC20 wmatic = ERC20(0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889);
    ISuperToken superUsdc = ISuperToken(0x42bb40bF79730451B11f6De1CbA222F17b87Afd7);

    address lensHub = 0xC1E77eE73403B8a7478884915aA599932A677870;

    address defaultSender = address(69);

    uint256 public bidderPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; // hardhat account 1
    uint256 public bidderPrivateKey2 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d; // hardhat account 2
    address public bidderAddress = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public bidderAddress2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    uint256 bidderProfileId = 236;
    uint256 bidderProfileId2 = 819;

    uint256 bidAmount1 = 75_000;
    uint256 bidAmount2 = 25_000;

    uint24 uniswapFee = 500; // 0.05% uniswap pool fee

    function setUp() public {
        polygonFork = vm.createFork(vm.envString("MUMBAI_RPC_URL"));
        vm.selectFork(polygonFork);

        mockMadSBT = new MockMadSBT(address(superUsdc));

        bounties = new Bounties(lensHub, 0, 0, address(swapRouter));
        rewardNft = new RewardNft(address(bounties));

        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        bounties.setRewardNft(address(rewardNft));

        setDelegatedExecutors(address(bounties));
    }

    function helperMintApproveTokens(uint256 bountyAmount, address recipient, ERC20 token) public {
        deal(address(token), recipient, bountyAmount);
        token.approve(address(bounties), type(uint256).max);
    }

    function createSettleData(uint256 newBountyId) internal view returns (Bounties.RankedSettleInput[] memory) {
        Types.PostParams memory post = Types.PostParams({
            profileId: bidderProfileId,
            contentURI: "ipfs://123",
            actionModules: new address[](0),
            actionModulesInitDatas: new bytes[](0),
            referenceModule: address(0),
            referenceModuleInitData: ""
        });

        Types.MirrorParams memory mirror = Types.MirrorParams({
            profileId: bidderProfileId,
            metadataURI: "ipfs://123",
            pointedProfileId: 349,
            pointedPubId: 0x04,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory idsOfProfilesToFollow = new uint256[](1);
        idsOfProfilesToFollow[0] = 349;
        Bounties.FollowParams memory follow = Bounties.FollowParams({
            followerProfileId: bidderProfileId,
            idsOfProfilesToFollow: idsOfProfilesToFollow,
            followTokenIds: new uint256[](1),
            datas: new bytes[](1)
        });

        Bounties.RankedSettleInput[] memory input = new Bounties.RankedSettleInput[](1);
        input[0] = Bounties.RankedSettleInput({
            bid: bidAmount1,
            recipient: bidderAddress,
            revShare: 0,
            signature: "",
            postParams: post,
            mirrorParams: mirror,
            followParams: follow
        });

        input[0].signature = createSignatures(newBountyId, input)[0];
        return input;
    }

    function createSettleDataTwoBidders(uint256 newBountyId, uint256 revShare)
        internal
        view
        returns (Bounties.RankedSettleInput[] memory)
    {
        Bounties.RankedSettleInput[] memory input = new Bounties.RankedSettleInput[](2);

        // bidder 1
        Types.PostParams memory post1 = Types.PostParams({
            profileId: bidderProfileId,
            contentURI: "ipfs://123",
            actionModules: new address[](0),
            actionModulesInitDatas: new bytes[](0),
            referenceModule: address(0),
            referenceModuleInitData: ""
        });

        Types.MirrorParams memory mirror1 = Types.MirrorParams({
            profileId: bidderProfileId,
            metadataURI: "ipfs://123",
            pointedProfileId: 349,
            pointedPubId: 0x04,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory idsOfProfilesToFollow1 = new uint256[](1);
        idsOfProfilesToFollow1[0] = 349;
        Bounties.FollowParams memory follow1 = Bounties.FollowParams({
            followerProfileId: bidderProfileId,
            idsOfProfilesToFollow: idsOfProfilesToFollow1,
            followTokenIds: new uint256[](1),
            datas: new bytes[](1)
        });

        input[0] = Bounties.RankedSettleInput({
            bid: bidAmount1,
            recipient: bidderAddress,
            revShare: revShare,
            signature: "",
            postParams: post1,
            mirrorParams: mirror1,
            followParams: follow1
        });

        // bidder 2
        Types.PostParams memory post2 = Types.PostParams({
            profileId: bidderProfileId2,
            contentURI: "ipfs://123",
            actionModules: new address[](0),
            actionModulesInitDatas: new bytes[](0),
            referenceModule: address(0),
            referenceModuleInitData: ""
        });

        Types.MirrorParams memory mirror2 = Types.MirrorParams({
            profileId: bidderProfileId2,
            metadataURI: "ipfs://123",
            pointedProfileId: 349,
            pointedPubId: 0x04,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory idsOfProfilesToFollow2 = new uint256[](1);
        idsOfProfilesToFollow2[0] = 349;
        Bounties.FollowParams memory follow2 = Bounties.FollowParams({
            followerProfileId: bidderProfileId2,
            idsOfProfilesToFollow: idsOfProfilesToFollow2,
            followTokenIds: new uint256[](1),
            datas: new bytes[](1)
        });
        input[1] = Bounties.RankedSettleInput({
            bid: bidAmount2,
            recipient: bidderAddress2,
            revShare: revShare,
            signature: "",
            postParams: post2,
            mirrorParams: mirror2,
            followParams: follow2
        });

        bytes[] memory signatures = createSignatures(newBountyId, input);

        input[0].signature = signatures[0];
        input[1].signature = signatures[1];

        return input;
    }

    function createNftSettleDataTwoBidders(uint256 newBountyId)
        internal
        view
        returns (Bounties.NftSettleInput[] memory)
    {
        Bounties.NftSettleInput[] memory input = new Bounties.NftSettleInput[](2);

        // bidder 1
        Types.PostParams memory post1 = Types.PostParams({
            profileId: bidderProfileId,
            contentURI: "ipfs://123",
            actionModules: new address[](0),
            actionModulesInitDatas: new bytes[](0),
            referenceModule: address(0),
            referenceModuleInitData: ""
        });

        Types.MirrorParams memory mirror1 = Types.MirrorParams({
            profileId: bidderProfileId,
            metadataURI: "ipfs://123",
            pointedProfileId: 349,
            pointedPubId: 0x04,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory idsOfProfilesToFollow1 = new uint256[](1);
        idsOfProfilesToFollow1[0] = 349;
        Bounties.FollowParams memory follow1 = Bounties.FollowParams({
            followerProfileId: bidderProfileId,
            idsOfProfilesToFollow: idsOfProfilesToFollow1,
            followTokenIds: new uint256[](1),
            datas: new bytes[](1)
        });

        input[0] = Bounties.NftSettleInput({
            nonce: bounties.nftSettleNonces(newBountyId, bidderAddress),
            recipient: bidderAddress,
            signature: "",
            postParams: post1,
            mirrorParams: mirror1,
            followParams: follow1
        });

        // bidder 2
        Types.PostParams memory post2 = Types.PostParams({
            profileId: bidderProfileId2,
            contentURI: "ipfs://123",
            actionModules: new address[](0),
            actionModulesInitDatas: new bytes[](0),
            referenceModule: address(0),
            referenceModuleInitData: ""
        });

        Types.MirrorParams memory mirror2 = Types.MirrorParams({
            profileId: bidderProfileId2,
            metadataURI: "ipfs://123",
            pointedProfileId: 349,
            pointedPubId: 0x04,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory idsOfProfilesToFollow2 = new uint256[](1);
        idsOfProfilesToFollow2[0] = 349;
        Bounties.FollowParams memory follow2 = Bounties.FollowParams({
            followerProfileId: bidderProfileId2,
            idsOfProfilesToFollow: idsOfProfilesToFollow2,
            followTokenIds: new uint256[](1),
            datas: new bytes[](1)
        });
        input[1] = Bounties.NftSettleInput({
            nonce: bounties.nftSettleNonces(newBountyId, bidderAddress2),
            recipient: bidderAddress2,
            signature: "",
            postParams: post2,
            mirrorParams: mirror2,
            followParams: follow2
        });

        bytes[] memory signatures = createSignatures(newBountyId, input);

        input[0].signature = signatures[0];
        input[1].signature = signatures[1];

        return input;
    }

    function createSignatures(uint256 bountyId, Bounties.RankedSettleInput[] memory data)
        internal
        view
        returns (bytes[] memory)
    {
        bytes[] memory signatures = new bytes[](data.length);
        uint256 i;
        while (i < signatures.length) {
            // Create the typed data hash
            bytes32 messageHash = hashRankedSettleInput(bountyId, data[i]);
            bytes32 typedDataHash = toTypedDataHash(messageHash);

            uint256 privateKey = i == 0 ? bidderPrivateKey : bidderPrivateKey2;
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, typedDataHash);
            signatures[i] = abi.encodePacked(r, s, v);
            unchecked {
                ++i;
            }
        }
        return signatures;
    }

    function createSignatures(uint256 bountyId, Bounties.NftSettleInput[] memory data)
        internal
        view
        returns (bytes[] memory)
    {
        bytes[] memory signatures = new bytes[](data.length);
        uint256 i;
        while (i < signatures.length) {
            // Create the typed data hash
            bytes32 messageHash = hashNftSettleInput(bountyId, data[i]);
            bytes32 typedDataHash = toTypedDataHash(messageHash);

            uint256 privateKey = i == 0 ? bidderPrivateKey : bidderPrivateKey2;
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, typedDataHash);
            signatures[i] = abi.encodePacked(r, s, v);
            unchecked {
                ++i;
            }
        }
        return signatures;
    }

    function toTypedDataHash(bytes32 messageHash) private view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH, keccak256("MadFi Bounties"), keccak256("1"), block.chainid, address(bounties)
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, messageHash));
    }

    function hashRankedSettleInput(uint256 bountyId, Bounties.RankedSettleInput memory input)
        private
        pure
        returns (bytes32)
    {
        bytes32 postParamsHash = keccak256(
            abi.encode(
                POST_PARAMS_TYPEHASH,
                input.postParams.profileId,
                input.postParams.contentURI,
                input.postParams.actionModules,
                input.postParams.actionModulesInitDatas,
                input.postParams.referenceModule,
                input.postParams.referenceModuleInitData
            )
        );

        bytes32 mirrorParamsHash = keccak256(
            abi.encode(
                MIRROR_PARAMS_TYPEHASH,
                input.mirrorParams.profileId,
                input.mirrorParams.metadataURI,
                input.mirrorParams.pointedProfileId,
                input.mirrorParams.pointedPubId,
                input.mirrorParams.referrerProfileIds,
                input.mirrorParams.referrerPubIds,
                input.mirrorParams.referenceModuleData
            )
        );

        bytes32 followParamsHash = keccak256(
            abi.encode(
                FOLLOW_PARAMS_TYPEHASH,
                input.followParams.datas,
                input.followParams.followTokenIds,
                input.followParams.followerProfileId,
                input.followParams.idsOfProfilesToFollow
            )
        );

        return keccak256(
            abi.encode(
                RANKED_SETTLE_INPUT_TYPEHASH,
                bountyId,
                input.bid,
                input.recipient,
                input.revShare,
                postParamsHash,
                mirrorParamsHash,
                followParamsHash
            )
        );
    }

    function hashNftSettleInput(uint256 bountyId, Bounties.NftSettleInput memory input)
        private
        pure
        returns (bytes32)
    {
        bytes32 postParamsHash = keccak256(
            abi.encode(
                POST_PARAMS_TYPEHASH,
                input.postParams.profileId,
                input.postParams.contentURI,
                input.postParams.actionModules,
                input.postParams.actionModulesInitDatas,
                input.postParams.referenceModule,
                input.postParams.referenceModuleInitData
            )
        );

        bytes32 mirrorParamsHash = keccak256(
            abi.encode(
                MIRROR_PARAMS_TYPEHASH,
                input.mirrorParams.profileId,
                input.mirrorParams.metadataURI,
                input.mirrorParams.pointedProfileId,
                input.mirrorParams.pointedPubId,
                input.mirrorParams.referrerProfileIds,
                input.mirrorParams.referrerPubIds,
                input.mirrorParams.referenceModuleData
            )
        );

        bytes32 followParamsHash = keccak256(
            abi.encode(
                FOLLOW_PARAMS_TYPEHASH,
                input.followParams.datas,
                input.followParams.followTokenIds,
                input.followParams.followerProfileId,
                input.followParams.idsOfProfilesToFollow
            )
        );

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

    function createBidFromActionParam(address[] memory recipients, uint256[] memory bids, uint256[] memory revShares)
        internal
        pure
        returns (Bounties.BidFromAction[] memory)
    {
        Bounties.BidFromAction[] memory data = new Bounties.BidFromAction[](recipients.length);
        uint256 i;
        while (i < recipients.length) {
            data[i] = Bounties.BidFromAction({recipient: recipients[i], bid: bids[i], revShare: revShares[i]});
            unchecked {
                ++i;
            }
        }
        return data;
    }

    function setDelegatedExecutors(address _bounties) internal {
        // set delegated executors
        address[] memory executors = new address[](1);
        executors[0] = _bounties;

        bool[] memory approvals = new bool[](1);
        approvals[0] = true;

        vm.prank(bidderAddress);
        ILensHubTest(lensHub).changeDelegatedExecutorsConfig(bidderProfileId, executors, approvals);
        vm.prank(bidderAddress2);
        ILensHubTest(lensHub).changeDelegatedExecutorsConfig(bidderProfileId2, executors, approvals);
    }
}
