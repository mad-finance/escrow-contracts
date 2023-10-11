// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/Bounties.sol";
import "../src/mocks/MockToken.sol";
import "../src/mocks/MockMadSBT.sol";
import "../src/extensions/LensExtension.sol";
import "../src/RewardNft.sol";
import "../src/RevShare.sol";

contract BountiesTest is Test {
    Bounties bounties;
    RewardNft rewardNft;
    RevShare revShare;
    MockToken mockToken;
    MockMadSBT mockMadSBT;
    address defaultSender = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

    function setUp() public {
        bounties = new Bounties(address(4545454545), 0, 0);
        rewardNft = new RewardNft(address(bounties));

        mockMadSBT = new MockMadSBT();
        mockToken = new MockToken();

        revShare = new RevShare(address(mockMadSBT));

        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        bounties.setRevShare(address(revShare));
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
        recipients[0] = address(1);

        uint256[] memory splits = new uint256[](1);
        splits[0] = 12;

        vm.prank(address(5));
        bounties.rankedSettle(
            newBountyId, recipients, splits, new Types.PostParams[](0), new Types.EIP712Signature[](0)
        );
        vm.stopPrank();
    }

    function testSettleRankedBounty() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender);
        uint256 tokenAmountBefore = mockToken.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = address(123);
        recipients[1] = address(124);

        uint256[] memory splits = new uint256[](2);
        splits[0] = 75_000;
        splits[1] = 25_000;
        bounties.rankedSettle(
            newBountyId, recipients, splits, new Types.PostParams[](0), new Types.EIP712Signature[](0)
        );
        bounties.close(newBountyId);

        uint256 expected1 = 75_000;
        uint256 expected2 = 25_000;
        uint256 expected3 = tokenAmountBefore - expected1 - expected2;
        assertTrue(mockToken.balanceOf(recipients[0]) == expected1);
        assertTrue(mockToken.balanceOf(recipients[1]) == expected2);
        assertTrue(mockToken.balanceOf(defaultSender) == expected3);
        vm.stopPrank();
    }

    function testFailClosedAccess() public {
        uint256 bountyAmount = 100_000_000;
        vm.startPrank(address(574839));
        bounties.deposit(address(mockToken), bountyAmount);
        vm.stopPrank();
    }

    function testSettleAndWithdrawFees() public {
        vm.startPrank(defaultSender);
        uint256 fee = 500;
        uint256 bountyAmount = 100_000_000;
        bounties = new Bounties(address(4545454545), fee, 0);
        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        helperMintApproveTokens(bountyAmount + ((500 * bountyAmount) / 10_000), defaultSender);
        uint256 beforeBal = mockToken.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = address(123);
        recipients[1] = address(124);

        uint256[] memory splits = new uint256[](2);
        splits[0] = 75_000;
        splits[1] = 25_000;
        bounties.rankedSettle(
            newBountyId, recipients, splits, new Types.PostParams[](0), new Types.EIP712Signature[](0)
        );
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

    function testFailOnlyDisperseBountiesedFunds() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000;
        helperMintApproveTokens(bountyAmount, defaultSender);
        helperMintApproveTokens(bountyAmount, address(bounties));

        assertTrue(mockToken.balanceOf(address(bounties)) == 2 * bountyAmount);

        uint256 newBountyId = bounties.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = address(123);
        recipients[1] = address(124);

        uint256[] memory splits = new uint256[](2);
        splits[0] = 75_000;
        splits[1] = 75_000;

        bounties.rankedSettle(
            newBountyId, recipients, splits, new Types.PostParams[](0), new Types.EIP712Signature[](0)
        );
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
        recipients[0] = address(123);
        recipients[1] = address(124);

        uint256[] memory splits = new uint256[](2);
        splits[0] = 75_000;

        bounties.rankedSettle(
            newBountyId, recipients, splits, new Types.PostParams[](0), new Types.EIP712Signature[](0)
        );
        vm.stopPrank();
    }

    function testOnlyWithdrawFees() public {
        vm.startPrank(defaultSender);
        uint256 fee = 500;
        uint256 bountyAmount = 100_000_000;
        bounties = new Bounties(address(4545454545), fee, 0);
        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        helperMintApproveTokens(bountyAmount + ((500 * bountyAmount) / 10_000), defaultSender);
        helperMintApproveTokens(bountyAmount, address(bounties));
        uint256 beforeBal = mockToken.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = address(123);
        recipients[1] = address(124);

        uint256[] memory splits = new uint256[](2);
        splits[0] = 75_000;
        splits[1] = 25_000;

        bounties.rankedSettle(
            newBountyId, recipients, splits, new Types.PostParams[](0), new Types.EIP712Signature[](0)
        );
        bounties.close(newBountyId);

        uint256 payout = splits[0] + splits[1];
        uint256 feePaid = (payout * fee) / 10_000;
        uint256 totalSpend = payout + feePaid;
        assertTrue(mockToken.balanceOf(defaultSender) == beforeBal - totalSpend);

        uint256 ownerBeforeBal = mockToken.balanceOf(defaultSender);
        address[] memory tokens = new address[](1);
        tokens[0] = address(mockToken);

        assertTrue(mockToken.balanceOf(address(bounties)) == bountyAmount + feePaid);
        bounties.withdrawFees(tokens);
        assertTrue(mockToken.balanceOf(defaultSender) == ownerBeforeBal + feePaid);
        assertTrue(mockToken.balanceOf(address(bounties)) == bountyAmount);
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
}
