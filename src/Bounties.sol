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
import "openzeppelin/utils/cryptography/ECDSA.sol";

import "madfi-protocol/interfaces/IMadSBT.sol";

import "lens/interfaces/ILensProtocol.sol";

import "./extensions/Constants.sol";
import "./interfaces/IRewardNft.sol";
import {RevShare} from "madfi-protocol/libraries/RevShare.sol";

contract Bounties is Ownable, Constants {
    using ECDSA for bytes32;

    uint256 public protocolFee; // basis points
    mapping(address => uint256) public feesEarned;

    uint256 internal count;
    mapping(uint256 => Bounty) public bounties;

    struct Bounty {
        uint256 amount;
        uint256 collectionId;
        address sponsor;
        address token;
    }

    struct RankedSettleInput {
        uint256 bid;
        address recipient;
        uint256 revShare;
        bytes signature;
        Types.PostParams postParams;
        Types.MirrorParams mirrorParams;
        FollowParams followParams;
    }

    struct NftSettleInput {
        uint256 nonce;
        address recipient;
        bytes signature;
        Types.PostParams postParams;
        Types.MirrorParams mirrorParams;
        FollowParams followParams;
    }

    struct BidFromAction {
        uint256 bid;
        address recipient;
        uint256 revShare;
    }

    struct RankedSettleFromActionInput {
        uint256 bountyId;
        uint256 bidTotal;
        BidFromAction[] data;
        Types.PostParams[] postParams;
        uint24 fee;
    }

    struct FollowParams {
        bytes[] datas;
        uint256[] followTokenIds;
        uint256 followerProfileId;
        uint256[] idsOfProfilesToFollow;
    }

    IRewardNft public rewardNft;
    address public publicationAction;

    mapping(uint256 => mapping(address => uint256)) public nftSettleNonces; // bountyId => recipient => nonces

    address swapRouter;

    ILensProtocol internal lensHub;

    bytes32 private domainSeparator;

    /* MADSBT POINTS */
    IMadSBT madSBT;
    uint256 collectionId;
    uint256 profileId;

    /* EVENTS */
    event BountyCreated(uint256 indexed bountyId, Bounty bounty);
    event BountyNfts(uint256 indexed bountyId, uint256 nftsMinted);
    event BountyPayments(uint256 indexed bountyId, uint256 amount);
    event TopUp(uint256 indexed bountyId, uint256 amount);
    event BountyClosed(uint256 indexed bountyId);
    event SetProtocolFee(uint256 protocolFee);
    event WithdrawFees(address[] _tokens);
    event SetMadSBT(address _madSBT, uint256 _collectionId, uint256 _profileId);
    event SetRewardNft(address _rewardNft);
    event SetRevShare(address _revShare);
    event SetPublicationAction(address _publicationAction);

    /* ERRORS */
    error NotArbiter(address sender);
    error InvalidBidAmount(uint256 amount);
    error InvalidBidTotal(uint256 amount);
    error NFTBounty(uint256 bountyId);
    error InvalidSignature(address bidder);
    error OnlyPublicationAction();

    modifier onlyPublicationAction() {
        if (_msgSender() != publicationAction) revert OnlyPublicationAction();
        _;
    }

    /* CONSTRUCTOR */
    constructor(address _lensHub, uint256 _protocolFee, uint256 _startId, address _swapRouter) Ownable() {
        protocolFee = _protocolFee;
        count = _startId;
        swapRouter = _swapRouter;
        lensHub = ILensProtocol(_lensHub);

        domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH, keccak256("MadFi Bounties"), keccak256("1"), block.chainid, address(this)
            )
        );
    }

    /* PUBLIC FUNCTIONS */

    /**
     * @notice desposits tokens creating an open bounty
     * @param token token to deposit
     * @param amount amount of token to deposit
     */
    function deposit(address token, uint256 amount) external returns (uint256 bountyId) {
        uint256 total = amount + calcFee(amount);
        Bounty memory newBounty = Bounty(total, 0, _msgSender(), token);
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
     */
    function depositFromAction(address account, address token, uint256 totalAmount)
        external
        onlyPublicationAction
        returns (uint256 bountyId)
    {
        Bounty memory newBounty = Bounty(totalAmount, 0, account, token);
        bounties[++count] = newBounty;

        IERC20(token).transferFrom(_msgSender(), address(this), totalAmount);

        madSBT.handleRewardsUpdate(account, collectionId, BOUNTY_CREATE_REWARD_ENUM);

        emit BountyCreated(count, newBounty);
        return count;
    }

    /**
     * @notice create a new bounty with an NFT
     * @param _uri uri to create collection with
     */
    function depositNft(string calldata _uri) external returns (uint256 bountyId) {
        uint256 nftCollectionId = rewardNft.createCollection(_uri);
        Bounty memory newBounty = Bounty(0, nftCollectionId, _msgSender(), address(0));
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
    function rankedSettle(uint256 bountyId, RankedSettleInput[] calldata input, uint24 fee) external {
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
     * @param input RankedSettleInput struct containing all inputs
     */
    function rankedSettleFromAction(RankedSettleFromActionInput calldata input) external onlyPublicationAction {
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
    function nftSettle(uint256 bountyId, NftSettleInput[] calldata input) external {
        Bounty memory bounty = bounties[bountyId];
        if (bounty.collectionId == 0) {
            revert NFTBounty(bountyId);
        }
        _verifySignatures(bountyId, input);
        for (uint256 i = 0; i < input.length;) {
            rewardNft.mint(input[i].recipient, bounty.collectionId, 1, "");
            _doLens(input[i].postParams, input[i].mirrorParams, input[i].followParams);
            nftSettleNonces[bountyId][input[i].recipient]++;
            unchecked {
                ++i;
            }
        }

        emit BountyNfts(bountyId, input.length);
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

    /* ADMIN FUNCTIONS */

    /// @notice sets the protocol fee (in basis points). Close all outstanding bounties before calling
    function setProtocolFee(uint256 _protocolFee) external onlyOwner {
        protocolFee = _protocolFee;
        emit SetProtocolFee(_protocolFee);
    }

    /// @notice withdraws all accumulated fees
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
     * @notice sets the PublicationBountyAction contract
     * @param _publicationAction the address of the PublicationBountyAction contract
     */
    function setPublicationActionModule(address _publicationAction) external onlyOwner {
        publicationAction = _publicationAction;
        emit SetPublicationAction(_publicationAction);
    }

    /* INTERNAL FUNCTIONS */

    /**
     * @notice This is an internal function that verifies the signatures of the recipients
     * @param bountyId The ID of the bounty
     * @param data The array of BidFromAction structs
     */
    function _verifySignatures(uint256 bountyId, RankedSettleInput[] calldata data) internal view {
        for (uint256 i = 0; i < data.length;) {
            bytes32 messageHash = hashRankedSettleInput(bountyId, data[i]);
            bytes32 typedDataHash = toTypedDataHash(messageHash);

            // Verify the signature
            if (data[i].recipient != ECDSA.recover(typedDataHash, data[i].signature)) {
                revert InvalidSignature(data[i].recipient);
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice This is an internal function that verifies the signatures of the recipients
     * @param bountyId The ID of the bounty
     * @param data The array of BidFromAction structs
     */
    function _verifySignatures(uint256 bountyId, NftSettleInput[] calldata data) internal view {
        for (uint256 i = 0; i < data.length;) {
            bytes32 messageHash = hashNftSettleInput(bountyId, data[i]);
            bytes32 typedDataHash = toTypedDataHash(messageHash);

            // Verify the signature
            if (data[i].recipient != ECDSA.recover(typedDataHash, data[i].signature)) {
                revert InvalidSignature(data[i].recipient);
            }
            unchecked {
                ++i;
            }
        }
    }

    function toTypedDataHash(bytes32 messageHash) private view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, messageHash));
    }

    function hashRankedSettleInput(uint256 bountyId, RankedSettleInput memory input) private pure returns (bytes32) {
        bytes32 postParamsHash = keccak256(
            abi.encode(
                POST_PARAMS_TYPEHASH,
                input.postParams.profileId,
                input.postParams.contentURI,
                input.postParams.actionModules,
                input.postParams.actionModulesInitDatas,
                input.postParams.referenceModule,
                input.postParams.referenceModuleInitData
            )
        );

        bytes32 mirrorParamsHash = keccak256(
            abi.encode(
                MIRROR_PARAMS_TYPEHASH,
                input.mirrorParams.profileId,
                input.mirrorParams.metadataURI,
                input.mirrorParams.pointedProfileId,
                input.mirrorParams.pointedPubId,
                input.mirrorParams.referrerProfileIds,
                input.mirrorParams.referrerPubIds,
                input.mirrorParams.referenceModuleData
            )
        );

        bytes32 followParamsHash = keccak256(
            abi.encode(
                FOLLOW_PARAMS_TYPEHASH,
                input.followParams.datas,
                input.followParams.followTokenIds,
                input.followParams.followerProfileId,
                input.followParams.idsOfProfilesToFollow
            )
        );

        return keccak256(
            abi.encode(
                RANKED_SETTLE_INPUT_TYPEHASH,
                bountyId,
                input.bid,
                input.recipient,
                input.revShare,
                postParamsHash,
                mirrorParamsHash,
                followParamsHash
            )
        );
    }

    function hashNftSettleInput(uint256 bountyId, NftSettleInput memory input) private pure returns (bytes32) {
        bytes32 postParamsHash = keccak256(
            abi.encode(
                POST_PARAMS_TYPEHASH,
                input.postParams.profileId,
                input.postParams.contentURI,
                input.postParams.actionModules,
                input.postParams.actionModulesInitDatas,
                input.postParams.referenceModule,
                input.postParams.referenceModuleInitData
            )
        );

        bytes32 mirrorParamsHash = keccak256(
            abi.encode(
                MIRROR_PARAMS_TYPEHASH,
                input.mirrorParams.profileId,
                input.mirrorParams.metadataURI,
                input.mirrorParams.pointedProfileId,
                input.mirrorParams.pointedPubId,
                input.mirrorParams.referrerProfileIds,
                input.mirrorParams.referrerPubIds,
                input.mirrorParams.referenceModuleData
            )
        );

        bytes32 followParamsHash = keccak256(
            abi.encode(
                FOLLOW_PARAMS_TYPEHASH,
                input.followParams.datas,
                input.followParams.followTokenIds,
                input.followParams.followerProfileId,
                input.followParams.idsOfProfilesToFollow
            )
        );

        return keccak256(
            abi.encode(
                NFT_SETTLE_INPUT_TYPEHASH,
                bountyId,
                input.nonce,
                input.recipient,
                postParamsHash,
                mirrorParamsHash,
                followParamsHash
            )
        );
    }

    /**
     * @dev disperse funds to recipients
     * @param bountyId bounty to settle
     * @param data array of data with recipients, amounts, and rev share
     * @param fee uniswap v3 fee in case of rev share swap
     */
    function _rankedSettle(uint256 bountyId, RankedSettleInput[] calldata data, uint24 fee) internal {
        Bounty memory bounty = bounties[bountyId];
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

        uint256 newFees = calcFee(bidTotal);
        uint256 total = newFees + bidTotal;
        if (total > bounty.amount) {
            revert InvalidBidTotal(total);
        }

        bounties[bountyId].amount -= total;
        feesEarned[bounty.token] += newFees;

        IERC20 token = IERC20(bounty.token);
        i = 0;
        while (i < data.length) {
            _bidPayment(token, data[i].recipient, data[i].bid, data[i].revShare, fee);
            madSBT.handleRewardsUpdate(data[i].recipient, collectionId, BID_ACCEPT_REWARD_ENUM);

            unchecked {
                ++i;
            }
        }

        emit BountyPayments(bountyId, bidTotal);
    }

    /**
     * @dev disperse funds to recipients
     * @param bountyId bounty to settle
     * @param bidTotal total amount to disburse
     * @param data array of data with recipients, amounts, and rev share
     * @param fee uniswap v3 fee in case of rev share swap
     */
    function _rankedSettleFromAction(uint256 bountyId, uint256 bidTotal, BidFromAction[] calldata data, uint24 fee)
        internal
    {
        Bounty memory bounty = bounties[bountyId];

        uint256 newFees = calcFee(bidTotal);
        uint256 total = newFees + bidTotal;
        if (total > bounty.amount) {
            revert InvalidBidTotal(total);
        }

        bounties[bountyId].amount -= total;
        feesEarned[bounty.token] += newFees;

        IERC20 token = IERC20(bounty.token);
        uint256 sponsorCollectionId = madSBT.activeCollection(bounty.sponsor);
        for (uint256 i = 0; i < data.length;) {
            _bidPayment(token, data[i].recipient, data[i].bid, data[i].revShare, fee);

            // MADFI BADGE POINTS
            madSBT.handleRewardsUpdate(data[i].recipient, collectionId, BID_ACCEPT_REWARD_ENUM);
            // SPONSOR BADGE POINTS
            if (sponsorCollectionId != 0) {
                madSBT.handleRewardsUpdate(data[i].recipient, sponsorCollectionId, BID_ACCEPT_REWARD_ENUM);
            }

            unchecked {
                i++;
            }
        }

        emit BountyPayments(bountyId, bidTotal);
    }

    /**
     * @dev disburses funds to a recipient, if they have a rev share setup it will be paid out
     * @param token token to disperse
     * @param recipient address to disperse to
     * @param bid amount to disperse
     * @param revShare percentage of bid to pay to rev share
     * @param fee uniswap v3 fee in case of rev share swap
     */
    function _bidPayment(IERC20 token, address recipient, uint256 bid, uint256 revShare, uint24 fee) internal {
        uint256 revShareAmount;
        if (revShare > 0) {
            uint256 _collectionId = madSBT.activeCollection(recipient);
            if (_collectionId != 0) {
                // if user has a collection
                unchecked {
                    revShareAmount = revShare * bid / 100_00;
                }
                RevShare.distribute(madSBT, revShareAmount, _collectionId, address(token), swapRouter, fee);
            }
        }
        token.transfer(recipient, bid - revShareAmount);
    }

    function _doLens(Types.PostParams calldata post, Types.MirrorParams calldata mirror, FollowParams calldata follow)
        internal
    {
        lensHub.post(post);
        if (mirror.profileId != 0) {
            try lensHub.mirror(mirror) returns (uint256) {} catch {}
        }
        if (follow.followerProfileId != 0) {
            try lensHub.follow(
                follow.followerProfileId, follow.idsOfProfilesToFollow, follow.followTokenIds, follow.datas
            ) returns (uint256[] memory) {} catch {}
        }
    }

    /// @notice fallback function to prevent accidental ether transfers
    receive() external payable {
        revert();
    }
}
