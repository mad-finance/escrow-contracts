// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "./helpers/TestHelper.sol";

contract BountiesTest is TestHelper {
    function testCreateBounty() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 123;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);
        assertEq(newBountyId, 1);
        (uint256 amount,, address sponsor, address token) = bounties.bounties(newBountyId);
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
        (uint256 amount,, address sponsor, address token) = bounties.bounties(newBountyId);
        assertEq(token, address(usdc));
        assertEq(amount, bountyAmount);
        assertEq(sponsor, defaultSender);

        // Top up
        uint256 topUpAmount = 100;
        helperMintApproveTokens(topUpAmount, defaultSender, usdc);
        bounties.topUp(newBountyId, topUpAmount);
        (amount,, sponsor, token) = bounties.bounties(newBountyId);
        assertEq(amount, bountyAmount + topUpAmount);
        vm.stopPrank();
    }

    function testFailSettleBountyBadArbiter() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 123;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        Bounties.RankedSettleInput[] memory input = createSettleData(newBountyId);

        vm.prank(address(5));
        bounties.rankedSettle(newBountyId, input, uniswapFee);
        vm.stopPrank();
    }

    function testSettleRankedBounty() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 tokenAmountBefore = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        Bounties.RankedSettleInput[] memory input = createSettleDataTwoBidders(newBountyId, 0);

        bounties.rankedSettle(newBountyId, input, uniswapFee);
        bounties.close(newBountyId);

        vm.stopPrank();

        uint256 expected1 = bidAmount1;
        uint256 expected2 = bidAmount2;
        uint256 expected3 = tokenAmountBefore - expected1 - expected2;
        assertEq(usdc.balanceOf(bidderAddress), expected1);
        assertEq(usdc.balanceOf(bidderAddress2), expected2);
        assertEq(usdc.balanceOf(defaultSender), expected3);
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

    function testSettleRankedBountyPayOnly() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 tokenAmountBefore = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        (Bounties.BidFromAction[] memory input, bytes[] memory signatures) =
            createPayOnlySettleDataTwoBidders(newBountyId, 0);

        bounties.rankedSettlePayOnly(newBountyId, input, signatures, uniswapFee);
        bounties.close(newBountyId);

        vm.stopPrank();

        uint256 expected1 = bidAmount1;
        uint256 expected2 = bidAmount2;
        uint256 expected3 = tokenAmountBefore - expected1 - expected2;
        assertEq(usdc.balanceOf(bidderAddress), expected1);
        assertEq(usdc.balanceOf(bidderAddress2), expected2);
        assertEq(usdc.balanceOf(defaultSender), expected3);
    }

    function testSettleAndWithdrawFees() public {
        uint256 protocolFee = 0;
        uint256 bountyAmount = 100_000_000;
        vm.startPrank(defaultSender);
        bounties = new Bounties(lensHub, protocolFee, 0, address(swapRouter));
        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        vm.stopPrank();

        setDelegatedExecutors(address(bounties));

        vm.startPrank(defaultSender);
        helperMintApproveTokens(bountyAmount + ((500 * bountyAmount) / 10_000), defaultSender, usdc);
        uint256 beforeBal = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        Bounties.RankedSettleInput[] memory input = createSettleDataTwoBidders(newBountyId, 0);

        bounties.rankedSettle(newBountyId, input, uniswapFee);
        bounties.close(newBountyId);

        uint256 payout = bidAmount1 + bidAmount2;
        uint256 feePaid = (payout * protocolFee) / 10_000;
        uint256 totalSpend = payout + feePaid;
        assertEq(usdc.balanceOf(defaultSender), beforeBal - totalSpend);

        uint256 ownerBeforeBal = usdc.balanceOf(defaultSender);
        address[] memory tokens = new address[](1);
        tokens[0] = address(usdc);
        bounties.withdrawFees(tokens);
        assertEq(usdc.balanceOf(defaultSender), ownerBeforeBal + feePaid, "Sponsor is not correct");

        vm.stopPrank();
    }

    function testFailOnlyDisperseBountiedFunds() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        helperMintApproveTokens(bountyAmount, address(bounties), usdc);

        assertEq(usdc.balanceOf(address(bounties)), 2 * bountyAmount);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        Bounties.RankedSettleInput[] memory input = createSettleDataTwoBidders(newBountyId, 0);

        bounties.rankedSettle(newBountyId, input, uniswapFee);
        vm.stopPrank();
    }

    function testOnlyWithdrawFees() public {
        uint256 protocolFee = 500;
        uint256 bountyAmount = 100_000_000;
        vm.startPrank(defaultSender);
        bounties = new Bounties(lensHub, protocolFee, 0, address(swapRouter));
        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        vm.stopPrank();

        setDelegatedExecutors(address(bounties));

        vm.startPrank(defaultSender);
        helperMintApproveTokens(bountyAmount + ((500 * bountyAmount) / 10_000), defaultSender, usdc);
        helperMintApproveTokens(bountyAmount, address(bounties), usdc);
        uint256 beforeBal = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount);

        Bounties.RankedSettleInput[] memory input = createSettleDataTwoBidders(newBountyId, 0);

        bounties.rankedSettle(newBountyId, input, uniswapFee);
        bounties.close(newBountyId);

        uint256 feePaid = ((bidAmount1 + bidAmount2) * protocolFee) / 10_000;
        assertEq(usdc.balanceOf(defaultSender), beforeBal - (bidAmount1 + bidAmount2 + feePaid));

        uint256 ownerBeforeBal = usdc.balanceOf(defaultSender);
        address[] memory tokens = new address[](1);
        tokens[0] = address(usdc);

        assertEq(
            usdc.balanceOf(address(bounties)),
            bountyAmount + feePaid,
            "Bounties contract balance is not correct (before withdraw)"
        );
        bounties.withdrawFees(tokens);
        assertEq(usdc.balanceOf(defaultSender), ownerBeforeBal + feePaid, "Sponsor balance is not correct");
        assertEq(
            usdc.balanceOf(address(bounties)), bountyAmount, "Bounties contract balance is not correct (after withdraw)"
        );

        vm.stopPrank();
    }

    function testNftRewardBounty() public {
        // create bounty
        vm.startPrank(defaultSender);
        uint256 newBountyId = bounties.depositNft("ipfs://123");
        assertEq(newBountyId, 1);
        (uint256 amount, uint256 collectionID, address sponsor, address token) = bounties.bounties(newBountyId);
        assertEq(token, address(0));
        assertEq(amount, 0);
        assertEq(sponsor, defaultSender);
        assertEq(collectionID, 1);

        Bounties.NftSettleInput[] memory input = createNftSettleDataTwoBidders(newBountyId);
        bounties.nftSettle(newBountyId, input);

        assertEq(rewardNft.balanceOf(bidderAddress, 1), 1);
        assertEq(rewardNft.balanceOf(bidderAddress2, 1), 1);
        assertEq(rewardNft.totalSupply(1), 2);

        address[] memory recipients = new address[](2);
        recipients[0] = address(1);
        recipients[1] = address(2);
        bounties.nftSettlePayOnly(newBountyId, recipients);

        assertEq(rewardNft.balanceOf(address(1), 1), 1);
        assertEq(rewardNft.balanceOf(address(2), 1), 1);

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

        Bounties.RankedSettleInput[] memory input = createSettleDataTwoBidders(newBountyId, 10_00);

        bounties.rankedSettle(newBountyId, input, uniswapFee);
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

        Bounties.RankedSettleInput[] memory input = createSettleDataTwoBidders(newBountyId, 10_00);

        bounties.rankedSettle(newBountyId, input, uniswapFee);
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
}
