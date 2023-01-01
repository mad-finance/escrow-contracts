// SPDX-License-Identifier: MIT
/**
 * ______   ______   ______   ______   ______   __     __
 * /\  ___\ /\  ___\ /\  ___\ /\  == \ /\  __ \ /\ \  _ \ \
 * \ \  __\ \ \___  \\ \ \____\ \  __< \ \ \/\ \\ \ \/ ".\ \
 *  \ \_____\\/\_____\\ \_____\\ \_\ \_\\ \_____\\ \__/".~\_\
 *   \/_____/ \/_____/ \/_____/ \/_/ /_/ \/_____/ \/_/   \/_/
 */
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";
import "./extensions/LensExtension.sol";

contract Escrow is Ownable, LensExtension {
    uint256 public protocolFee; // basis points
    mapping(address => uint256) public feesEarned;

    uint256 internal count;
    mapping(uint256 => Bounty) public bounties;
    mapping(address => bool) public allowedDepositors;

    bool internal onlyAllowedDepositors = true;

    struct Bounty {
        uint256 amount;
        address sponsor;
        address token;
    }

    // EVENTS
    event BountyCreated(uint256 bountyId, Bounty bounty);
    event BountyPayments(address[] recipients);
    event BountyClosed(uint256 bountyId);
    event DepositorsAdded(address[] depositors);
    event DepositorsRemoved(address[] depositors);
    event OpenTheGates();
    event SetProtocolFee(uint256 protocolFee);

    // ERRORS
    error EarlySettlement();
    error NotArbiter();
    error DepositorNotAllowed();
    error InvalidSplits();

    constructor(address _lensHub, uint256 _protocolFee) Ownable() LensExtension(_lensHub) {
        protocolFee = _protocolFee;
    }

    // PUBLIC FUNCTIONS

    /**
     * @notice desposits tokens creating an open bounty
     * @param token token to deposit
     * @param amount amount of token to deposit
     */
    function deposit(address token, uint256 amount) external returns (uint256 bountyId) {
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
     * @notice disperse funds to recipeints and post to Lens
     * @param bountyId bounty to settle
     * @param recipients list of addresses to disperse to
     * @param splits list of split amounts to go to each recipient
     * @param posts PostWithSigData to post to Lens on recipients behalf
     */
    function rankedSettle(
        uint256 bountyId,
        address[] calldata recipients,
        uint256[] calldata splits,
        PostWithSigData[] calldata posts
    ) external {
        _rankedSettle(bountyId, recipients, splits);
        postWithSigBatch(posts);
    }

    function _rankedSettle(uint256 bountyId, address[] calldata recipients, uint256[] calldata splits) internal {
        Bounty memory bounty = bounties[bountyId];
        if (_msgSender() != bounty.sponsor) {
            revert NotArbiter();
        }

        uint256 splitTotal;
        IERC20 token = IERC20(bounty.token);
        for (uint256 i = 0; i < recipients.length; ++i) {
            splitTotal += splits[i];
            token.transfer(recipients[i], splits[i]);
        }

        uint256 newFees = calcFee(splitTotal);
        uint256 total = newFees + splitTotal;
        if (total > bounty.amount) {
            revert InvalidSplits();
        }

        bounties[bountyId].amount -= total;
        feesEarned[bounty.token] += newFees;

        emit BountyPayments(recipients);
    }

    /**
     * @notice can be called by owner or bounty creator to close bounty and refund
     * @param bountyId id of bounty to refund
     */
    function close(uint256 bountyId) external {
        Bounty memory bounty = bounties[bountyId];
        IERC20(bounty.token).transfer(bounty.sponsor, bounty.amount);
        delete bounties[bountyId];

        emit BountyClosed(bountyId);
    }

    /**
     * @notice calculates the fee to be paid on a token amount
     * @param amount token amount to calculate fee for
     */
    function calcFee(uint256 amount) public view returns (uint256) {
        return (amount * protocolFee) / 10_000;
    }

    // ADMIN FUNCTIONS

    /// @notice sets the protocol fee (in basis points). Close all outstanding bounties before calling
    function setProtocolFee(uint256 _protocolFee) external onlyOwner {
        protocolFee = _protocolFee;

        emit SetProtocolFee(_protocolFee);
    }

    /// @notice withdraws all accumulated fees
    function withdrawFees(address[] calldata _tokens) external onlyOwner {
        for (uint256 i = 0; i < _tokens.length; ++i) {
            uint256 contractBal = feesEarned[_tokens[i]];
            feesEarned[_tokens[i]] = 0;
            IERC20(_tokens[i]).transfer(owner(), contractBal);
        }
    }

    /// @notice add list of depositors to allowlist
    function addDepositors(address[] calldata _allowedDepositors) external onlyOwner {
        for (uint8 i = 0; i < _allowedDepositors.length; ++i) {
            allowedDepositors[_allowedDepositors[i]] = true;
        }

        emit DepositorsAdded(_allowedDepositors);
    }

    /// @notice remove list of depositors from allowlist
    function removeDepositors(address[] calldata _allowedDepositors) external onlyOwner {
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

    /// @notice fallback function to prevent accidental ether transfers
    receive() external payable {
        revert();
    }
}
