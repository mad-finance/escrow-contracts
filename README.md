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

- rankedSettle: settles the bounty by splitting between all recipients and posts to Lens. There are different versions for posting, mirroring, commenting, following and collecting.

- refund: Returns escrowed tokens for a bounty to sponsor. Can only be called by contract owner.

- setProtocolFee: sets the protocol fee (in basis points). Can only be called by contract owner.

- withdrawFees: withdraws all accumulated fees

- addDepositors: Adds addresses that are allowed to create bounties

- removeDepositors: Removes addresses that are allowed to create bounties

- openTheGates: remove allowlist requirement for depositors

## PermissionedMintNft

An nft contract with unlimited supply that requires a signature from the contract owner to mint a token.

## Scripts

```bash
source .env

# deploy escrow contract
forge script script/Deploy.s.sol:DeployScript --rpc-url polygon --broadcast --verify -vvvv

# deploy escrow contract v2
forge script script/DeployV2.s.sol:DeployScript --rpc-url polygon --broadcast --verify -vvvv

# withdraw fees
forge script script/WithdrawFees.s.sol:WithdrawFeesScript --rpc-url polygon --broadcast -vvvv

# add despoitor
forge script script/AddDepositors.s.sol:AddDepositorsScript --rpc-url polygon --broadcast -vvvv

#when verification fails
forge verify-contract --chain-id 137 --num-of-optimizations 20000 --watch --constructor-args $(cast abi-encode "constructor(address,uint256,uint256)" "0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d" 1000 4) --compiler-version v0.8.10+commit.fc410830 <contract_address> src/EscrowV2.sol:EscrowV2 <etherscan_key>
```
