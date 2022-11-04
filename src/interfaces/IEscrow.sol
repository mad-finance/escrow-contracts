// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IEscrow {
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

    // BOUNTIES
    /**
        @dev deposit funds and create a new bounty
     */
    function deposit(
        address token,
        uint256 amount
    ) external returns (uint256 bountyId);

    /**
        @dev end a bounty, specify and payout the winners
            can specify multiple winners but they all receive 
            an equal split
     */
    function settle(uint256 bountyId, address[] calldata recipients) external;

    /**
        @dev end a bounty, specify and payout the winners by rank
        @param recipients list of recipients to receive payout
        @param splits list of split out of 100000 for corresponding
        entry in the recipient list to receive, has to add up to 100000
     */
    function rankedSettle(
        uint256 bountyId,
        address[] calldata recipients,
        uint256[] calldata splits
    ) external;

    /**
        @dev end a bounty and return escrowed funds to the sponsor
     */
    function refund(uint256 bountyId) external;

    // ADMIN
    /**
        @dev specify a list of tokens that can be used in bounties
     */
    function addAllowListTokens(address[] calldata _allowedTokens) external;

    /**
        @dev specify a list of tokens that can no longer be used in bounties
     */
    function removeAllowListTokens(address[] calldata _allowedTokens) external;

    /**
        @dev specify a list of depositors that can create bounties
     */
    function addDepositors(address[] calldata _allowedDepositors) external;

    /**
        @dev specify a list of depositors that can no longer create bounties
     */
    function removeDepositors(address[] calldata _allowedDepositors) external;

    // ERRORS
    error EarlySettlement();
    error NotArbiter();
    error TokenNotAllowed();
    error DepositorNotAllowed();
    error InvalidSplits();
}
