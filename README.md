# Briefs/Bounties Smart Contracts

Smart contracts for escrowing funds for bounties and issuing funds/rewards.

## Usage

1. [install Foundry](https://book.getfoundry.sh/getting-started/installation.html)
2. `forge update` to download dependencies
3. `forge build` to compile contracts
4. `forge test` to run tests

## Escrow

Escrows funds for bounties.

Functions:

- deposit: Specify amount and address of token and time period of bounty. Transfers tokens into escrow contract. Returns a id for the bounty.

- settle: Specifies winners of bounty and distributes funds and posts to Lens

- rankedSettle: settles the bounty by splitting between all recipients and posts to Lens

- refund: Returns escrowed tokens for a bounty to sponsor. Can only be called by contract owner.

- setProtocolFee: sets the protocol fee (in basis points). Can only be called by contract owner.

- withdrawFees: withdraws all accumulated fees

- addDepositors: Adds addresses that are allowed to create bounties

- removeDepositors: Removes addresses that are allowed to create bounties

- openTheGates: remove allowlist requirement for depositors

## PermissionedMintNft

An nft contract with unlimited supply that requires a signature from the contract owner to mint a token.
