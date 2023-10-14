// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/Bounties.sol";
import "../src/mocks/MockToken.sol";
import "../src/mocks/MockMadSBT.sol";
import "../src/mocks/MockRouter.sol";
import "../src/mocks/MockSuperToken.sol";
import "../src/extensions/LensExtension.sol";
import "../src/RewardNft.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";

contract BountiesTest is Test {
    using ECDSA for bytes32;

    Bounties bounties;
    RewardNft rewardNft;
    MockToken mockToken;
    MockMadSBT mockMadSBT;
    MockRouter mockRouter;
    MockSuperToken mockSuperToken;
    address defaultSender = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

    uint256 public bidderPrivateKey = 0x1;
    uint256 public bidderPrivateKey2 = 0x2;
    address public bidderAddress = vm.addr(bidderPrivateKey);
    address public bidderAddress2 = vm.addr(bidderPrivateKey2);

    uint256 splitAmount1 = 75_000;
    uint256 splitAmount2 = 25_000;

    function setUp() public {
        mockToken = new MockToken();
        mockRouter = new MockRouter();
        mockSuperToken = new MockSuperToken(address(mockToken));
        mockMadSBT = new MockMadSBT(address(mockSuperToken));

        bounties = new Bounties(address(4545454545), 0, 0, address(mockRouter));
        rewardNft = new RewardNft(address(bounties));

        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        bounties.setRewardNft(address(rewardNft));
    }

    function helperMintApproveTokens(uint256 bountyAmount, address recipient) public {
        mockToken.mint(recipient, bountyAmount);
        mockToken.approve(address(bounties), 2 * bountyAmount);
    }

    function testCreateBounty() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 123;
        helperMintApproveTokens(bountyAmount, defaultSender);
        uint256 newBountyId = bounties.deposit(address(mockToken), bountyAmount);
        assertTrue(newBountyId == 1);
        (uint256 amount, address sponsor, address token,) = bounties.bounties(newBountyId);
        assertTrue(token == address(mockToken));
        assertTrue(amount == bountyAmount);
        assertTrue(sponsor == defaultSender);
        vm.stopPrank();
    }

    function testTopUp() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 123;
        helperMintApproveTokens(bountyAmount, defaultSender);
        uint256 newBountyId = bounties.deposit(address(mockToken), bountyAmount);
        assertTrue(newBountyId == 1);
        (uint256 amount, address sponsor, address token,) = bounties.bounties(newBountyId);
        assertTrue(token == address(mockToken));
        assertTrue(amount == bountyAmount);
        assertTrue(sponsor == defaultSender);

        // Top up
        uint256 topUpAmount = 100;
        helperMintApproveTokens(topUpAmount, defaultSender);
        bounties.topUp(newBountyId, topUpAmount);
        (amount, sponsor, token,) = bounties.bounties(newBountyId);
        assertTrue(amount == bountyAmount + topUpAmount);
        vm.stopPrank();
    }

    function testFailSettleBountyBadArbiter() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 123;
        helperMintApproveTokens(bountyAmount, defaultSender);
        uint256 newBountyId = bounties.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](1);
        recipients[0] = bidderAddress;

        uint256[] memory splits = new uint256[](1);
        splits[0] = 12;

        uint256[] memory revShares = new uint256[](1);
        revShares[0] = 0;

        bytes32 digest =
            keccak256(abi.encode(newBountyId, bidderAddress, splits[0], revShares[0])).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);

        bytes[] memory paymentSignatures = new bytes[](1);
        paymentSignatures[0] = abi.encodePacked(r, s, v);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            recipients: recipients,
            splits: splits,
            revShares: revShares,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0)
        });

        vm.prank(address(5));
        bounties.rankedSettle(input);
        vm.stopPrank();
    }

    function testSettleRankedBounty() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender);
        uint256 tokenAmountBefore = mockToken.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;

        uint256[] memory splits = new uint256[](2);
        splits[0] = splitAmount1;
        splits[1] = splitAmount2;

        uint256[] memory revShares = new uint256[](2);
        revShares[0] = 0;
        revShares[1] = 0;

        bytes[] memory paymentSignatures = new bytes[](2);
        bytes32 digest =
            keccak256(abi.encode(newBountyId, recipients[0], splits[0], revShares[0])).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);
        paymentSignatures[0] = abi.encodePacked(r, s, v);

        digest = keccak256(abi.encode(newBountyId, recipients[1], splits[1], revShares[1])).toEthSignedMessageHash();
        (v, r, s) = vm.sign(bidderPrivateKey2, digest);
        paymentSignatures[1] = abi.encodePacked(r, s, v);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            recipients: recipients,
            splits: splits,
            revShares: revShares,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0)
        });

        bounties.rankedSettle(input);
        bounties.close(newBountyId);

        uint256 expected1 = splitAmount1;
        uint256 expected2 = splitAmount2;
        uint256 expected3 = tokenAmountBefore - expected1 - expected2;
        assertTrue(mockToken.balanceOf(recipients[0]) == expected1);
        assertTrue(mockToken.balanceOf(recipients[1]) == expected2);
        assertTrue(mockToken.balanceOf(defaultSender) == expected3);
        vm.stopPrank();
    }

    function testSettleAndWithdrawFees() public {
        vm.startPrank(defaultSender);
        uint256 fee = 500;
        uint256 bountyAmount = 100_000_000;
        bounties = new Bounties(address(4545454545), fee, 0, address(mockRouter));
        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        helperMintApproveTokens(bountyAmount + ((500 * bountyAmount) / 10_000), defaultSender);
        uint256 beforeBal = mockToken.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;

        uint256[] memory splits = new uint256[](2);
        splits[0] = splitAmount1;
        splits[1] = splitAmount2;

        uint256[] memory revShares = new uint256[](2);
        revShares[0] = 0;
        revShares[1] = 0;

        bytes[] memory paymentSignatures = new bytes[](2);
        bytes32 digest =
            keccak256(abi.encode(newBountyId, recipients[0], splits[0], revShares[0])).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);
        paymentSignatures[0] = abi.encodePacked(r, s, v);

        digest = keccak256(abi.encode(newBountyId, recipients[1], splits[1], revShares[1])).toEthSignedMessageHash();
        (v, r, s) = vm.sign(bidderPrivateKey2, digest);
        paymentSignatures[1] = abi.encodePacked(r, s, v);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            recipients: recipients,
            splits: splits,
            revShares: revShares,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0)
        });

        bounties.rankedSettle(input);
        bounties.close(newBountyId);

        uint256 payout = splits[0] + splits[1];
        uint256 feePaid = (payout * fee) / 10_000;
        uint256 totalSpend = payout + feePaid;
        assertTrue(mockToken.balanceOf(defaultSender) == beforeBal - totalSpend);

        uint256 ownerBeforeBal = mockToken.balanceOf(defaultSender);
        address[] memory tokens = new address[](1);
        tokens[0] = address(mockToken);
        bounties.withdrawFees(tokens);
        assertTrue(mockToken.balanceOf(defaultSender) == ownerBeforeBal + feePaid);
        vm.stopPrank();
    }

    function testFailOnlyDisperseBountiedFunds() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000;
        helperMintApproveTokens(bountyAmount, defaultSender);
        helperMintApproveTokens(bountyAmount, address(bounties));

        assertTrue(mockToken.balanceOf(address(bounties)) == 2 * bountyAmount);

        uint256 newBountyId = bounties.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;

        uint256[] memory splits = new uint256[](2);
        splits[0] = splitAmount1;
        splits[1] = splitAmount1;

        uint256[] memory revShares = new uint256[](2);
        revShares[0] = 0;
        revShares[1] = 0;

        bytes[] memory paymentSignatures = new bytes[](2);
        bytes32 digest =
            keccak256(abi.encode(newBountyId, recipients[0], splits[0], revShares[0])).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);
        paymentSignatures[0] = abi.encodePacked(r, s, v);

        digest = keccak256(abi.encode(newBountyId, recipients[1], splits[1], revShares[1])).toEthSignedMessageHash();
        (v, r, s) = vm.sign(bidderPrivateKey2, digest);
        paymentSignatures[1] = abi.encodePacked(r, s, v);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            recipients: recipients,
            splits: splits,
            revShares: revShares,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0)
        });

        bounties.rankedSettle(input);
        vm.stopPrank();
    }

    function testFailTooFewSplits() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000;
        helperMintApproveTokens(bountyAmount, defaultSender);
        helperMintApproveTokens(bountyAmount, address(bounties));

        assertTrue(mockToken.balanceOf(address(bounties)) == 2 * bountyAmount);

        uint256 newBountyId = bounties.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;

        uint256[] memory splits = new uint256[](2);
        splits[0] = splitAmount1;

        uint256[] memory revShares = new uint256[](2);
        revShares[0] = 0;
        revShares[1] = 0;

        bytes[] memory paymentSignatures = new bytes[](2);
        bytes32 digest =
            keccak256(abi.encode(newBountyId, recipients[0], splits[0], revShares[0])).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);
        paymentSignatures[0] = abi.encodePacked(r, s, v);

        digest = keccak256(abi.encode(newBountyId, recipients[1], splits[1], revShares[1])).toEthSignedMessageHash();
        (v, r, s) = vm.sign(bidderPrivateKey2, digest);
        paymentSignatures[1] = abi.encodePacked(r, s, v);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            recipients: recipients,
            splits: splits,
            revShares: revShares,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0)
        });

        bounties.rankedSettle(input);
        vm.stopPrank();
    }

    function testOnlyWithdrawFees() public {
        vm.startPrank(defaultSender);
        uint256 fee = 500;
        uint256 bountyAmount = 100_000_000;
        bounties = new Bounties(address(4545454545), fee, 0, address(mockRouter));
        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        helperMintApproveTokens(bountyAmount + ((500 * bountyAmount) / 10_000), defaultSender);
        helperMintApproveTokens(bountyAmount, address(bounties));
        uint256 beforeBal = mockToken.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(mockToken), bountyAmount);

        {
            address[] memory recipients = new address[](2);
            recipients[0] = bidderAddress;
            recipients[1] = bidderAddress2;

            uint256[] memory splits = new uint256[](2);
            splits[0] = splitAmount1;
            splits[1] = splitAmount2;

            uint256[] memory revShares = new uint256[](2);
            revShares[0] = 0;
            revShares[1] = 0;

            bytes[] memory paymentSignatures = new bytes[](2);
            bytes32 digest =
                keccak256(abi.encode(newBountyId, recipients[0], splits[0], revShares[0])).toEthSignedMessageHash();
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);
            paymentSignatures[0] = abi.encodePacked(r, s, v);

            digest = keccak256(abi.encode(newBountyId, recipients[1], splits[1], revShares[1])).toEthSignedMessageHash();
            (v, r, s) = vm.sign(bidderPrivateKey2, digest);
            paymentSignatures[1] = abi.encodePacked(r, s, v);

            Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
                bountyId: newBountyId,
                recipients: recipients,
                splits: splits,
                revShares: revShares,
                paymentSignatures: paymentSignatures,
                postParams: new Types.PostParams[](0),
                signatures: new Types.EIP712Signature[](0)
            });

            bounties.rankedSettle(input);
            bounties.close(newBountyId);
        }

        {
            uint256 feePaid = ((splitAmount1 + splitAmount2) * fee) / 10_000;
            assertTrue(mockToken.balanceOf(defaultSender) == beforeBal - (splitAmount1 + splitAmount2 + feePaid));

            uint256 ownerBeforeBal = mockToken.balanceOf(defaultSender);
            address[] memory tokens = new address[](1);
            tokens[0] = address(mockToken);

            assertTrue(mockToken.balanceOf(address(bounties)) == bountyAmount + feePaid);
            bounties.withdrawFees(tokens);
            assertTrue(mockToken.balanceOf(defaultSender) == ownerBeforeBal + feePaid);
            assertTrue(mockToken.balanceOf(address(bounties)) == bountyAmount);
        }

        vm.stopPrank();
    }

    function testNftRewardBounty() public {
        // create bounty
        vm.startPrank(defaultSender);
        uint256 newBountyId = bounties.depositNft("ipfs://123");
        assertTrue(newBountyId == 1);
        (uint256 amount, address sponsor, address token, uint256 collectionID) = bounties.bounties(newBountyId);
        assertTrue(token == address(0));
        assertTrue(amount == 0);
        assertTrue(sponsor == defaultSender);
        assertTrue(collectionID == 1);

        // pay out bounty
        address[] memory recipients = new address[](2);
        recipients[0] = address(123);
        recipients[1] = address(124);
        bounties.nftSettle(newBountyId, recipients, new Types.PostParams[](0), new Types.EIP712Signature[](0));
        assertTrue(rewardNft.balanceOf(recipients[0], 1) == 1);
        assertTrue(rewardNft.balanceOf(recipients[1], 1) == 1);

        // close bounty
        bounties.close(newBountyId);

        vm.stopPrank();
    }

    function testRevShare() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender);
        uint256 tokenAmountBefore = mockToken.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = bidderAddress;
        recipients[1] = bidderAddress2;

        uint256[] memory splits = new uint256[](2);
        splits[0] = splitAmount1;
        splits[1] = splitAmount2;

        uint256[] memory revShares = new uint256[](2);
        revShares[0] = 10_00;
        revShares[1] = 10_00;

        bytes[] memory paymentSignatures = new bytes[](2);
        bytes32 digest =
            keccak256(abi.encode(newBountyId, recipients[0], splits[0], revShares[0])).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPrivateKey, digest);
        paymentSignatures[0] = abi.encodePacked(r, s, v);

        digest = keccak256(abi.encode(newBountyId, recipients[1], splits[1], revShares[1])).toEthSignedMessageHash();
        (v, r, s) = vm.sign(bidderPrivateKey2, digest);
        paymentSignatures[1] = abi.encodePacked(r, s, v);

        Bounties.RankedSettleInput memory input = Bounties.RankedSettleInput({
            bountyId: newBountyId,
            recipients: recipients,
            splits: splits,
            revShares: revShares,
            paymentSignatures: paymentSignatures,
            postParams: new Types.PostParams[](0),
            signatures: new Types.EIP712Signature[](0)
        });

        bounties.rankedSettle(input);
        bounties.close(newBountyId);

        uint256 expected1 = 90 * splitAmount1 / 100;
        uint256 expected2 = 90 * splitAmount2 / 100;
        uint256 expected3 = tokenAmountBefore - splitAmount1 - splitAmount2;
        assertTrue(mockToken.balanceOf(recipients[0]) == expected1);
        assertTrue(mockToken.balanceOf(recipients[1]) == expected2);
        assertTrue(mockToken.balanceOf(defaultSender) == expected3);
        vm.stopPrank();
    }
}
