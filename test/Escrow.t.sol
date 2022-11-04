// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Escrow.sol";
import "../src/mocks/MockToken.sol";

contract EscrowTest is Test {
    Escrow escrow;
    MockToken mockToken;
    address defaultSender = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

    function setUp() public {
        escrow = new Escrow();
        mockToken = new MockToken();

        address[] memory depositors = new address[](1);
        depositors[0] = defaultSender;
        escrow.addDepositors(depositors);
    }

    function helperAddMockToken() public {
        address[] memory newTokens = new address[](1);
        newTokens[0] = address(mockToken);
        escrow.addAllowListTokens(newTokens);
    }

    function helperMintApproveTokens(uint256 bountyAmount, address recipient)
        public
    {
        vm.startPrank(recipient);
        mockToken.mint(recipient, bountyAmount);
        mockToken.approve(address(escrow), bountyAmount);
        vm.stopPrank();
    }

    function testCreateBounty() public {
        uint256 bountyAmount = 123;
        helperAddMockToken();
        helperMintApproveTokens(bountyAmount, defaultSender);
        uint256 newBountyId = escrow.deposit(address(mockToken), bountyAmount);
        assertTrue(newBountyId == 1);
        (uint256 amount, address sponsor, address token) = escrow.bounties(
            newBountyId
        );
        assertTrue(token == address(mockToken));
        assertTrue(amount == bountyAmount);
        assertTrue(sponsor == defaultSender);
    }

    function testFailUnkownToken() public {
        uint256 bountyAmount = 123;
        mockToken.mint(defaultSender, bountyAmount);
        mockToken.approve(address(escrow), bountyAmount);
        escrow.deposit(address(mockToken), bountyAmount);
    }

    function testSettleBounty() public {
        uint256 bountyAmount = 123;
        helperAddMockToken();
        helperMintApproveTokens(bountyAmount, defaultSender);
        uint256 newBountyId = escrow.deposit(address(mockToken), bountyAmount);
        vm.warp(block.timestamp + 10);

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        escrow.settle(newBountyId, recipients);
        assertTrue(mockToken.balanceOf(address(1)) == bountyAmount);

        // another address can settle as long as its the bounty creator
        address newSponsor = address(4);

        address[] memory depositors = new address[](1);
        depositors[0] = newSponsor;
        escrow.addDepositors(depositors);

        helperMintApproveTokens(bountyAmount, newSponsor);
        vm.startPrank(newSponsor);
        newBountyId = escrow.deposit(address(mockToken), bountyAmount);
        vm.warp(block.timestamp + 10);

        escrow.settle(newBountyId, recipients);
        assertTrue(mockToken.balanceOf(address(1)) == bountyAmount * 2);
        vm.stopPrank();
    }

    function testFailSettleBountyBadArbiter() public {
        uint256 bountyAmount = 123;
        helperAddMockToken();
        helperMintApproveTokens(bountyAmount, defaultSender);
        uint256 newBountyId = escrow.deposit(address(mockToken), bountyAmount);
        vm.warp(block.timestamp + 9);

        address[] memory recipients = new address[](1);
        recipients[0] = address(1);

        vm.prank(address(5));
        escrow.settle(newBountyId, recipients);
    }

    function testSettleRankedBounty() public {
        uint256 bountyAmount = 100000000;
        helperAddMockToken();
        helperMintApproveTokens(bountyAmount, defaultSender);
        uint256 newBountyId = escrow.deposit(address(mockToken), bountyAmount);
        vm.warp(block.timestamp + 10);

        address[] memory recipients = new address[](2);
        recipients[0] = address(123);
        recipients[1] = address(124);

        uint256[] memory splits = new uint256[](2);
        splits[0] = 75000;
        splits[1] = 25000;
        escrow.rankedSettle(newBountyId, recipients, splits);

        uint256 expected1 = (splits[0] * bountyAmount) / 100000;
        uint256 expected2 = (splits[1] * bountyAmount) / 100000;
        assertTrue(mockToken.balanceOf(recipients[0]) == expected1);
        assertTrue(mockToken.balanceOf(recipients[1]) == expected2);
    }

    function testFailClosedAccess() public {
        uint256 bountyAmount = 100000000;
        vm.startPrank(address(574839));
        uint256 newBountyId = escrow.deposit(address(mockToken), bountyAmount);
        vm.stopPrank();
    }

    function testOpenTheGates() public {
        address newSender = address(574839);
        uint256 bountyAmount = 100000000;
        escrow.openTheGates();
        helperAddMockToken();
        helperMintApproveTokens(bountyAmount, newSender);
        vm.startPrank(newSender);
        uint256 newBountyId = escrow.deposit(address(mockToken), bountyAmount);
        vm.stopPrank();
    }
}
