// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {ILensProtocol, Types} from "lens/interfaces/ILensProtocol.sol";

/**
 * @dev This library contains structs used in the Bounties contract
 */
library Structs {
    struct Bounty {
        uint256 amount;
        uint256 collectionId;
        address sponsor;
        uint256 sponsorCollectionId;
        address token;
    }

    struct RankedSettleInput {
        uint256 bid;
        uint256 bidderCollectionId;
        address recipient;
        uint256 revShare;
        bytes signature;
        Types.PostParams postParams;
        Types.MirrorParams mirrorParams;
        FollowParams followParams;
    }

    struct RankedSettleInputQuote {
        uint256 bid;
        uint256 bidderCollectionId;
        address recipient;
        uint256 revShare;
        bytes signature;
        Types.QuoteParams quoteParams;
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

    struct NftSettleInputQuote {
        uint256 nonce;
        address recipient;
        bytes signature;
        Types.QuoteParams quoteParams;
        Types.MirrorParams mirrorParams;
        FollowParams followParams;
    }

    struct BidFromAction {
        address recipient;
        address transactionExecutor; // can be address(0) for pay only settlements
        uint256 bid;
        uint256 bidderCollectionId;
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
}
