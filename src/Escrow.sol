// SPDX-License-Identifier: UNLICENSED
/**
 ______   ______   __  __   __   __   ______  __  __       
/\  == \ /\  __ \ /\ \/\ \ /\ "-.\ \ /\__  _\/\ \_\ \      
\ \  __< \ \ \/\ \\ \ \_\ \\ \ \-.  \\/_/\ \/\ \____ \     
 \ \_____\\ \_____\\ \_____\\ \_\\"\_\  \ \_\ \/\_____\    
  \/_____/ \/_____/ \/_____/ \/_/ \/_/   \/_/  \/_____/    
 ______   ______   ______   ______   ______   __     __    
/\  ___\ /\  ___\ /\  ___\ /\  == \ /\  __ \ /\ \  _ \ \   
\ \  __\ \ \___  \\ \ \____\ \  __< \ \ \/\ \\ \ \/ ".\ \  
 \ \_____\\/\_____\\ \_____\\ \_\ \_\\ \_____\\ \__/".~\_\ 
  \/_____/ \/_____/ \/_____/ \/_/ /_/ \/_____/ \/_/   \/_/ 

 */
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";
import "./interfaces/IEscrow.sol";

contract Escrow is IEscrow, Ownable {
    uint256 private count;
    mapping(uint256 => Bounty) public bounties;
    mapping(address => bool) private allowedTokens;
    mapping(address => bool) private allowedDepositors;

    constructor() Ownable() {}

    // PUBLIC FUNCTIONS
    function deposit(
        address token,
        uint256 amount,
        uint32 start,
        uint32 length
    ) external override returns (uint256 bountyId) {
        if (!allowedTokens[token]) {
            revert TokenNotAllowed();
        }
        if (!allowedDepositors[_msgSender()]) {
            revert DepositorNotAllowed();
        }
        if (start < block.timestamp) {
            start = uint32(block.timestamp);
        }
        Bounty memory newBounty = Bounty(
            amount,
            length,
            _msgSender(),
            start,
            token
        );
        bounties[++count] = newBounty;
        IERC20(token).transferFrom(_msgSender(), address(this), amount);

        emit BountyCreated(count, newBounty);
        return count;
    }

    function settle(uint256 bountyId, address[] calldata recipients)
        external
        override
    {
        uint256 split = 100000 / recipients.length;
        Bounty memory bounty = bounties[bountyId];
        if (_msgSender() != owner() && _msgSender() != bounty.sponsor) {
            revert NotArbiter();
        }
        if (block.timestamp < bounty.start + bounty.bountyLength) {
            revert EarlySettlement();
        }

        IERC20 token = IERC20(bounty.token);
        for (uint256 i = 0; i < recipients.length; ++i) {
            uint256 recipSplit = (split * bounty.amount) / 100000;
            token.transfer(recipients[i], recipSplit);
        }

        delete bounties[bountyId];

        emit BountySettled(bountyId, recipients);
    }

    function rankedSettle(
        uint256 bountyId,
        address[] calldata recipients,
        uint256[] calldata splits
    ) external override {
        if (recipients.length != splits.length) {
            revert InvalidSplits();
        }
        Bounty memory bounty = bounties[bountyId];
        if (_msgSender() != owner() && _msgSender() != bounty.sponsor) {
            revert NotArbiter();
        }
        if (block.timestamp < bounty.start + bounty.bountyLength) {
            revert EarlySettlement();
        }

        uint256 splitTotal;
        IERC20 token = IERC20(bounty.token);
        for (uint256 i = 0; i < recipients.length; ++i) {
            uint256 recipSplit = (splits[i] * bounty.amount) / 100000;
            splitTotal += recipSplit;
            token.transfer(recipients[i], recipSplit);
        }

        if (splitTotal != bounty.amount) {
            revert InvalidSplits();
        }

        delete bounties[bountyId];

        emit BountySettled(bountyId, recipients);
    }

    function refund(uint256 bountyId) external override onlyOwner {
        Bounty memory bounty = bounties[bountyId];
        IERC20(bounty.token).transfer(bounty.sponsor, bounty.amount);

        delete bounties[bountyId];

        emit BountyRefunded(bountyId);
    }

    // ADMIN FUNCTIONS
    function addAllowListTokens(address[] calldata _allowedTokens)
        external
        override
        onlyOwner
    {
        for (uint8 i = 0; i < _allowedTokens.length; ++i) {
            allowedTokens[_allowedTokens[i]] = true;
        }

        emit TokensAdded(_allowedTokens);
    }

    function removeAllowListTokens(address[] calldata _allowedTokens)
        external
        override
        onlyOwner
    {
        for (uint8 i = 0; i < _allowedTokens.length; ++i) {
            allowedTokens[_allowedTokens[i]] = false;
        }

        emit TokensRemoved(_allowedTokens);
    }

    function addDepositors(address[] calldata _allowedDepositors)
        external
        override
        onlyOwner
    {
        for (uint8 i = 0; i < _allowedDepositors.length; ++i) {
            allowedDepositors[_allowedDepositors[i]] = true;
        }

        emit DepositorsAdded(_allowedDepositors);
    }

    function removeDepositors(address[] calldata _allowedDepositors)
        external
        override
        onlyOwner
    {
        for (uint8 i = 0; i < _allowedDepositors.length; ++i) {
            allowedDepositors[_allowedDepositors[i]] = false;
        }

        emit DepositorsRemoved(_allowedDepositors);
    }
}
