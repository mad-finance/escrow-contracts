// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "lens/interfaces/ILensProtocol.sol";
import {Typehash} from "lens/libraries/constants/TypeHash.sol";

import "openzeppelin/utils/cryptography/ECDSA.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

import "madfi-protocol/interfaces/ISuperToken.sol";

import "../../src/Bounties.sol";
import {RewardNft} from "../../src/RewardNft.sol";
import "../../src/libraries/Constants.sol";

import "../../src/mocks/MockMadSBT.sol";
import "../../src/mocks/MockRouter.sol";
import "../../src/mocks/MockSuperToken.sol";
import "../../src/mocks/MockReferralHandler.sol";

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
    MockReferralHandler mockReferralHandler;

    address swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // uniswap swap router

    ERC20 usdc = ERC20(0xbe49ac1EadAc65dccf204D4Df81d650B50122aB2);
    ERC20 wmatic = ERC20(0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889);
    ISuperToken superUsdc = ISuperToken(0x42bb40bF79730451B11f6De1CbA222F17b87Afd7);

    address lensHub = 0x4fbffF20302F3326B20052ab9C217C44F6480900;

    address defaultSender = address(69);

    address client = address(54321);

    uint256 public bidderPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; // hardhat account 1
    uint256 public bidderPrivateKey2 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d; // hardhat account 2
    address public bidderAddress = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public bidderAddress2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    uint256 bidderProfileId = 78;
    uint256 bidderProfileId2 = 79;

    uint256 bidAmount1 = 75_000;
    uint256 bidAmount2 = 25_000;

    uint24 uniswapFee = 500; // 0.05% uniswap pool fee

    function setUp() public virtual {
        polygonFork = vm.createFork(vm.envString("MUMBAI_RPC_URL"));
        vm.selectFork(polygonFork);

        mockMadSBT = new MockMadSBT(address(superUsdc));
        mockReferralHandler = new MockReferralHandler();

        bounties = new Bounties(lensHub, 0, 0, address(swapRouter), address(mockReferralHandler));
        rewardNft = new RewardNft(address(bounties));

        bounties.setRewardNft(address(rewardNft));

        setDelegatedExecutors(address(bounties));
    }

    function helperMintApproveTokens(uint256 bountyAmount, address recipient, ERC20 token) public {
        deal(address(token), recipient, bountyAmount);
        token.approve(address(bounties), type(uint256).max);
    }

    function createSettleData(uint256 newBountyId) internal view returns (Structs.RankedSettleInput[] memory) {
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
            pointedProfileId: 0x1e,
            pointedPubId: 0x5b,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory idsOfProfilesToFollow = new uint256[](1);
        idsOfProfilesToFollow[0] = 71;
        Structs.FollowParams memory follow = Structs.FollowParams({
            followerProfileId: bidderProfileId,
            idsOfProfilesToFollow: idsOfProfilesToFollow,
            followTokenIds: new uint256[](1),
            datas: new bytes[](1)
        });

        Structs.RankedSettleInput[] memory input = new Structs.RankedSettleInput[](1);
        input[0] = Structs.RankedSettleInput({
            bid: bidAmount1,
            bidderCollectionId: 0,
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

    function createSettleDataWithRevshare(uint256 newBountyId, uint256 revShare, uint256 bidderCollectionId)
        internal
        view
        returns (Structs.RankedSettleInput[] memory)
    {
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
            pointedProfileId: 0x1e,
            pointedPubId: 0x5b,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory idsOfProfilesToFollow = new uint256[](1);
        idsOfProfilesToFollow[0] = 71;
        Structs.FollowParams memory follow = Structs.FollowParams({
            followerProfileId: bidderProfileId,
            idsOfProfilesToFollow: idsOfProfilesToFollow,
            followTokenIds: new uint256[](1),
            datas: new bytes[](1)
        });

        Structs.RankedSettleInput[] memory input = new Structs.RankedSettleInput[](1);
        input[0] = Structs.RankedSettleInput({
            bid: bidAmount1,
            bidderCollectionId: bidderCollectionId,
            recipient: bidderAddress,
            revShare: revShare,
            signature: "",
            postParams: post,
            mirrorParams: mirror,
            followParams: follow
        });

        input[0].signature = createSignatures(newBountyId, input)[0];
        return input;
    }

    function createQuoteSettleData(uint256 newBountyId)
        internal
        view
        returns (Structs.RankedSettleInputQuote[] memory)
    {
        Types.QuoteParams memory quote = Types.QuoteParams({
            profileId: bidderProfileId,
            contentURI: "ipfs://123",
            pointedProfileId: 0x1e,
            pointedPubId: 0x5b,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: "",
            actionModules: new address[](0),
            actionModulesInitDatas: new bytes[](0),
            referenceModule: address(0),
            referenceModuleInitData: ""
        });

        Types.MirrorParams memory mirror = Types.MirrorParams({
            profileId: bidderProfileId,
            metadataURI: "ipfs://123",
            pointedProfileId: 0x1e,
            pointedPubId: 0x5b,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory idsOfProfilesToFollow = new uint256[](1);
        idsOfProfilesToFollow[0] = 71;
        Structs.FollowParams memory follow = Structs.FollowParams({
            followerProfileId: bidderProfileId,
            idsOfProfilesToFollow: idsOfProfilesToFollow,
            followTokenIds: new uint256[](1),
            datas: new bytes[](1)
        });

        Structs.RankedSettleInputQuote[] memory input = new Structs.RankedSettleInputQuote[](1);
        input[0] = Structs.RankedSettleInputQuote({
            bid: bidAmount1,
            bidderCollectionId: 0,
            recipient: bidderAddress,
            revShare: 0,
            signature: "",
            quoteParams: quote,
            mirrorParams: mirror,
            followParams: follow
        });

        input[0].signature = createSignatures(newBountyId, input)[0];
        return input;
    }

    function createSettleDataTwoBidders(uint256 newBountyId, uint256 revShare, uint256 bidderCollectionId)
        internal
        view
        returns (Structs.RankedSettleInput[] memory)
    {
        Structs.RankedSettleInput[] memory input = new Structs.RankedSettleInput[](2);

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
            pointedProfileId: 0x1e,
            pointedPubId: 0x5b,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory idsOfProfilesToFollow1 = new uint256[](1);
        idsOfProfilesToFollow1[0] = 71;
        Structs.FollowParams memory follow1 = Structs.FollowParams({
            followerProfileId: bidderProfileId,
            idsOfProfilesToFollow: idsOfProfilesToFollow1,
            followTokenIds: new uint256[](1),
            datas: new bytes[](1)
        });

        input[0] = Structs.RankedSettleInput({
            bid: bidAmount1,
            bidderCollectionId: bidderCollectionId,
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
            pointedProfileId: 0x1e,
            pointedPubId: 0x5b,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory idsOfProfilesToFollow2 = new uint256[](1);
        idsOfProfilesToFollow2[0] = 71;
        Structs.FollowParams memory follow2 = Structs.FollowParams({
            followerProfileId: bidderProfileId2,
            idsOfProfilesToFollow: idsOfProfilesToFollow2,
            followTokenIds: new uint256[](1),
            datas: new bytes[](1)
        });
        input[1] = Structs.RankedSettleInput({
            bid: bidAmount2,
            bidderCollectionId: bidderCollectionId,
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
        returns (Structs.NftSettleInput[] memory)
    {
        Structs.NftSettleInput[] memory input = new Structs.NftSettleInput[](2);

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
            pointedProfileId: 0x1e,
            pointedPubId: 0x5b,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory idsOfProfilesToFollow1 = new uint256[](1);
        idsOfProfilesToFollow1[0] = 71;
        Structs.FollowParams memory follow1 = Structs.FollowParams({
            followerProfileId: bidderProfileId,
            idsOfProfilesToFollow: idsOfProfilesToFollow1,
            followTokenIds: new uint256[](1),
            datas: new bytes[](1)
        });

        input[0] = Structs.NftSettleInput({
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
            pointedProfileId: 0x1e,
            pointedPubId: 0x5b,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory idsOfProfilesToFollow2 = new uint256[](1);
        idsOfProfilesToFollow2[0] = 71;
        Structs.FollowParams memory follow2 = Structs.FollowParams({
            followerProfileId: bidderProfileId2,
            idsOfProfilesToFollow: idsOfProfilesToFollow2,
            followTokenIds: new uint256[](1),
            datas: new bytes[](1)
        });
        input[1] = Structs.NftSettleInput({
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

    function createNftSettleDataQuote(uint256 newBountyId)
        internal
        view
        returns (Structs.NftSettleInputQuote[] memory)
    {
        Structs.NftSettleInputQuote[] memory input = new Structs.NftSettleInputQuote[](1);

        Types.QuoteParams memory quote = Types.QuoteParams({
            profileId: bidderProfileId,
            contentURI: "ipfs://123",
            pointedProfileId: 0x1e,
            pointedPubId: 0x5b,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: "",
            actionModules: new address[](0),
            actionModulesInitDatas: new bytes[](0),
            referenceModule: address(0),
            referenceModuleInitData: ""
        });

        Types.MirrorParams memory mirror1 = Types.MirrorParams({
            profileId: bidderProfileId,
            metadataURI: "ipfs://123",
            pointedProfileId: 0x1e,
            pointedPubId: 0x5b,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory idsOfProfilesToFollow1 = new uint256[](1);
        idsOfProfilesToFollow1[0] = 71;
        Structs.FollowParams memory follow1 = Structs.FollowParams({
            followerProfileId: bidderProfileId,
            idsOfProfilesToFollow: idsOfProfilesToFollow1,
            followTokenIds: new uint256[](1),
            datas: new bytes[](1)
        });

        input[0] = Structs.NftSettleInputQuote({
            nonce: bounties.nftSettleNonces(newBountyId, bidderAddress),
            recipient: bidderAddress,
            signature: "",
            quoteParams: quote,
            mirrorParams: mirror1,
            followParams: follow1
        });

        input[0].signature = createSignatures(newBountyId, input)[0];

        return input;
    }

    function createPayOnlySettleDataTwoBidders(uint256 newBountyId, uint256 revShare)
        internal
        view
        returns (Structs.BidFromAction[] memory, bytes[] memory)
    {
        Structs.BidFromAction[] memory input = new Structs.BidFromAction[](2);

        // bidder 1
        input[0] = Structs.BidFromAction({
            bid: bidAmount1,
            recipient: bidderAddress,
            transactionExecutor: address(0),
            revShare: revShare,
            bidderCollectionId: 0
        });

        // bidder 2
        input[1] = Structs.BidFromAction({
            bid: bidAmount2,
            recipient: bidderAddress2,
            transactionExecutor: address(0),
            revShare: revShare,
            bidderCollectionId: 0
        });

        bytes[] memory signatures = createSignatures(newBountyId, input);

        return (input, signatures);
    }

    function createSignatures(uint256 bountyId, Structs.RankedSettleInput[] memory data)
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

    function createSignatures(uint256 bountyId, Structs.RankedSettleInputQuote[] memory data)
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

    function createSignatures(uint256 bountyId, Structs.NftSettleInput[] memory data)
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

    function createSignatures(uint256 bountyId, Structs.NftSettleInputQuote[] memory data)
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

    function createSignatures(uint256 bountyId, Structs.BidFromAction[] memory data)
        internal
        view
        returns (bytes[] memory)
    {
        bytes[] memory signatures = new bytes[](data.length);
        uint256 i;
        while (i < signatures.length) {
            // Create the typed data hash
            bytes32 messageHash = hashBidFromActionInput(bountyId, data[i]);
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
        return keccak256(abi.encodePacked(bytesArrayEncodedElements));
    }

    function hashLensInputs(Types.PostParams memory postParams) private pure returns (bytes32 postParamsHash) {
        postParamsHash = keccak256(
            abi.encode(
                POST_PARAMS_TYPEHASH,
                postParams.profileId,
                keccak256(bytes(postParams.contentURI)),
                keccak256(abi.encodePacked(postParams.actionModules)),
                _encodeUsingEip712Rules(postParams.actionModulesInitDatas),
                postParams.referenceModule,
                keccak256(postParams.referenceModuleInitData)
            )
        );
    }

    function hashLensInputs(Types.QuoteParams memory quoteParams) private pure returns (bytes32 quoteParamsHash) {
        quoteParamsHash = keccak256(
            abi.encode(
                QUOTE_PARAMS_TYPEHASH,
                quoteParams.profileId,
                keccak256(bytes(quoteParams.contentURI)),
                quoteParams.pointedProfileId,
                quoteParams.pointedPubId,
                keccak256(abi.encodePacked(quoteParams.referrerProfileIds)),
                keccak256(abi.encodePacked(quoteParams.referrerPubIds)),
                keccak256(quoteParams.referenceModuleData),
                keccak256(abi.encodePacked(quoteParams.actionModules)),
                _encodeUsingEip712Rules(quoteParams.actionModulesInitDatas),
                quoteParams.referenceModule,
                keccak256(quoteParams.referenceModuleInitData)
            )
        );
    }

    function hashLensInputs(Types.MirrorParams memory mirrorParams, Structs.FollowParams memory followParams)
        private
        pure
        returns (bytes32 mirrorParamsHash, bytes32 followParamsHash)
    {
        mirrorParamsHash = keccak256(
            abi.encode(
                MIRROR_PARAMS_TYPEHASH,
                mirrorParams.profileId,
                keccak256(bytes(mirrorParams.metadataURI)),
                mirrorParams.pointedProfileId,
                mirrorParams.pointedPubId,
                keccak256(abi.encodePacked(mirrorParams.referrerProfileIds)),
                keccak256(abi.encodePacked(mirrorParams.referrerPubIds)),
                keccak256(mirrorParams.referenceModuleData)
            )
        );

        followParamsHash = keccak256(
            abi.encode(
                FOLLOW_PARAMS_TYPEHASH,
                _encodeUsingEip712Rules(followParams.datas),
                keccak256(abi.encodePacked(followParams.followTokenIds)),
                followParams.followerProfileId,
                keccak256(abi.encodePacked(followParams.idsOfProfilesToFollow))
            )
        );
    }

    function hashRankedSettleInput(uint256 bountyId, Structs.RankedSettleInput memory input)
        private
        pure
        returns (bytes32)
    {
        (bytes32 postParamsHash) = hashLensInputs(input.postParams);
        (bytes32 mirrorParamsHash, bytes32 followParamsHash) = hashLensInputs(input.mirrorParams, input.followParams);
        return keccak256(
            abi.encode(
                RANKED_SETTLE_INPUT_TYPEHASH,
                bountyId,
                input.bid,
                input.bidderCollectionId,
                input.recipient,
                input.revShare,
                postParamsHash,
                mirrorParamsHash,
                followParamsHash
            )
        );
    }

    function hashRankedSettleInput(uint256 bountyId, Structs.RankedSettleInputQuote memory input)
        private
        pure
        returns (bytes32)
    {
        (bytes32 quoteParamsHash) = hashLensInputs(input.quoteParams);
        (bytes32 mirrorParamsHash, bytes32 followParamsHash) = hashLensInputs(input.mirrorParams, input.followParams);
        return keccak256(
            abi.encode(
                RANKED_SETTLE_INPUT_QUOTE_TYPEHASH,
                bountyId,
                input.bid,
                input.bidderCollectionId,
                input.recipient,
                input.revShare,
                quoteParamsHash,
                mirrorParamsHash,
                followParamsHash
            )
        );
    }

    function hashNftSettleInput(uint256 bountyId, Structs.NftSettleInput memory input) private pure returns (bytes32) {
        (bytes32 postParamsHash) = hashLensInputs(input.postParams);
        (bytes32 mirrorParamsHash, bytes32 followParamsHash) = hashLensInputs(input.mirrorParams, input.followParams);
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

    function hashNftSettleInput(uint256 bountyId, Structs.NftSettleInputQuote memory input)
        private
        pure
        returns (bytes32)
    {
        (bytes32 quoteParamsHash) = hashLensInputs(input.quoteParams);
        (bytes32 mirrorParamsHash, bytes32 followParamsHash) = hashLensInputs(input.mirrorParams, input.followParams);
        return keccak256(
            abi.encode(
                NFT_SETTLE_INPUT_QUOTE_TYPEHASH,
                bountyId,
                input.nonce,
                input.recipient,
                quoteParamsHash,
                mirrorParamsHash,
                followParamsHash
            )
        );
    }

    function hashBidFromActionInput(uint256 bountyId, Structs.BidFromAction memory input)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                PAY_ONLY_INPUT_TYPEHASH, bountyId, input.bid, input.bidderCollectionId, input.recipient, input.revShare
            )
        );
    }

    function createBidFromActionParam(address[] memory recipients, uint256[] memory bids, uint256[] memory revShares)
        internal
        view
        returns (Structs.BidFromAction[] memory)
    {
        Structs.BidFromAction[] memory data = new Structs.BidFromAction[](recipients.length);
        uint256 i;
        while (i < recipients.length) {
            data[i] = Structs.BidFromAction({
                recipient: recipients[i],
                transactionExecutor: client,
                bid: bids[i],
                revShare: revShares[i],
                bidderCollectionId: 0
            });
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

    function validateLogEmitted(Vm.Log[] memory logs, bytes memory signature) internal pure returns (bool) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256(signature)) {
                return true;
            }
        }

        return false;
    }
}
