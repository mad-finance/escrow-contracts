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
import {RevShare} from "madfi-protocol/libraries/RevShare.sol";

import "./libraries/VerifySignatures.sol";
import "./interfaces/IRewardNft.sol";
import "./interfaces/ISocialClubReferrals.sol";

/**
 * @dev This contract handles the creation and settlement of bounties
 */
contract Bounties is Ownable, VerifySignatures {
    uint256 public protocolFee; // bps
    uint256 public referralFee; // bps, what clients earn from the protocol fee amount
    mapping(address => uint256) public feesEarned;
    mapping(address => mapping(address => uint256)) public transactionExecutorFeesEarned; // transactionExecutor => token => amount

    uint256 public count;
    mapping(uint256 => Structs.Bounty) public bounties;

    mapping(uint256 => mapping(address => uint256)) public nftSettleNonces; // bountyId => recipient => nonces

    // third-party clients that wish to earn referral fees must be whitelisted
    mapping(address => bool) public whitelistedTransactionExecutors; // transactionExecutor => isWhitelisted

    IRewardNft private rewardNft;
    address private publicationAction;
    ISocialClubReferrals private referralHandler;

    address private swapRouter;
    ILensProtocol private lensHub;

    /* MADSBT POINTS */
    IMadSBT private madSBT;
    uint256 private collectionId;
    uint256 private profileId;

    /* EVENTS */
    event BountyCreated(uint256 indexed bountyId, Structs.Bounty bounty);
    event BountyNfts(uint256 indexed bountyId, uint256 nftsMinted);
    event BountyPayments(uint256 indexed bountyId, uint256 amount);
    event TopUp(uint256 indexed bountyId, uint256 amount);
    event BountyClosed(uint256 indexed bountyId);
    event SetProtocolFee(uint256 protocolFee);
    event WithdrawFees(address[] _tokens);
    event WithdrawClientReferrals(address[] _tokens);
    event SetMadSBT(address _madSBT, uint256 _collectionId, uint256 _profileId);
    event SetRewardNft(address _rewardNft);
    event SetPublicationAction(address _publicationAction);
    event SetWhitelistedTransactionExecutor(address transactionExecutor, bool isWhitelisted);
    event SetReferralHandler(address referralHandler);
    event SetReferralFee(uint256 referralFee);

    /* ERRORS */
    error NotArbiter(address sender);
    error InvalidBidAmount(uint256 amount);
    error InvalidBidTotal(uint256 amount);
    error NFTBounty(uint256 bountyId);
    error OnlyPublicationAction();

    modifier onlyPublicationAction() {
        if (_msgSender() != publicationAction) revert OnlyPublicationAction();
        _;
    }

    /* CONSTRUCTOR */
    constructor(address _lensHub, uint256 _protocolFee, uint256 _startId, address _swapRouter, address _referralHandler)
        Ownable()
    {
        lensHub = ILensProtocol(_lensHub);
        setProtocolFee(_protocolFee);
        count = _startId;
        swapRouter = _swapRouter;
        setReferralHandler(_referralHandler);
    }

    /* PUBLIC FUNCTIONS */

    /**
     * @notice desposits tokens creating an open bounty
     * @param token token to deposit
     * @param amount amount of token to deposit
     * @param sponsorCollectionId collection ID of the sponsor
     */
    function deposit(address token, uint256 amount, uint256 sponsorCollectionId) external returns (uint256 bountyId) {
        uint256 total = amount + calcFee(amount);
        Structs.Bounty memory newBounty = Structs.Bounty(total, 0, _msgSender(), sponsorCollectionId, token);
        bounties[++count] = newBounty;

        IERC20(token).transferFrom(_msgSender(), address(this), total);

        madSBT.handleRewardsUpdate(_msgSender(), collectionId, BOUNTY_CREATE_REWARD_ENUM);

        emit BountyCreated(count, newBounty);
        return count;
    }

    /**
     * @notice Called from the Lens PublicationBountyAction module, on init
     * @param account the Lens profile owner creating the bounty
     * @param token token to deposit
     * @param totalAmount amount of tokens to deposit, including the fee
     * @param sponsorCollectionId collection ID of the sponsor
     */
    function depositFromAction(address account, address token, uint256 totalAmount, uint256 sponsorCollectionId)
        external
        onlyPublicationAction
        returns (uint256 bountyId)
    {
        Structs.Bounty memory newBounty = Structs.Bounty(totalAmount, 0, account, sponsorCollectionId, token);
        bounties[++count] = newBounty;

        IERC20(token).transferFrom(_msgSender(), address(this), totalAmount);

        madSBT.handleRewardsUpdate(account, collectionId, BOUNTY_CREATE_REWARD_ENUM);

        emit BountyCreated(count, newBounty);
        return count;
    }

    /**
     * @notice create a new bounty with an NFT
     * @param _uri uri to create collection with
     * @param sponsorCollectionId collection ID of the sponsor
     */
    function depositNft(string calldata _uri, uint256 sponsorCollectionId) external returns (uint256 bountyId) {
        uint256 nftCollectionId = rewardNft.createCollection(_uri);
        Structs.Bounty memory newBounty =
            Structs.Bounty(0, nftCollectionId, _msgSender(), sponsorCollectionId, address(0));
        bounties[++count] = newBounty;

        madSBT.handleRewardsUpdate(_msgSender(), collectionId, BOUNTY_CREATE_REWARD_ENUM);

        emit BountyCreated(count, newBounty);
        return count;
    }

    /**
     * @notice disperse funds to recipients and posts to Lens
     * @param bountyId bounty to settle
     * @param input RankedSettleInput struct containing all inputs
     * @param fee uniswap v3 fee in case of rev share swap
     */
    function rankedSettle(uint256 bountyId, Structs.RankedSettleInput[] calldata input, uint24 fee) external {
        _verifySignatures(bountyId, input);
        _rankedSettle(bountyId, input, fee);

        for (uint256 i = 0; i < input.length;) {
            _doLens(input[i].postParams, input[i].mirrorParams, input[i].followParams);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice disperse funds to recipients and posts to Lens
     * @param bountyId bounty to settle
     * @param input RankedSettleInputQuote struct containing all inputs
     * @param fee uniswap v3 fee in case of rev share swap
     */
    function rankedSettleQuote(uint256 bountyId, Structs.RankedSettleInputQuote[] calldata input, uint24 fee)
        external
    {
        _verifySignatures(bountyId, input);
        _rankedSettle(bountyId, input, fee);

        for (uint256 i = 0; i < input.length;) {
            _doLens(input[i].quoteParams, input[i].mirrorParams, input[i].followParams);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice disperse funds to recipients, no other onchain actions - for twitter posts
     * @param bountyId bounty to settle
     * @param bidData BidFromAction struct containing all inputs
     * @param signatures signatures of recipients
     * @param fee uniswap v3 fee in case of rev share swap
     */
    function rankedSettlePayOnly(
        uint256 bountyId,
        Structs.BidFromAction[] calldata bidData,
        bytes[] calldata signatures,
        uint24 fee
    ) external {
        _verifySignatures(bountyId, bidData, signatures);
        _rankedSettle(bountyId, bidData, fee);
    }

    /**
     * @notice disperse funds to recipients and posts to Lens
     * @param input RankedSettleInput struct containing all inputs
     */
    function rankedSettleFromAction(Structs.RankedSettleFromActionInput calldata input)
        external
        onlyPublicationAction
    {
        _rankedSettleFromAction(input.bountyId, input.bidTotal, input.data, input.fee);
        for (uint256 i = 0; i < input.postParams.length;) {
            lensHub.post(input.postParams[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice mints nft to recipients and posts to Lens
     * @param bountyId bounty to settle
     * @param input NftSettleInput struct containing all inputs
     */
    function nftSettle(uint256 bountyId, Structs.NftSettleInput[] calldata input) external {
        Structs.Bounty memory bounty = bounties[bountyId];
        if (bounty.collectionId == 0) {
            revert NFTBounty(bountyId);
        }
        if (_msgSender() != bounty.sponsor) {
            revert NotArbiter(_msgSender());
        }
        _verifySignatures(bountyId, input);
        uint256 sponsorCollectionId = bounty.sponsorCollectionId;
        for (uint256 i = 0; i < input.length;) {
            if (nftSettleNonces[bountyId][input[i].recipient] == input[i].nonce) {
                rewardNft.mint(input[i].recipient, bounty.collectionId, 1, "");
                _doLens(input[i].postParams, input[i].mirrorParams, input[i].followParams);
                nftSettleNonces[bountyId][input[i].recipient]++;
                awardBadgePoints(sponsorCollectionId, input[i].recipient);
            }
            unchecked {
                ++i;
            }
        }

        emit BountyNfts(bountyId, input.length);
    }

    /**
     * @notice mints nft to recipients and posts to Lens
     * @param bountyId bounty to settle
     * @param input NftSettleInputQuote struct containing all inputs
     */
    function nftSettleQuote(uint256 bountyId, Structs.NftSettleInputQuote[] calldata input) external {
        Structs.Bounty memory bounty = bounties[bountyId];
        if (bounty.collectionId == 0) {
            revert NFTBounty(bountyId);
        }
        if (_msgSender() != bounty.sponsor) {
            revert NotArbiter(_msgSender());
        }
        _verifySignatures(bountyId, input);
        uint256 sponsorCollectionId = bounty.sponsorCollectionId;
        for (uint256 i = 0; i < input.length;) {
            if (nftSettleNonces[bountyId][input[i].recipient] == input[i].nonce) {
                rewardNft.mint(input[i].recipient, bounty.collectionId, 1, "");
                _doLens(input[i].quoteParams, input[i].mirrorParams, input[i].followParams);
                nftSettleNonces[bountyId][input[i].recipient]++;
                awardBadgePoints(sponsorCollectionId, input[i].recipient);
            }
            unchecked {
                ++i;
            }
        }

        emit BountyNfts(bountyId, input.length);
    }

    /**
     * @notice mints nft to recipients
     * @param bountyId bounty to settle
     * @param recipients array of recipients
     */
    function nftSettlePayOnly(uint256 bountyId, address[] calldata recipients) external {
        Structs.Bounty memory bounty = bounties[bountyId];
        if (bounty.collectionId == 0) {
            revert NFTBounty(bountyId);
        }
        if (_msgSender() != bounty.sponsor) {
            revert NotArbiter(_msgSender());
        }
        uint256 sponsorCollectionId = bounty.sponsorCollectionId;
        for (uint256 i = 0; i < recipients.length;) {
            rewardNft.mint(recipients[i], bounty.collectionId, 1, "");
            awardBadgePoints(sponsorCollectionId, recipients[i]);
            unchecked {
                ++i;
            }
        }

        emit BountyNfts(bountyId, recipients.length);
    }

    /**
     * @notice top up bounty with more tokens
     * @param bountyId bounty to top up
     * @param amount amount of tokens to add
     */
    function topUp(uint256 bountyId, uint256 amount) external {
        Structs.Bounty memory bounty = bounties[bountyId];
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

        Structs.Bounty memory bounty = bounties[bountyId];
        if (bounty.collectionId == 0) {
            IERC20(bounty.token).transfer(bounty.sponsor, bounty.amount);
        }
        delete bounties[bountyId];

        emit BountyClosed(bountyId);
    }

    /// @notice withdraws all accumulated client referral fees denominated in the specified tokens to the sender
    function withdrawClientReferrals(address[] calldata _tokens) external {
        for (uint256 i = 0; i < _tokens.length;) {
            uint256 availableBal = transactionExecutorFeesEarned[_msgSender()][_tokens[i]];
            transactionExecutorFeesEarned[_msgSender()][_tokens[i]] = 0;
            IERC20(_tokens[i]).transfer(_msgSender(), availableBal);
            unchecked {
                ++i;
            }
        }
        emit WithdrawClientReferrals(_tokens);
    }

    /**
     * @notice calculates the fee to be paid on a token amount
     * @param amount token amount to calculate fee for
     */
    function calcFee(uint256 amount) public view returns (uint256) {
        return (amount * protocolFee) / 10_000;
    }

    /**
     * @notice calculates the fee to be paid for client referrals, from the protocol fee
     * @param amount token amount to calculate fee for
     */
    function calcReferralFee(uint256 amount) public view returns (uint256) {
        return (calcFee(amount) * referralFee) / 10_000;
    }

    /* ADMIN FUNCTIONS */

    /// @notice sets the protocol fee (in basis points). Close all outstanding bounties before calling
    function setProtocolFee(uint256 _protocolFee) public onlyOwner {
        protocolFee = _protocolFee;
        emit SetProtocolFee(_protocolFee);
    }

    /// @notice sets the transaction executor referral fee (bps) to be taken from the protocol fee, given to third-party
    /// clients that submit a winning bid from the open action
    function setReferralFee(uint256 _referralFee) external onlyOwner {
        referralFee = _referralFee;
        emit SetReferralFee(_referralFee);
    }

    /// @notice withdraws all accumulated fees denominated in the specified tokens to the owner
    function withdrawFees(address[] calldata _tokens) external onlyOwner {
        for (uint256 i = 0; i < _tokens.length;) {
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
     * @notice sets the SocialClubReferrals contract
     * @param _referralHandler the address of the SocialClubReferrals contract
     */
    function setReferralHandler(address _referralHandler) public onlyOwner {
        referralHandler = ISocialClubReferrals(_referralHandler);
        emit SetReferralHandler(_referralHandler);
    }

    /**
     * @notice sets the PublicationBountyAction contract
     * @param _publicationAction the address of the PublicationBountyAction contract
     */
    function setPublicationActionModule(address _publicationAction) external onlyOwner {
        publicationAction = _publicationAction;
        emit SetPublicationAction(_publicationAction);
    }

    /**
     * @notice sets a whitelisted third-party client
     * @param transactionExecutor the address of the client that submits the lens #act txs
     * @param whitelisted whether or not the client is whitelisted
     */
    function setWhitelistedTransactionExecutor(address transactionExecutor, bool whitelisted) external onlyOwner {
        whitelistedTransactionExecutors[transactionExecutor] = whitelisted;
        emit SetWhitelistedTransactionExecutor(transactionExecutor, whitelisted);
    }

    /* INTERNAL FUNCTIONS */

    /**
     * @dev disperse funds to recipients
     * @param bountyId bounty to settle
     * @param data array of data with recipients, amounts, and rev share
     * @param fee uniswap v3 fee in case of rev share swap
     */
    function _rankedSettle(uint256 bountyId, Structs.RankedSettleInput[] calldata data, uint24 fee) internal {
        Structs.Bounty memory bounty = bounties[bountyId];
        if (bounty.collectionId != 0) {
            revert NFTBounty(bountyId);
        }
        if (_msgSender() != bounty.sponsor) {
            revert NotArbiter(_msgSender());
        }

        uint256 bidTotal;
        uint256 i;
        while (i < data.length) {
            bidTotal += data[i].bid;
            unchecked {
                ++i;
            }
        }

        uint256 protocolFees = calcFee(bidTotal);
        uint256 total = protocolFees + bidTotal;
        if (total > bounty.amount) {
            revert InvalidBidTotal(total);
        }

        bounties[bountyId].amount -= total;

        IERC20 token = IERC20(bounty.token);
        i = 0;
        uint256 sponsorCollectionId = bounty.sponsorCollectionId;
        uint256 finalProtocolFees = protocolFees;
        while (i < data.length) {
            _bidPayment(token, data[i].recipient, data[i].bid, data[i].revShare, data[i].bidderCollectionId, fee);
            awardBadgePoints(sponsorCollectionId, data[i].recipient);
            finalProtocolFees -= _handleReferral(protocolFees, token, data[i].recipient, data[i].bid, bidTotal);

            unchecked {
                ++i;
            }
        }

        feesEarned[bounty.token] += finalProtocolFees;

        emit BountyPayments(bountyId, bidTotal);
    }

    /**
     * @dev disperse funds to recipients, handle creator referrals, and award points on the sponsor badge
     * @param bountyId bounty to settle
     * @param data array of data with recipients, amounts, and rev share
     * @param fee uniswap v3 fee in case of rev share swap
     */
    function _rankedSettle(uint256 bountyId, Structs.RankedSettleInputQuote[] calldata data, uint24 fee) internal {
        Structs.Bounty memory bounty = bounties[bountyId];
        if (bounty.collectionId != 0) {
            revert NFTBounty(bountyId);
        }
        if (_msgSender() != bounty.sponsor) {
            revert NotArbiter(_msgSender());
        }

        uint256 bidTotal;
        uint256 i;
        while (i < data.length) {
            bidTotal += data[i].bid;
            unchecked {
                ++i;
            }
        }

        uint256 protocolFees = calcFee(bidTotal);
        uint256 total = protocolFees + bidTotal;
        if (total > bounty.amount) {
            revert InvalidBidTotal(total);
        }

        bounties[bountyId].amount -= total;

        IERC20 token = IERC20(bounty.token);
        i = 0;
        uint256 sponsorCollectionId = bounty.sponsorCollectionId;
        uint256 finalProtocolFees = protocolFees;
        while (i < data.length) {
            _bidPayment(token, data[i].recipient, data[i].bid, data[i].revShare, data[i].bidderCollectionId, fee);
            finalProtocolFees -= _handleReferral(protocolFees, token, data[i].recipient, data[i].bid, bidTotal);
            awardBadgePoints(sponsorCollectionId, data[i].recipient);

            unchecked {
                ++i;
            }
        }

        feesEarned[bounty.token] += finalProtocolFees;

        emit BountyPayments(bountyId, bidTotal);
    }

    /**
     * @dev disperse funds to recipients, handle creator AND client referrals, and award points on the sponsor badge
     * @param bountyId bounty to settle
     * @param bidTotal total amount to disburse
     * @param data array of data with recipients, amounts, and rev share
     * @param fee uniswap v3 fee in case of rev share swap
     */
    function _rankedSettleFromAction(
        uint256 bountyId,
        uint256 bidTotal,
        Structs.BidFromAction[] calldata data,
        uint24 fee
    ) internal {
        Structs.Bounty memory bounty = bounties[bountyId];

        uint256 protocolFees = calcFee(bidTotal);
        uint256 total = protocolFees + bidTotal;
        if (total > bounty.amount) {
            revert InvalidBidTotal(total);
        }

        bounties[bountyId].amount -= total;

        IERC20 token = IERC20(bounty.token);
        uint256 sponsorCollectionId = bounty.sponsorCollectionId;
        uint256 finalProtocolFees = protocolFees;
        for (uint256 i = 0; i < data.length;) {
            _bidPayment(token, data[i].recipient, data[i].bid, data[i].revShare, data[i].bidderCollectionId, fee);
            finalProtocolFees -= _handleReferral(protocolFees, token, data[i].recipient, data[i].bid, bidTotal);
            finalProtocolFees -=
                _handleClientReferral(protocolFees, data[i].transactionExecutor, bounty.token, data[i].bid, bidTotal);
            awardBadgePoints(sponsorCollectionId, data[i].recipient);

            unchecked {
                i++;
            }
        }

        feesEarned[bounty.token] += finalProtocolFees;

        emit BountyPayments(bountyId, bidTotal);
    }

    /**
     * @dev disperse funds to recipients - for use with pay only ranked settle
     * @param bountyId bounty to settle
     * @param data array of data with recipients, amounts, and rev share
     * @param fee uniswap v3 fee in case of rev share swap
     */
    function _rankedSettle(uint256 bountyId, Structs.BidFromAction[] calldata data, uint24 fee) internal {
        Structs.Bounty memory bounty = bounties[bountyId];
        if (bounty.collectionId != 0) {
            revert NFTBounty(bountyId);
        }
        if (_msgSender() != bounty.sponsor) {
            revert NotArbiter(_msgSender());
        }

        uint256 bidTotal;
        uint256 i;
        while (i < data.length) {
            bidTotal += data[i].bid;
            unchecked {
                ++i;
            }
        }

        uint256 protocolFees = calcFee(bidTotal);
        uint256 total = protocolFees + bidTotal;
        if (total > bounty.amount) {
            revert InvalidBidTotal(total);
        }

        bounties[bountyId].amount -= total;

        IERC20 token = IERC20(bounty.token);
        i = 0;
        uint256 sponsorCollectionId = bounty.sponsorCollectionId;
        uint256 finalProtocolFees = protocolFees;
        while (i < data.length) {
            _bidPayment(token, data[i].recipient, data[i].bid, data[i].revShare, data[i].bidderCollectionId, fee);
            finalProtocolFees -= _handleReferral(protocolFees, token, data[i].recipient, data[i].bid, bidTotal);
            awardBadgePoints(sponsorCollectionId, data[i].recipient);

            unchecked {
                ++i;
            }
        }

        feesEarned[bounty.token] += finalProtocolFees;

        emit BountyPayments(bountyId, bidTotal);
    }

    /**
     * @dev disburses funds to a recipient, if they have a rev share setup it will be paid out
     * @param token token to disperse
     * @param recipient address to disperse to
     * @param bid amount to disperse
     * @param revShare percentage of bid to pay to rev share
     * @param bidderCollectionId collection ID of the bidder
     * @param fee uniswap v3 fee in case of rev share swap
     */
    function _bidPayment(
        IERC20 token,
        address recipient,
        uint256 bid,
        uint256 revShare,
        uint256 bidderCollectionId,
        uint24 fee
    ) internal {
        uint256 revShareAmount;
        if (revShare > 0 && bidderCollectionId != 0) {
            // if user has a collection
            unchecked {
                revShareAmount = revShare * bid / 100_00;
            }
            RevShare.distribute(madSBT, revShareAmount, bidderCollectionId, address(token), swapRouter, fee);
        }
        token.transfer(recipient, bid - revShareAmount);
    }

    /**
     * @dev This function awards badge points to a recipient.
     * @param sponsorCollectionId The ID of the sponsor's collection.
     * @param recipient The address of the recipient.
     */
    function awardBadgePoints(uint256 sponsorCollectionId, address recipient) internal {
        // MADFI BADGE POINTS
        madSBT.handleRewardsUpdate(recipient, collectionId, BID_ACCEPT_REWARD_ENUM);
        // SPONSOR BADGE POINTS
        if (sponsorCollectionId != 0) {
            madSBT.handleRewardsUpdate(recipient, sponsorCollectionId, BID_ACCEPT_REWARD_ENUM);
        }
    }

    /**
     * @dev Performs all lens actions for an address
     * @param post post params data
     * @param mirror mirror params data
     * @param follow follow params data
     */
    function _doLens(
        Types.PostParams calldata post,
        Types.MirrorParams calldata mirror,
        Structs.FollowParams calldata follow
    ) internal {
        lensHub.post(post);
        _doLens(mirror, follow);
    }

    /**
     * @dev Performs all lens actions for an address
     * @param quote quote params data
     * @param mirror mirror params data
     * @param follow follow params data
     */
    function _doLens(
        Types.QuoteParams calldata quote,
        Types.MirrorParams calldata mirror,
        Structs.FollowParams calldata follow
    ) internal {
        lensHub.quote(quote);
        _doLens(mirror, follow);
    }

    /**
     * @dev Performs mirror and follow lens actions for an address
     * @param mirror mirror params data
     * @param follow follow params data
     */
    function _doLens(Types.MirrorParams calldata mirror, Structs.FollowParams calldata follow) internal {
        if (mirror.profileId != 0) {
            try lensHub.mirror(mirror) returns (uint256) {} catch {}
        }
        if (follow.followerProfileId != 0) {
            try lensHub.follow(
                follow.followerProfileId, follow.idsOfProfilesToFollow, follow.followTokenIds, follow.datas
            ) returns (uint256[] memory) {} catch {}
        }
    }

    /**
     * @dev Handles creator referrals by calculating the referral amount, then distributing it to the referrer
     * @param protocolFeeAmount The total amount in protocol fees
     * @param token The bounty token
     * @param bidder The bidder address getting paid out
     * @param bidAmount The bidder amount
     * @param bidTotal The total bid amount for the bounty
     * @return uint256 The amount paid to the referrer
     */
    function _handleReferral(
        uint256 protocolFeeAmount,
        IERC20 token,
        address bidder,
        uint256 bidAmount,
        uint256 bidTotal
    ) internal returns (uint256) {
        uint256 protocolFeeShare = bidAmount * protocolFeeAmount / bidTotal;

        (address referrer, uint256 referralAmount) =
            referralHandler.processBountyWithBadgeCreator(bidder, protocolFeeShare, address(token));

        if (referralAmount > 0 && referrer != address(0)) {
            token.transfer(referrer, referralAmount);
        }

        return referralAmount;
    }

    /**
     * @dev Handles client referrals by calculating the referral amount and storing it for them to claim
     * @param protocolFeeAmount The total amount in protocol fees
     * @param targetExecutor The target executor of the lens #act that submitted the bid
     * @param bidAmount The bidder amount
     * @param bidTotal The total bid amount for the bounty
     * @return uint256 The amount paid to the referrer
     */
    function _handleClientReferral(
        uint256 protocolFeeAmount,
        address targetExecutor,
        address token,
        uint256 bidAmount,
        uint256 bidTotal
    ) internal returns (uint256) {
        if (referralFee == 0 || !whitelistedTransactionExecutors[targetExecutor]) return 0;

        uint256 protocolFeeShare = bidAmount * protocolFeeAmount / bidTotal;
        uint256 referralFeeShare = protocolFeeShare * referralFee / 10_000;

        transactionExecutorFeesEarned[targetExecutor][token] += referralFeeShare;

        return referralFeeShare;
    }
}
