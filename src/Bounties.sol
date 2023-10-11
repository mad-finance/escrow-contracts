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
import "./interfaces/IRewardNft.sol";
import "./interfaces/IRevShare.sol";

contract Bounties is Ownable, LensExtension {
    uint256 public protocolFee; // basis points
    mapping(address => uint256) public feesEarned;

    uint256 internal count;
    mapping(uint256 => Bounty) public bounties;

    struct Bounty {
        uint256 amount;
        address sponsor;
        address token;
        uint256 collectionId;
    }

    IRewardNft public rewardNft;

    IRevShare public revShare;

    // MADSBT POINTS
    IMadSBT madSBT;
    uint256 collectionId;
    uint256 profileId;

    // EVENTS
    event BountyCreated(uint256 indexed bountyId, Bounty bounty);
    event BountyNfts(uint256 indexed bountyId, uint256 nftsMinted);
    event BountyPayments(uint256 indexed bountyId, address[] recipients, uint256 amount);
    event TopUp(uint256 indexed bountyId, uint256 amount);
    event BountyClosed(uint256 indexed bountyId);
    event SetProtocolFee(uint256 protocolFee);
    event WithdrawFees(address[] _tokens);
    event SetMadSBT(address _madSBT, uint256 _collectionId, uint256 _profileId);
    event SetRewardNft(address _rewardNft);
    event SetRevShare(address _revShare);

    // ERRORS
    error NotArbiter(address sender);
    error InvalidBidAmount(uint256 amount);
    error InvalidSplits(uint256 amount);
    error NFTBounty(uint256 bountyId);

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
        Bounty memory newBounty = Bounty(total, _msgSender(), token, 0);
        bounties[++count] = newBounty;

        IERC20(token).transferFrom(_msgSender(), address(this), total);

        madSBT.handleRewardsUpdate(_msgSender(), collectionId, 3);

        emit BountyCreated(count, newBounty);
        return count;
    }

    /**
     * @notice create a new bounty with an NFT
     * @param _uri uri to create collection with
     */
    function depositNft(string calldata _uri) external returns (uint256 bountyId) {
        uint256 nftCollectionId = rewardNft.createCollection(_uri);
        Bounty memory newBounty = Bounty(0, _msgSender(), address(0), nftCollectionId);
        bounties[++count] = newBounty;

        madSBT.handleRewardsUpdate(_msgSender(), collectionId, 3);

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
     * @notice mints nft to recipients and posts to Lens
     * @param bountyId bounty to settle
     * @param recipients list of addresses to mint to
     * @param postParams PostParams to post to Lens on recipients behalf
     * @param signatures EIP712 signatures for postParams
     */
    function nftSettle(
        uint256 bountyId,
        address[] calldata recipients,
        Types.PostParams[] calldata postParams,
        Types.EIP712Signature[] calldata signatures
    ) external {
        Bounty memory bounty = bounties[bountyId];
        if (bounty.collectionId == 0) {
            revert NFTBounty(bountyId);
        }
        uint256 length = recipients.length;
        for (uint256 i = 0; i < length;) {
            rewardNft.mint(recipients[i], bounty.collectionId, 1, "");
            unchecked {
                ++i;
            }
        }
        postWithSigBatch(postParams, signatures);
        emit BountyNfts(bountyId, length);
    }

    /**
     * @notice top up bounty with more tokens
     * @param bountyId bounty to top up
     * @param amount amount of tokens to add
     */
    function topUp(uint256 bountyId, uint256 amount) external {
        Bounty memory bounty = bounties[bountyId];
        if (bounty.collectionId != 0) {
            revert NFTBounty(bountyId);
        }
        uint256 total = amount + calcFee(amount);
        bounties[bountyId].amount += total;
        IERC20(bounty.token).transferFrom(_msgSender(), address(this), total);
        emit TopUp(bountyId, amount);
    }

    /**
     * @notice can be called by owner or bounty creator to close bounty and refund
     * @param bountyId id of bounty to refund
     */
    function close(uint256 bountyId) external {
        if (_msgSender() != bounties[bountyId].sponsor) {
            revert NotArbiter(_msgSender());
        }

        Bounty memory bounty = bounties[bountyId];
        if (bounty.collectionId == 0) {
            IERC20(bounty.token).transfer(bounty.sponsor, bounty.amount);
        }
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
        uint256 length = _tokens.length;
        for (uint256 i = 0; i < length;) {
            uint256 contractBal = feesEarned[_tokens[i]];
            feesEarned[_tokens[i]] = 0;
            IERC20(_tokens[i]).transfer(owner(), contractBal);
            unchecked {
                ++i;
            }
        }
        emit WithdrawFees(_tokens);
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
        emit SetMadSBT(_madSBT, _collectionId, _profileId);
    }

    /**
     * @notice sets the RewardNft contract
     * @param _rewardNft the address of the RewardNft contract
     */
    function setRewardNft(address _rewardNft) external onlyOwner {
        rewardNft = IRewardNft(_rewardNft);
        emit SetRewardNft(_rewardNft);
    }

    /**
     * @notice sets the RevShare contract
     * @param _revShare the address of the RevShare contract
     */
    function setRevShare(address _revShare) external onlyOwner {
        revShare = IRevShare(_revShare);
        emit SetRevShare(_revShare);
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
        if (bounty.collectionId != 0) {
            revert NFTBounty(bountyId);
        }
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
            _bidPayment(recipients[i], token, splits[i]);
            madSBT.handleRewardsUpdate(recipients[i], collectionId, 4);

            unchecked {
                ++i;
            }
        }

        emit BountyPayments(bountyId, recipients, splitTotal);
    }

    /**
     * @dev disburses funds to a recipient, if they have a rev share setup it will be paid out
     * @param recipient address to disperse to
     * @param token token to disperse
     * @param amount amount of token to disperse
     */
    function _bidPayment(address recipient, IERC20 token, uint256 amount) internal {
        uint256 revShareSplitAmount;
        if (address(revShare) != address(0)) {
            (uint256 collectionId_, uint256 split) = revShare.getCreatorData(recipient);
            if (collectionId_ != 0) {
                unchecked {
                    revShareSplitAmount = split * amount / 10_000;
                }
                revShare.deposit(collectionId_, revShareSplitAmount, address(token));
            }
        }
        token.transfer(recipient, amount - revShareSplitAmount);
    }

    /// @notice fallback function to prevent accidental ether transfers
    receive() external payable {
        revert();
    }
}