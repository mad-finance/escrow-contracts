// SPDX-License-Identifier: MIT
/**
 * ______   ______   ______   ______   ______   __     __
 * /\  ___\ /\  ___\ /\  ___\ /\  == \ /\  __ \ /\ \  _ \ \
 * \ \  __\ \ \___  \\ \ \____\ \  __< \ \ \/\ \\ \ \/ ".\ \
 *  \ \_____\\/\_____\\ \_____\\ \_\ \_\\ \_____\\ \__/".~\_\
 *   \/_____/ \/_____/ \/_____/ \/_/ /_/ \/_____/ \/_/   \/_/
 */
pragma solidity ^0.8.10;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";
import "./extensions/LensExtension.sol";

contract EscrowV2 is Ownable, LensExtension {
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
    event BountyPayments(
        uint256 bountyId,
        address[] recipients,
        uint256 amount
    );
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

    constructor(address _lensHub, uint256 _protocolFee, uint _startId)
        Ownable()
        LensExtension(_lensHub)
    {
        protocolFee = _protocolFee;
        count = _startId;
    }

    // PUBLIC FUNCTIONS

    /**
     * @notice desposits tokens creating an open bounty
     * @param token token to deposit
     * @param amount amount of token to deposit
     */
    function deposit(address token, uint256 amount)
        external
        returns (uint256 bountyId)
    {
        if (onlyAllowedDepositors && !allowedDepositors[_msgSender()]) {
            revert DepositorNotAllowed();
        }
        uint256 total = amount + calcFee(amount);
        Bounty memory newBounty = Bounty(total, _msgSender(), token);
        bounties[++count] = newBounty;

        IERC20(token).transferFrom(_msgSender(), address(this), total);

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
        DataTypes.PostWithSigData[] calldata posts
    ) external {
        _rankedSettle(bountyId, recipients, splits);
        postWithSigBatch(posts);
    }

    function _rankedSettle(
        uint256 bountyId,
        address[] calldata recipients,
        uint256[] calldata splits
    ) internal {
        Bounty memory bounty = bounties[bountyId];
        if (_msgSender() != bounty.sponsor) {
            revert NotArbiter();
        }

        uint256 splitTotal;
        uint256 length = recipients.length;
        for (uint256 i = 0; i < length; ) {
            splitTotal += splits[i];
            unchecked {
                ++i;
            }
        }

        uint256 newFees = calcFee(splitTotal);
        uint256 total = newFees + splitTotal;
        if (total > bounty.amount) {
            revert InvalidSplits();
        }

        bounties[bountyId].amount -= total;
        feesEarned[bounty.token] += newFees;

        IERC20 token = IERC20(bounty.token);
        for (uint256 i = 0; i < length; ) {
            token.transfer(recipients[i], splits[i]);
            unchecked {
                ++i;
            }
        }

        emit BountyPayments(bountyId, recipients, splitTotal);
    }

    /**
     * @notice top up bounty with more tokens
     * @param bountyId bounty to top up
     * @param amount amount of tokens to add
     */
    function topUp(uint256 bountyId, uint256 amount) external {
        Bounty memory bounty = bounties[bountyId];
        if (_msgSender() != bounty.sponsor) {
            revert NotArbiter();
        }

        uint256 total = amount + calcFee(amount);
        bounties[bountyId].amount += total;
        IERC20(bounty.token).transferFrom(_msgSender(), address(this), total);
    }

    /**
     * @notice can be called by owner or bounty creator to close bounty and refund
     * @param bountyId id of bounty to refund
     */
    function close(uint256 bountyId) external {
        if (_msgSender() != bounties[bountyId].sponsor) {
            revert NotArbiter();
        }
        address sponsor = bounties[bountyId].sponsor;
        uint256 amount = bounties[bountyId].amount;
        address token = bounties[bountyId].token;
        delete bounties[bountyId];
        IERC20(token).transfer(sponsor, amount);

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
        uint256 length = _tokens.length;
        for (uint256 i = 0; i < length; ) {
            uint256 contractBal = feesEarned[_tokens[i]];
            feesEarned[_tokens[i]] = 0;
            IERC20(_tokens[i]).transfer(owner(), contractBal);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice add list of depositors to allowlist
    function addDepositors(address[] calldata _allowedDepositors)
        external
        onlyOwner
    {
        uint256 length = _allowedDepositors.length;
        for (uint8 i = 0; i < length; ) {
            allowedDepositors[_allowedDepositors[i]] = true;
            unchecked {
                ++i;
            }
        }

        emit DepositorsAdded(_allowedDepositors);
    }

    /// @notice remove list of depositors from allowlist
    function removeDepositors(address[] calldata _allowedDepositors)
        external
        onlyOwner
    {
        uint256 length = _allowedDepositors.length;
        for (uint8 i = 0; i < length; ) {
            allowedDepositors[_allowedDepositors[i]] = false;
            unchecked {
                ++i;
            }
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