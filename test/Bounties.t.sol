// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "../src/Bounties.sol";
import "../src/mocks/MockToken.sol";
import "../src/mocks/MockMadSBT.sol";
import "../src/mocks/MockRouter.sol";
import "../src/mocks/MockSuperToken.sol";
import "../src/mocks/MockActionModule.sol";
import "../src/extensions/LensExtension.sol";
import "../src/RewardNft.sol";

import "../src/interfaces/ISuperToken.sol";

import "./helpers/LensHelper.sol";

import "openzeppelin/utils/cryptography/ECDSA.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
// import "lens/../test/base/BaseTest.t.sol";

interface IHubTest {
    function nonces(address signer) external returns (uint256);
    function changeDelegatedExecutorsConfig(
        uint256 delegatorProfileId,
        address[] calldata delegatedExecutors,
        bool[] calldata approvals
    ) external;
}

contract BountiesTest is Test, LensHelper {
    using ECDSA for bytes32;

    uint256 polygonFork;

    Bounties bounties;
    RewardNft rewardNft;
    MockMadSBT mockMadSBT;

    address lensHub = 0xC1E77eE73403B8a7478884915aA599932A677870; // lens hub proxy v2 preview
    address swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // uniswap swap router

    ERC20 usdc = ERC20(0xbe49ac1EadAc65dccf204D4Df81d650B50122aB2);
    ERC20 wmatic = ERC20(0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889);
    ISuperToken superUsdc = ISuperToken(0x42bb40bF79730451B11f6De1CbA222F17b87Afd7);

    address defaultSender = address(69);

    uint256 public bidderPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; // hardhat account 1
    uint256 public bidderPrivateKey2 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d; // hardhat account 2
    address public bidderAddress = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public bidderAddress2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    uint256 bidderProfileId = 236;

    uint256 bidAmount1 = 75_000;
    uint256 bidAmount2 = 25_000;

    MockActionModule mockActionModule;

    function setUp() public {
        polygonFork = vm.createFork(vm.envString("MUMBAI_RPC_URL"));
        vm.selectFork(polygonFork);

        mockMadSBT = new MockMadSBT(address(superUsdc));

        bounties = new Bounties(lensHub, 0, 0, address(swapRouter));
        rewardNft = new RewardNft(address(bounties));

        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        bounties.setRewardNft(address(rewardNft));

        mockActionModule = new MockActionModule();
    }

    function helperMintApproveTokens(uint256 bountyAmount, address recipient, ERC20 token) public {
        deal(address(token), recipient, bountyAmount);
        token.approve(address(bounties), type(uint256).max);
    }

    function testCreateBounty() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 123;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);
        assertEq(newBountyId, 1);
        (uint256 amount, address sponsor, address token,) = bounties.bounties(newBountyId);
        assertEq(token, address(usdc));
        assertEq(amount, bountyAmount);
        assertEq(sponsor, defaultSender);
        vm.stopPrank();
    }

    function testTopUp() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 123;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);
        assertEq(newBountyId, 1);
        (uint256 amount, address sponsor, address token,) = bounties.bounties(newBountyId);
        assertEq(token, address(usdc));
        assertEq(amount, bountyAmount);
        assertEq(sponsor, defaultSender);

        // Top up
        uint256 topUpAmount = 100;
        helperMintApproveTokens(topUpAmount, defaultSender, usdc);
        bounties.topUp(newBountyId, topUpAmount);
        (amount, sponsor, token,) = bounties.bounties(newBountyId);
        assertEq(amount, bountyAmount + topUpAmount);
        vm.stopPrank();
    }

    function testFailSettleBountyBadArbiter() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 123;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        address[] memory recipients = new address[](1);
        recipients[0] = bidderAddress;

        uint256[] memory bids = new uint256[](1);
        bids[0] = bidAmount1;

        uint256[] memory revShares = new uint256[](1);
        revShares[0] = 0;

        bytes[] memory paymentSignatures = createPaymentSignatures(newBountyId, recipients, bids, revShares);

        Bounties.BidFromAction[] memory data = createBidFromActionParam(recipients, bids, revShares);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            data: data,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0),
            fee: 500
        });

        vm.prank(address(5));
        bounties.rankedSettle(input);
        vm.stopPrank();
    }

    function testSettleRankedBounty() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 tokenAmountBefore = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;

        uint256[] memory bids = new uint256[](2);
        bids[0] = bidAmount1;
        bids[1] = bidAmount2;

        uint256[] memory revShares = new uint256[](2);
        revShares[0] = 0;
        revShares[1] = 0;

        bytes[] memory paymentSignatures = createPaymentSignatures(newBountyId, recipients, bids, revShares);

        Bounties.BidFromAction[] memory data = createBidFromActionParam(recipients, bids, revShares);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            data: data,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0),
            fee: 500
        });

        bounties.rankedSettle(input);
        bounties.close(newBountyId);

        uint256 expected1 = bidAmount1;
        uint256 expected2 = bidAmount2;
        uint256 expected3 = tokenAmountBefore - expected1 - expected2;
        assertEq(usdc.balanceOf(bidderAddress), expected1);
        assertEq(usdc.balanceOf(bidderAddress2), expected2);
        assertEq(usdc.balanceOf(defaultSender), expected3);
        vm.stopPrank();
    }

    function testSettleRankedBountyFromAction() public {
        address openAction = address(70);

        bounties.setPublicationActionModule(openAction);

        vm.startPrank(openAction);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, openAction, usdc);
        uint256 tokenAmountBefore = usdc.balanceOf(openAction);

        uint256 newBountyId = bounties.depositFromAction(defaultSender, address(usdc), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;

        uint256[] memory bids = new uint256[](2);
        bids[0] = bidAmount1;
        bids[1] = bidAmount2;

        uint256[] memory revShares = new uint256[](2);
        revShares[0] = 0;
        revShares[1] = 0;

        Bounties.BidFromAction[] memory data = createBidFromActionParam(recipients, bids, revShares);

        Bounties.RankedSettleFromActionInput memory input = Bounties.RankedSettleFromActionInput({
            bountyId: newBountyId,
            bidTotal: bidAmount1 + bidAmount2,
            data: data,
            postParams: new Types.PostParams[](0),
            fee: 500
        });

        bounties.rankedSettleFromAction(input);
        vm.stopPrank();
        vm.prank(defaultSender);
        bounties.close(newBountyId);

        uint256 expected1 = bidAmount1;
        uint256 expected2 = bidAmount2;
        uint256 expected3 = tokenAmountBefore - expected1 - expected2;
        assertEq(usdc.balanceOf(bidderAddress), expected1, "Bidder 1 balance is not correct");
        assertEq(usdc.balanceOf(bidderAddress2), expected2, "Bidder 2 balance is not correct");
        assertEq(usdc.balanceOf(defaultSender), expected3, "Sponsor balance is not correct");
        assertEq(usdc.balanceOf(openAction), 0, "Open Action balance is not correct");
    }

    function testSettleAndWithdrawFees() public {
        vm.startPrank(defaultSender);
        uint256 fee = 500;
        uint256 bountyAmount = 100_000_000;
        bounties = new Bounties(address(4545454545), fee, 0, address(swapRouter));
        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        helperMintApproveTokens(bountyAmount + ((500 * bountyAmount) / 10_000), defaultSender, usdc);
        uint256 beforeBal = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;

        uint256[] memory bids = new uint256[](2);
        bids[0] = bidAmount1;
        bids[1] = bidAmount2;

        uint256[] memory revShares = new uint256[](2);
        revShares[0] = 0;
        revShares[1] = 0;

        bytes[] memory paymentSignatures = createPaymentSignatures(newBountyId, recipients, bids, revShares);

        Bounties.BidFromAction[] memory data = createBidFromActionParam(recipients, bids, revShares);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            data: data,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0),
            fee: 500
        });

        bounties.rankedSettle(input);
        bounties.close(newBountyId);

        uint256 payout = bidAmount1 + bidAmount2;
        uint256 feePaid = (payout * fee) / 10_000;
        uint256 totalSpend = payout + feePaid;
        assertEq(usdc.balanceOf(defaultSender), beforeBal - totalSpend);

        uint256 ownerBeforeBal = usdc.balanceOf(defaultSender);
        address[] memory tokens = new address[](1);
        tokens[0] = address(usdc);
        bounties.withdrawFees(tokens);
        assertEq(usdc.balanceOf(defaultSender), ownerBeforeBal + feePaid);

        vm.stopPrank();
    }

    function testFailOnlyDisperseBountiedFunds() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        helperMintApproveTokens(bountyAmount, address(bounties), usdc);

        assertEq(usdc.balanceOf(address(bounties)), 2 * bountyAmount);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;

        uint256[] memory bids = new uint256[](2);
        bids[0] = bidAmount1;
        bids[1] = bidAmount1;

        uint256[] memory revShares = new uint256[](2);
        revShares[0] = 0;
        revShares[1] = 0;

        bytes[] memory paymentSignatures = createPaymentSignatures(newBountyId, recipients, bids, revShares);

        Bounties.BidFromAction[] memory data = createBidFromActionParam(recipients, bids, revShares);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            data: data,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0),
            fee: 500
        });

        bounties.rankedSettle(input);
        vm.stopPrank();
    }

    function testFailTooFewSplits() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        helperMintApproveTokens(bountyAmount, address(bounties), usdc);

        assertEq(usdc.balanceOf(address(bounties)), 2 * bountyAmount);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;

        uint256[] memory bids = new uint256[](2);
        bids[0] = bidAmount1;

        uint256[] memory revShares = new uint256[](2);
        revShares[0] = 0;
        revShares[1] = 0;

        bytes[] memory paymentSignatures = createPaymentSignatures(newBountyId, recipients, bids, revShares);

        Bounties.BidFromAction[] memory data = createBidFromActionParam(recipients, bids, revShares);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            data: data,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0),
            fee: 500
        });

        bounties.rankedSettle(input);
        vm.stopPrank();
    }

    function testOnlyWithdrawFees() public {
        vm.startPrank(defaultSender);
        uint256 fee = 500;
        uint256 bountyAmount = 100_000_000;
        bounties = new Bounties(address(4545454545), fee, 0, address(swapRouter));
        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        helperMintApproveTokens(bountyAmount + ((500 * bountyAmount) / 10_000), defaultSender, usdc);
        helperMintApproveTokens(bountyAmount, address(bounties), usdc);
        uint256 beforeBal = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;

        uint256[] memory bids = new uint256[](2);
        bids[0] = bidAmount1;
        bids[1] = bidAmount2;

        uint256[] memory revShares = new uint256[](2);
        revShares[0] = 0;
        revShares[1] = 0;

        bytes[] memory paymentSignatures = createPaymentSignatures(newBountyId, recipients, bids, revShares);

        Bounties.BidFromAction[] memory data = createBidFromActionParam(recipients, bids, revShares);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            data: data,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0),
            fee: 500
        });

        bounties.rankedSettle(input);
        bounties.close(newBountyId);

        uint256 feePaid = ((bidAmount1 + bidAmount2) * fee) / 10_000;
        assertEq(usdc.balanceOf(defaultSender), beforeBal - (bidAmount1 + bidAmount2 + feePaid));

        uint256 ownerBeforeBal = usdc.balanceOf(defaultSender);
        address[] memory tokens = new address[](1);
        tokens[0] = address(usdc);

        assertEq(usdc.balanceOf(address(bounties)), bountyAmount + feePaid);
        bounties.withdrawFees(tokens);
        assertEq(usdc.balanceOf(defaultSender), ownerBeforeBal + feePaid);
        assertEq(usdc.balanceOf(address(bounties)), bountyAmount);

        vm.stopPrank();
    }

    function testNftRewardBounty() public {
        // create bounty
        vm.startPrank(defaultSender);
        uint256 newBountyId = bounties.depositNft("ipfs://123");
        assertEq(newBountyId, 1);
        (uint256 amount, address sponsor, address token, uint256 collectionID) = bounties.bounties(newBountyId);
        assertEq(token, address(0));
        assertEq(amount, 0);
        assertEq(sponsor, defaultSender);
        assertEq(collectionID, 1);

        // pay out bounty
        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;
        bounties.nftSettle(newBountyId, recipients, new Types.PostParams[](0), new Types.EIP712Signature[](0));
        assertEq(rewardNft.balanceOf(bidderAddress, 1), 1);
        assertEq(rewardNft.balanceOf(bidderAddress2, 1), 1);

        // close bounty
        bounties.close(newBountyId);

        vm.stopPrank();
    }

    function testRevShare() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 tokenAmountBefore = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;

        uint256[] memory bids = new uint256[](2);
        bids[0] = bidAmount1;
        bids[1] = bidAmount2;

        uint256[] memory revShares = new uint256[](2);
        revShares[0] = 10_00;
        revShares[1] = 10_00;

        bytes[] memory paymentSignatures = createPaymentSignatures(newBountyId, recipients, bids, revShares);

        Bounties.BidFromAction[] memory data = createBidFromActionParam(recipients, bids, revShares);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            data: data,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0),
            fee: 500
        });

        bounties.rankedSettle(input);
        bounties.close(newBountyId);

        uint256 expected1 = 90 * bidAmount1 / 100;
        uint256 expected2 = 90 * bidAmount2 / 100;
        uint256 expected3 = tokenAmountBefore - bidAmount1 - bidAmount2;
        assertEq(usdc.balanceOf(bidderAddress), expected1);
        assertEq(usdc.balanceOf(bidderAddress2), expected2);
        assertEq(usdc.balanceOf(defaultSender), expected3);
        vm.stopPrank();
    }

    function testRevShareWithSwap() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender, wmatic);
        uint256 tokenAmountBefore = wmatic.balanceOf(defaultSender);
        uint256 recipient1BalanceBefore = wmatic.balanceOf(bidderAddress);
        uint256 recipient2BalanceBefore = wmatic.balanceOf(bidderAddress2);

        uint256 newBountyId = bounties.deposit(address(wmatic), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;

        uint256[] memory bids = new uint256[](2);
        bids[0] = bidAmount1;
        bids[1] = bidAmount2;

        uint256[] memory revShares = new uint256[](2);
        revShares[0] = 10_00;
        revShares[1] = 10_00;

        bytes[] memory paymentSignatures = createPaymentSignatures(newBountyId, recipients, bids, revShares);

        Bounties.BidFromAction[] memory data = createBidFromActionParam(recipients, bids, revShares);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            data: data,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0),
            fee: 500
        });

        bounties.rankedSettle(input);
        bounties.close(newBountyId);

        uint256 expected1 = 90 * bidAmount1 / 100;
        uint256 expected2 = 90 * bidAmount2 / 100;
        uint256 expected3 = tokenAmountBefore - bidAmount1 - bidAmount2;
        assertEq(
            wmatic.balanceOf(bidderAddress), recipient1BalanceBefore + expected1, "Recipient 1 balance is not correct"
        );
        assertEq(
            wmatic.balanceOf(bidderAddress2), recipient2BalanceBefore + expected2, "Recipient 2 balance is not correct"
        );
        assertEq(wmatic.balanceOf(defaultSender), expected3, "Default sender balance is not correct");
        vm.stopPrank();
    }

    function skiptestSettleRankedBountyPostToLens() public {
        {
            vm.prank(bidderAddress);
            address[] memory executors = new address[](1);
            executors[0] = defaultSender;

            bool[] memory approvals = new bool[](1);
            approvals[0] = true;

            IHubTest(lensHub).changeDelegatedExecutorsConfig(bidderProfileId, executors, approvals);
        }

        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 tokenAmountBefore = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        address[] memory recipients = new address[](1);
        recipients[0] = bidderAddress;

        uint256[] memory bids = new uint256[](1);
        bids[0] = bidAmount1;

        uint256[] memory revShares = new uint256[](1);
        revShares[0] = 0;

        bytes[] memory paymentSignatures = createPaymentSignatures(newBountyId, recipients, bids, revShares);

        Bounties.BidFromAction[] memory data = createBidFromActionParam(recipients, bids, revShares);

        uint256 nonce = IHubTest(lensHub).nonces(bidderAddress);
        uint256 deadline = type(uint256).max;

        Types.PostParams[] memory posts = new Types.PostParams[](1);
        posts[0] = Types.PostParams({
            profileId: bidderProfileId,
            contentURI: "ipfs://123",
            actionModules: _toAddressArray(address(mockActionModule)),
            actionModulesInitDatas: _toBytesArray(abi.encode(true)),
            referenceModule: address(0),
            referenceModuleInitData: ""
        });

        Types.EIP712Signature[] memory postSignatures = new Types.EIP712Signature[](1);
        postSignatures[0] = _getSigStruct({
            signer: bidderAddress,
            pKey: bidderPrivateKey,
            digest: _getPostTypedDataHash(posts[0], bidderAddress, nonce, deadline),
            deadline: deadline
        });

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            data: data,
            paymentSignatures: paymentSignatures,
            postParams: posts,
            signatures: postSignatures,
            fee: 500
        });

        bounties.rankedSettle(input);
        bounties.close(newBountyId);

        assertEq(usdc.balanceOf(bidderAddress), bidAmount1);
        assertEq(usdc.balanceOf(defaultSender), tokenAmountBefore - bidAmount1);
        vm.stopPrank();
    }

    // HELPERS
    function createPaymentSignatures(
        uint256 newBountyId,
        address[] memory recipients,
        uint256[] memory bids,
        uint256[] memory revShares
    ) internal view returns (bytes[] memory) {
        bytes[] memory paymentSignatures = new bytes[](recipients.length);
        uint256 i;
        while (i < recipients.length) {
            bytes32 digest =
                keccak256(abi.encode(newBountyId, recipients[i], bids[i], revShares[i])).toEthSignedMessageHash();
            uint256 privateKey = i == 0 ? bidderPrivateKey : bidderPrivateKey2;
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
            paymentSignatures[i] = abi.encodePacked(r, s, v);
            unchecked {
                ++i;
            }
        }
        return paymentSignatures;
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
}
