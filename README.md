# Briefs/Bounties Smart Contracts

Smart contracts for escrowing funds for bounties and issuing funds/rewards.

## Usage

1. [install Foundry](https://book.getfoundry.sh/getting-started/installation.html)
2. `forge update` to download dependencies
3. `forge build` to compile contracts
4. `forge test` to run tests

## Escrow

Escrows funds for bounties. Includes list of allowed tokens that can be used for rewards, updateable only by contract owner.

Functions:

- desposit: Specify amount and address of token and time period of bounty. Transfers tokens into escrow contract. Returns a id for the bounty.

- settle: Specifies winners of bounty and distributes funds.

- refund: Returns escrowed tokens for a bounty to sponsor. Can only be called by contract owner.

- addAllowListTokens: Adds new tokens that can be used for bounty rewards

- removeAllowListTokens: Removes tokens that can be used for bounty rewards

- addDepositors: Adds addresses that are allowed to create bounties

- removeDepositors: Removes addresses that are allowed to create bounties

## PermissionedMintNft

An nft contract with unlimited supply that requires a signature from the contract owner to mint a token. Can be used for issuing reward nfts for winners of bounties or for allowing users to mint nfts of their briefs.
