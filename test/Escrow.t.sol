// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Escrow.sol";
import "../src/mocks/MockToken.sol";
import "../src/extensions/LensExtension.sol";

contract EscrowTest is Test, DataTypes {
    Escrow escrow;
    MockToken mockToken;
    address defaultSender = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

    function setUp() public {
        escrow = new Escrow(address(4545454545), 0);
        mockToken = new MockToken();

        address[] memory depositors = new address[](1);
        depositors[0] = defaultSender;
        escrow.addDepositors(depositors);
    }

    function helperMintApproveTokens(uint256 bountyAmount, address recipient) public {
        mockToken.mint(recipient, bountyAmount);
        mockToken.approve(address(escrow), 2 * bountyAmount);
    }

    function testCreateBounty() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 123;
        helperMintApproveTokens(bountyAmount, defaultSender);
        uint256 newBountyId = escrow.deposit(address(mockToken), bountyAmount);
        assertTrue(newBountyId == 1);
        (uint256 amount, address sponsor, address token) = escrow.bounties(newBountyId);
        assertTrue(token == address(mockToken));
        assertTrue(amount == bountyAmount);
        assertTrue(sponsor == defaultSender);
        vm.stopPrank();
    }

    function testFailSettleBountyBadArbiter() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 123;
        helperMintApproveTokens(bountyAmount, defaultSender);
        uint256 newBountyId = escrow.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        uint256[] memory splits = new uint[](1);
        splits[0] = 12;

        vm.prank(address(5));
        escrow.rankedSettle(newBountyId, recipients, splits, new PostWithSigData[](0));
        vm.stopPrank();
    }

    function testSettleRankedBounty() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000_000;
        helperMintApproveTokens(bountyAmount, defaultSender);
        uint256 tokenAmountBefore = mockToken.balanceOf(defaultSender);

        uint256 newBountyId = escrow.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = address(123);
        recipients[1] = address(124);

        uint256[] memory splits = new uint256[](2);
        splits[0] = 75_000;
        splits[1] = 25_000;
        escrow.rankedSettle(newBountyId, recipients, splits, new PostWithSigData[](0));
        escrow.close(newBountyId);

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
        escrow.deposit(address(mockToken), bountyAmount);
        vm.stopPrank();
    }

    function testOpenTheGates() public {
        address newSender = address(574839);
        uint256 bountyAmount = 100_000_000;
        escrow.openTheGates();
        vm.startPrank(newSender);
        helperMintApproveTokens(bountyAmount, newSender);
        escrow.deposit(address(mockToken), bountyAmount);
        vm.stopPrank();
    }

    function testSettleAndWithdrawFees() public {
        vm.startPrank(defaultSender);
        uint256 fee = 500;
        uint256 bountyAmount = 100_000_000;
        escrow = new Escrow(address(4545454545), fee);
        escrow.openTheGates();
        helperMintApproveTokens(bountyAmount + ((500 * bountyAmount) / 10_000), defaultSender);
        uint256 beforeBal = mockToken.balanceOf(defaultSender);

        uint256 newBountyId = escrow.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = address(123);
        recipients[1] = address(124);

        uint256[] memory splits = new uint256[](2);
        splits[0] = 75_000;
        splits[1] = 25_000;
        escrow.rankedSettle(newBountyId, recipients, splits, new PostWithSigData[](0));
        escrow.close(newBountyId);

        uint256 payout = splits[0] + splits[1];
        uint256 feePaid = (payout * fee) / 10_000;
        uint256 totalSpend = payout + feePaid;
        assertTrue(mockToken.balanceOf(defaultSender) == beforeBal - totalSpend);

        uint256 ownerBeforeBal = mockToken.balanceOf(defaultSender);
        address[] memory tokens = new address[](1);
        tokens[0] = address(mockToken);
        escrow.withdrawFees(tokens);
        assertTrue(mockToken.balanceOf(defaultSender) == ownerBeforeBal + feePaid);
        vm.stopPrank();
    }

    function testFailOnlyDisperseEscrowedFunds() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000;
        helperMintApproveTokens(bountyAmount, defaultSender);
        helperMintApproveTokens(bountyAmount, address(escrow));

        assertTrue(mockToken.balanceOf(address(escrow)) == 2 * bountyAmount);

        uint256 newBountyId = escrow.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = address(123);
        recipients[1] = address(124);

        uint256[] memory splits = new uint256[](2);
        splits[0] = 75_000;
        splits[1] = 75_000;

        escrow.rankedSettle(newBountyId, recipients, splits, new PostWithSigData[](0));
        vm.stopPrank();
    }

    function testFailTooFewSplits() public {
        vm.startPrank(defaultSender);
        uint256 bountyAmount = 100_000;
        helperMintApproveTokens(bountyAmount, defaultSender);
        helperMintApproveTokens(bountyAmount, address(escrow));

        assertTrue(mockToken.balanceOf(address(escrow)) == 2 * bountyAmount);

        uint256 newBountyId = escrow.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = address(123);
        recipients[1] = address(124);

        uint256[] memory splits = new uint256[](2);
        splits[0] = 75_000;

        escrow.rankedSettle(newBountyId, recipients, splits, new PostWithSigData[](0));
        vm.stopPrank();
    }

    function testOnlyWithdrawFees() public {
        vm.startPrank(defaultSender);
        uint256 fee = 500;
        uint256 bountyAmount = 100_000_000;
        escrow = new Escrow(address(4545454545), fee);
        escrow.openTheGates();
        helperMintApproveTokens(bountyAmount + ((500 * bountyAmount) / 10_000), defaultSender);
        helperMintApproveTokens(bountyAmount, address(escrow));
        uint256 beforeBal = mockToken.balanceOf(defaultSender);

        uint256 newBountyId = escrow.deposit(address(mockToken), bountyAmount);

        address[] memory recipients = new address[](2);
        recipients[0] = address(123);
        recipients[1] = address(124);

        uint256[] memory splits = new uint256[](2);
        splits[0] = 75_000;
        splits[1] = 25_000;

        escrow.rankedSettle(newBountyId, recipients, splits, new PostWithSigData[](0));
        escrow.close(newBountyId);

        uint256 payout = splits[0] + splits[1];
        uint256 feePaid = (payout * fee) / 10_000;
        uint256 totalSpend = payout + feePaid;
        assertTrue(mockToken.balanceOf(defaultSender) == beforeBal - totalSpend);

        uint256 ownerBeforeBal = mockToken.balanceOf(defaultSender);
        address[] memory tokens = new address[](1);
        tokens[0] = address(mockToken);

        assertTrue(mockToken.balanceOf(address(escrow)) == bountyAmount + feePaid);
        escrow.withdrawFees(tokens);
        assertTrue(mockToken.balanceOf(defaultSender) == ownerBeforeBal + feePaid);
        assertTrue(mockToken.balanceOf(address(escrow)) == bountyAmount);
        vm.stopPrank();
    }
}
