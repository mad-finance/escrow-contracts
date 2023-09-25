// SPDX-License-Identifier: MIT

/*

__/\\\\____________/\\\\_____/\\\\\\\\\_____/\\\\\\\\\\\\_____/\\\\\\\\\\\\\\\__/\\\\\\\\\\\_        
 _\/\\\\\\________/\\\\\\___/\\\\\\\\\\\\\__\/\\\////////\\\__\/\\\///////////__\/////\\\///__       
  _\/\\\//\\\____/\\\//\\\__/\\\/////////\\\_\/\\\______\//\\\_\/\\\_________________\/\\\_____      
   _\/\\\\///\\\/\\\/_\/\\\_\/\\\_______\/\\\_\/\\\_______\/\\\_\/\\\\\\\\\\\_________\/\\\_____     
    _\/\\\__\///\\\/___\/\\\_\/\\\\\\\\\\\\\\\_\/\\\_______\/\\\_\/\\\///////__________\/\\\_____    
     _\/\\\____\///_____\/\\\_\/\\\/////////\\\_\/\\\_______\/\\\_\/\\\_________________\/\\\_____   
      _\/\\\_____________\/\\\_\/\\\_______\/\\\_\/\\\_______/\\\__\/\\\_________________\/\\\_____  
       _\/\\\_____________\/\\\_\/\\\_______\/\\\_\/\\\\\\\\\\\\/___\/\\\______________/\\\\\\\\\\\_ 
        _\///______________\///__\///________\///__\////////////_____\///______________\///////////__
                                        
*/

pragma solidity ^0.8.10;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";
import "madfi-protocol/interfaces/IMadSBT.sol";
import "./extensions/LensExtension.sol";

contract Escrow is Ownable, LensExtension {
    uint256 public protocolFee; // basis points
    mapping(address => uint256) public feesEarned;

    uint256 internal count;
    mapping(uint256 => Bounty) public bounties;

    struct Bounty {
        uint256 amount;
        address sponsor;
        address token;
    }

    // MADSBT POINTS
    IMadSBT madSBT;
    uint256 collectionId;
    uint256 profileId;

    // EVENTS
    event BountyCreated(uint256 bountyId, Bounty bounty);
    event BountyPayments(uint256 bountyId, address[] recipients, uint256 amount);
    event BountyClosed(uint256 bountyId);
    event SetProtocolFee(uint256 protocolFee);

    // ERRORS
    error NotArbiter(address sender);
    error InvalidBidAmount(uint256 amount);
    error InvalidSplits(uint256 amount);

    // CONSTRUCTOR
    constructor(address _lensHub, uint256 _protocolFee, uint256 _startId) Ownable() LensExtension(_lensHub) {
        protocolFee = _protocolFee;
        count = _startId;
    }

    // PUBLIC FUNCTIONS

    /**
     * @notice desposits tokens creating an open bounty
     * @param token token to deposit
     * @param amount amount of token to deposit
     */
    function deposit(address token, uint256 amount) external returns (uint256 bountyId) {
        uint256 total = amount + calcFee(amount);
        Bounty memory newBounty = Bounty(total, _msgSender(), token);
        bounties[++count] = newBounty;

        IERC20(token).transferFrom(_msgSender(), address(this), total);

        madSBT.handleRewardsUpdate(_msgSender(), collectionId, profileId, IMadSBT.Action.CREATE_BOUNTY);

        emit BountyCreated(count, newBounty);
        return count;
    }

    /**
     * @notice disperse funds to recipients and posts to Lens
     * @param bountyId bounty to settle
     * @param recipients list of addresses to disperse to
     * @param splits list of split amounts to go to each recipient
     * @param postParams PostParams to post to Lens on recipients behalf
     * @param signatures EIP712 signatures for postParams
     */
    function rankedSettle(
        uint256 bountyId,
        address[] calldata recipients,
        uint256[] calldata splits,
        Types.PostParams[] calldata postParams,
        Types.EIP712Signature[] calldata signatures
    ) external {
        _rankedSettle(bountyId, recipients, splits);
        postWithSigBatch(postParams, signatures);
    }

    /**
     * @notice top up bounty with more tokens
     * @param bountyId bounty to top up
     * @param amount amount of tokens to add
     */
    function topUp(uint256 bountyId, uint256 amount) external {
        Bounty memory bounty = bounties[bountyId];
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
            revert NotArbiter(_msgSender());
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
        for (uint256 i = 0; i < length;) {
            uint256 contractBal = feesEarned[_tokens[i]];
            feesEarned[_tokens[i]] = 0;
            IERC20(_tokens[i]).transfer(owner(), contractBal);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice sets the MadSBT contract, collection ID and profile ID
     * @param _madSBT the address of the MadSBT contract
     * @param _collectionId the ID of the collection
     * @param _profileId the ID of the profile
     */
    function setMadSBT(address _madSBT, uint256 _collectionId, uint256 _profileId) external onlyOwner {
        madSBT = IMadSBT(_madSBT);
        collectionId = _collectionId;
        profileId = _profileId;
    }

    // INTERNAL FUNCTIONS

    /**
     * @dev disperse funds to recipeints
     * @param bountyId bounty to settle
     * @param recipients list of addresses to disperse to
     * @param splits list of split amounts to go to each recipient
     */
    function _rankedSettle(uint256 bountyId, address[] calldata recipients, uint256[] calldata splits) internal {
        Bounty memory bounty = bounties[bountyId];
        if (_msgSender() != bounty.sponsor) {
            revert NotArbiter(_msgSender());
        }

        uint256 splitTotal;
        uint256 length = recipients.length;
        for (uint256 i = 0; i < length;) {
            splitTotal += splits[i];
            unchecked {
                ++i;
            }
        }

        uint256 newFees = calcFee(splitTotal);
        uint256 total = newFees + splitTotal;
        if (total > bounty.amount) {
            revert InvalidSplits(total);
        }

        bounties[bountyId].amount -= total;
        feesEarned[bounty.token] += newFees;

        IERC20 token = IERC20(bounty.token);
        for (uint256 i = 0; i < length;) {
            token.transfer(recipients[i], splits[i]);

            madSBT.handleRewardsUpdate(recipients[i], collectionId, profileId, IMadSBT.Action.ACCEPTED_BID);

            unchecked {
                ++i;
            }
        }

        emit BountyPayments(bountyId, recipients, splitTotal);
    }

    /// @notice fallback function to prevent accidental ether transfers
    receive() external payable {
        revert();
    }
}
