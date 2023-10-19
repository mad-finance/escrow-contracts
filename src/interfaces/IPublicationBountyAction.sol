// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IPublicationBountyAction {
    struct Bid {
        uint256 profileId;
        uint256 bidAmount;
        string contentURI;
        address referrer; // transactionExecutor
    }

    struct ActiveBounty {
        uint256 id;
        uint256 bidCount;
    }

    function activeBounties(uint256 profileId, uint256 pubId) external returns (ActiveBounty memory);

    function activeBids(uint256 bountyId) external returns (Bid memory);
}
