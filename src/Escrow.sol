// SPDX-License-Identifier: MIT
/**
 ______   ______   ______   ______   ______   __     __    
/\  ___\ /\  ___\ /\  ___\ /\  == \ /\  __ \ /\ \  _ \ \   
\ \  __\ \ \___  \\ \ \____\ \  __< \ \ \/\ \\ \ \/ ".\ \  
 \ \_____\\/\_____\\ \_____\\ \_\ \_\\ \_____\\ \__/".~\_\ 
  \/_____/ \/_____/ \/_____/ \/_/ /_/ \/_____/ \/_/   \/_/ 

 */
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";
import "./extensions/LensExtension.sol";

contract Escrow is Ownable, LensExtension {
    uint256 private count;
    mapping(uint256 => Bounty) public bounties;
    mapping(address => bool) private allowedTokens;
    mapping(address => bool) private allowedDepositors;

    bool onlyAllowedDepositors = true;

    struct Bounty {
        uint256 amount;
        address sponsor;
        address token;
    }

    // EVENTS
    event BountyCreated(uint256 bountyId, Bounty bounty);
    event BountySettled(uint256 bountyId, address[] recipients);
    event BountyRefunded(uint256 bountyId);
    event TokensAdded(address[] tokens);
    event TokensRemoved(address[] tokens);
    event DepositorsAdded(address[] depositors);
    event DepositorsRemoved(address[] depositors);
    event OpenTheGates();

    // ERRORS
    error EarlySettlement();
    error NotArbiter();
    error TokenNotAllowed();
    error DepositorNotAllowed();
    error InvalidSplits();

    constructor(address _lensHub) Ownable() LensExtension(_lensHub) {}

    // PUBLIC FUNCTIONS

    /**
     * @notice desposits tokens creating an open bounty
     * @param token token to deposit - must be allowed
     * @param amount amount of token to deposit
     */
    function deposit(address token, uint256 amount)
        external
        returns (uint256 bountyId)
    {
        if (!allowedTokens[token]) {
            revert TokenNotAllowed();
        }
        if (onlyAllowedDepositors && !allowedDepositors[_msgSender()]) {
            revert DepositorNotAllowed();
        }
        Bounty memory newBounty = Bounty(amount, _msgSender(), token);
        bounties[++count] = newBounty;
        IERC20(token).transferFrom(_msgSender(), address(this), amount);

        emit BountyCreated(count, newBounty);
        return count;
    }

    /**
     * @notice settles the bounty by splitting evenly between all recipients
     * @param bountyId bounty to settle
     * @param recipients list of addresses to disperse to
     */
    function settle(
        uint256 bountyId,
        address[] calldata recipients,
        PostWithSigData[] calldata posts
    ) external {
        uint256 split = 100000 / recipients.length;
        Bounty memory bounty = bounties[bountyId];
        if (_msgSender() != owner() && _msgSender() != bounty.sponsor) {
            revert NotArbiter();
        }

        IERC20 token = IERC20(bounty.token);
        for (uint256 i = 0; i < recipients.length; ++i) {
            uint256 recipSplit = (split * bounty.amount) / 100000;
            token.transfer(recipients[i], recipSplit);
        }

        delete bounties[bountyId];

        postWithSigBatch(posts);

        emit BountySettled(bountyId, recipients);
    }

    /**
     * @notice settles the bounty by splitting between all recipients by percent
     * @param bountyId bounty to settle
     * @param recipients list of addresses to disperse to
     * @param splits list of split amounts to go to each recipient, should add up to 100,000
     */
    function rankedSettle(
        uint256 bountyId,
        address[] calldata recipients,
        uint256[] calldata splits,
        PostWithSigData[] calldata posts
    ) external {
        if (recipients.length != splits.length) {
            revert InvalidSplits();
        }
        Bounty memory bounty = bounties[bountyId];
        if (_msgSender() != owner() && _msgSender() != bounty.sponsor) {
            revert NotArbiter();
        }

        uint256 splitTotal;
        IERC20 token = IERC20(bounty.token);
        for (uint256 i = 0; i < recipients.length; ++i) {
            token.transfer(recipients[i], splits[i]);
            splitTotal += splits[i];
        }

        token.transfer(bounty.sponsor, bounty.amount - splitTotal);

        delete bounties[bountyId];

        postWithSigBatch(posts);

        emit BountySettled(bountyId, recipients);
    }

    /**
     * @notice can be called by owner to refund bounty in case of issue
     * @param bountyId id of bounty to refund
     */
    function refund(uint256 bountyId) external onlyOwner {
        Bounty memory bounty = bounties[bountyId];
        IERC20(bounty.token).transfer(bounty.sponsor, bounty.amount);

        delete bounties[bountyId];

        emit BountyRefunded(bountyId);
    }

    // ADMIN FUNCTIONS

    /// @notice add list of tokens to allowlist
    function addAllowListTokens(address[] calldata _allowedTokens)
        external
        onlyOwner
    {
        for (uint8 i = 0; i < _allowedTokens.length; ++i) {
            allowedTokens[_allowedTokens[i]] = true;
        }

        emit TokensAdded(_allowedTokens);
    }

    /// @notice remove list of tokens from allowlist
    function removeAllowListTokens(address[] calldata _allowedTokens)
        external
        onlyOwner
    {
        for (uint8 i = 0; i < _allowedTokens.length; ++i) {
            allowedTokens[_allowedTokens[i]] = false;
        }

        emit TokensRemoved(_allowedTokens);
    }

    /// @notice add list of depositors to allowlist
    function addDepositors(address[] calldata _allowedDepositors)
        external
        onlyOwner
    {
        for (uint8 i = 0; i < _allowedDepositors.length; ++i) {
            allowedDepositors[_allowedDepositors[i]] = true;
        }

        emit DepositorsAdded(_allowedDepositors);
    }

    /// @notice remove list of depositors from allowlist
    function removeDepositors(address[] calldata _allowedDepositors)
        external
        onlyOwner
    {
        for (uint8 i = 0; i < _allowedDepositors.length; ++i) {
            allowedDepositors[_allowedDepositors[i]] = false;
        }

        emit DepositorsRemoved(_allowedDepositors);
    }

    /// @notice remove allowlist requirement for depositors
    function openTheGates() external onlyOwner {
        onlyAllowedDepositors = false;

        emit OpenTheGates();
    }
}
