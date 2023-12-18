// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "./helpers/TestHelper.sol";

contract BountiesTest is TestHelper {
    function testStickerDrop() public {
        vm.startPrank(defaultSender);
        string memory tokenUri = "ipfs://bafkreiduigb4zpsumwhxd3hgslwkr4jgqa2cznzpmycxezyfm4ooasudfq";
        uint256 id = rewardNft.createCollection(tokenUri, defaultSender);
        rewardNft.mint(address(107), id, 1, "");
        assertEq(rewardNft.balanceOf(address(107), id), 1);

        address[] memory recipients = new address[](2);
        recipients[0] = address(208);
        recipients[1] = address(308);
        rewardNft.batchMint(recipients, id, "");
        assertEq(rewardNft.balanceOf(address(208), id), 1);
        assertEq(rewardNft.balanceOf(address(308), id), 1);
        vm.stopPrank();

        vm.prank(address(9));
        vm.expectRevert();
        rewardNft.mint(address(9), id, 1, "");
    }

    function testCreateBounty() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 123;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount, 0);
        assertEq(newBountyId, 1);
        (uint256 amount,, address sponsor,, address token) = bounties.bounties(newBountyId);
        assertEq(token, address(usdc));
        assertEq(amount, bountyAmount);
        assertEq(sponsor, defaultSender);
        vm.stopPrank();
    }

    function testTopUp() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 123;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount, 0);
        assertEq(newBountyId, 1);
        (uint256 amount,, address sponsor,, address token) = bounties.bounties(newBountyId);
        assertEq(token, address(usdc));
        assertEq(amount, bountyAmount);
        assertEq(sponsor, defaultSender);

        // Top up
        uint256 topUpAmount = 100;
        helperMintApproveTokens(topUpAmount, defaultSender, usdc);
        bounties.topUp(newBountyId, topUpAmount);
        (amount,, sponsor,, token) = bounties.bounties(newBountyId);
        assertEq(amount, bountyAmount + topUpAmount);
        vm.stopPrank();
    }

    function testFailSettleBountyBadArbiter() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 123;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount, 0);

        Structs.RankedSettleInput[] memory input = createSettleData(newBountyId);

        vm.prank(address(5));
        bounties.rankedSettle(newBountyId, input, uniswapFee);
        vm.stopPrank();
    }

    function testSettleRankedBounty() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 tokenAmountBefore = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount, 0);

        Structs.RankedSettleInput[] memory input = createSettleDataTwoBidders(newBountyId, 0, 0);

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

    function testSettleRankedBountyQuote() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 tokenAmountBefore = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount, 0);

        Structs.RankedSettleInputQuote[] memory input = createQuoteSettleData(newBountyId);

        bounties.rankedSettleQuote(newBountyId, input, uniswapFee);
        bounties.close(newBountyId);

        vm.stopPrank();

        uint256 expected1 = bidAmount1;
        uint256 expected2 = tokenAmountBefore - expected1;
        assertEq(usdc.balanceOf(bidderAddress), expected1);
        assertEq(usdc.balanceOf(defaultSender), expected2);
    }

    function testSettleRankedBountyFromAction() public {
        // enable action module
        address openAction = address(70);
        bounties.setPublicationActionModule(openAction);

        // set protocol fee (required for referral fee)
        uint256 protocolFee = 500;
        bounties.setProtocolFee(protocolFee);

        // set referral fee - 5000 = 50%
        uint256 referralFee = 5000;
        bounties.setReferralFee(referralFee);

        // whitelist client referral
        bounties.setWhitelistedTransactionExecutor(client, true);

        // begin test
        vm.startPrank(openAction);
        uint256 bountyAmount = 100_000_000;
        uint256 bountyTotal = bountyAmount + (protocolFee * bountyAmount / 10_000);
        helperMintApproveTokens(bountyTotal, openAction, usdc);

        {
            uint256 newBountyId = bounties.depositFromAction(defaultSender, address(usdc), bountyTotal, 0);

            address[] memory recipients = new address[](2);
            recipients[0] = bidderAddress;
            recipients[1] = bidderAddress2;

            uint256[] memory bids = new uint256[](2);
            bids[0] = bidAmount1;
            bids[1] = bidAmount2;

            uint256[] memory revShares = new uint256[](2);
            revShares[0] = 0;
            revShares[1] = 0;

            Structs.BidFromAction[] memory data = createBidFromActionParam(recipients, bids, revShares);

            Structs.RankedSettleFromActionInput memory input = Structs.RankedSettleFromActionInput({
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
        }

        {
            uint256 expected1 = bidAmount1;
            uint256 expected2 = bidAmount2;
            uint256 expected3 = bountyTotal - (expected1 + (protocolFee * expected1 / 10_000))
                - (expected2 + (protocolFee * expected2 / 10_000));
            assertEq(usdc.balanceOf(bidderAddress), expected1, "Bidder 1 balance is not correct");
            assertEq(usdc.balanceOf(bidderAddress2), expected2, "Bidder 2 balance is not correct");
            assertEq(usdc.balanceOf(defaultSender), expected3, "Sponsor balance is not correct");
            assertEq(usdc.balanceOf(openAction), 0, "Open Action balance is not correct");
        }

        // check client referral reward
        {
            vm.prank(client);
            assertEq(
                usdc.balanceOf(client),
                protocolFee * (bidAmount1 + bidAmount2) / 10_000 / 2,
                "Referral reward is not correct"
            );
        }
    }

    function testSettleRankedBountyPayOnly() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 tokenAmountBefore = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount, 0);

        (Structs.BidFromAction[] memory input, bytes[] memory signatures) =
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
        uint256 protocolFee = 500;
        uint256 bountyAmount = 100_000_000;
        vm.startPrank(defaultSender);
        bounties = new Bounties(lensHub, protocolFee, 0, address(swapRouter), address(mockReferralHandler));
        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        vm.stopPrank();

        setDelegatedExecutors(address(bounties));

        vm.startPrank(defaultSender);
        helperMintApproveTokens(bountyAmount + (protocolFee * bountyAmount / 10_000), defaultSender, usdc);
        uint256 beforeBal = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount, 0);

        Structs.RankedSettleInput[] memory input = createSettleDataTwoBidders(newBountyId, 0, 0);

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
        // owner should be able to withdraw half of the protocol fee
        assertEq(usdc.balanceOf(defaultSender), ownerBeforeBal + feePaid / 2, "Sponsor is not correct");

        // referral rewards - the other half of the protocol fee
        assertEq(usdc.balanceOf(address(123123)), feePaid / 2, "Referral reward is not correct");

        vm.stopPrank();
    }

    function testFailOnlyDisperseBountiedFunds() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        helperMintApproveTokens(bountyAmount, address(bounties), usdc);

        assertEq(usdc.balanceOf(address(bounties)), 2 * bountyAmount);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount, 0);

        Structs.RankedSettleInput[] memory input = createSettleDataTwoBidders(newBountyId, 0, 0);

        bounties.rankedSettle(newBountyId, input, uniswapFee);
        vm.stopPrank();
    }

    function testOnlyWithdrawFees() public {
        uint256 protocolFee = 500;
        uint256 bountyAmount = 100_000_000;
        vm.startPrank(defaultSender);
        bounties = new Bounties(lensHub, protocolFee, 0, address(swapRouter), address(mockReferralHandler));
        bounties.setMadSBT(address(mockMadSBT), 1, 1);
        vm.stopPrank();

        setDelegatedExecutors(address(bounties));

        vm.startPrank(defaultSender);
        helperMintApproveTokens(bountyAmount + ((500 * bountyAmount) / 10_000), defaultSender, usdc);
        helperMintApproveTokens(bountyAmount, address(bounties), usdc);
        uint256 beforeBal = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount, 0);

        Structs.RankedSettleInput[] memory input = createSettleDataTwoBidders(newBountyId, 0, 0);

        bounties.rankedSettle(newBountyId, input, uniswapFee);
        bounties.close(newBountyId);

        uint256 feePaid = ((bidAmount1 + bidAmount2) * protocolFee) / 10_000;
        assertEq(usdc.balanceOf(defaultSender), beforeBal - (bidAmount1 + bidAmount2 + feePaid));

        uint256 ownerBeforeBal = usdc.balanceOf(defaultSender);
        address[] memory tokens = new address[](1);
        tokens[0] = address(usdc);

        assertEq(
            usdc.balanceOf(address(bounties)),
            bountyAmount + feePaid / 2, // half goes to referral
            "Bounties contract balance is not correct (before withdraw)"
        );
        bounties.withdrawFees(tokens);
        // half of feePaid goes to referral
        assertEq(usdc.balanceOf(defaultSender), ownerBeforeBal + feePaid / 2, "Sponsor balance is not correct");
        assertEq(
            usdc.balanceOf(address(bounties)), bountyAmount, "Bounties contract balance is not correct (after withdraw)"
        );

        vm.stopPrank();
    }

    function testNftRewardBounty() public {
        // create bounty
        vm.startPrank(defaultSender);
        uint256 newBountyId = bounties.depositNft("ipfs://123", 0);
        assertEq(newBountyId, 1);
        (uint256 amount, uint256 collectionID, address sponsor,, address token) = bounties.bounties(newBountyId);
        assertEq(token, address(0));
        assertEq(amount, 0);
        assertEq(sponsor, defaultSender);
        assertEq(collectionID, 1);

        // post settle
        Structs.NftSettleInput[] memory input = createNftSettleDataTwoBidders(newBountyId);
        bounties.nftSettle(newBountyId, input);

        assertEq(rewardNft.balanceOf(bidderAddress, 1), 1);
        assertEq(rewardNft.balanceOf(bidderAddress2, 1), 1);
        assertEq(rewardNft.totalSupply(1), 2);

        // pay only settle
        address[] memory recipients = new address[](2);
        recipients[0] = address(1);
        recipients[1] = address(2);
        bounties.nftSettlePayOnly(newBountyId, recipients);

        assertEq(rewardNft.balanceOf(address(1), 1), 1);
        assertEq(rewardNft.balanceOf(address(2), 1), 1);

        // quote settle
        Structs.NftSettleInputQuote[] memory inputQuote = createNftSettleDataQuote(newBountyId);
        bounties.nftSettleQuote(newBountyId, inputQuote);

        assertEq(rewardNft.balanceOf(bidderAddress, 1), 2);

        // close bounty
        bounties.close(newBountyId);

        vm.stopPrank();
    }

    function testRevShare() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender, usdc);
        uint256 tokenAmountBefore = usdc.balanceOf(defaultSender);

        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount, 0);

        Structs.RankedSettleInput[] memory input = createSettleDataTwoBidders(newBountyId, 10_00, 1);

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

        uint256 newBountyId = bounties.deposit(address(wmatic), bountyAmount, 0);

        Structs.RankedSettleInput[] memory input = createSettleDataTwoBidders(newBountyId, 10_00, 1);

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
