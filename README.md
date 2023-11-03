# Briefs/Bounties Smart Contracts

Smart contracts for escrowing funds for bounties and issuing funds/rewards.

## Usage

1. [install Foundry](https://book.getfoundry.sh/getting-started/installation.html)
2. `forge update` to download dependencies
3. `forge build` to compile contracts
4. `forge test` to run tests

## Bounties

Manages Bounties.

Functions:

- deposit: Specify amount and address of token and time period of bounty. Transfers tokens into escrow contract. Returns a id for the bounty.

- depositNft: Specify token uri and create a bounty with an nft as reward instead of cash

- rankedSettle: settles the bounty by splitting between all recipients and posts to Lens. There are different versions for posting, mirroring, commenting, following and collecting.

- nftSettle: settle an nft bounty

- topUp: add funds to a bounty

- close: close bounty and return remaining funds

Admin Functions

- setProtocolFee: sets the protocol fee (in basis points). Can only be called by contract owner.

- withdrawFees: withdraws all accumulated fees

- setMadSbt: sets the MadSBT contract, collection ID and profile ID

- setRewardNft: sets the RewardNft contract

## RewardNft

An erc1155 contract that can be used for free bounties where winners are just minted an nft in a collection for that bounty.

## PermissionedMintNft

An nft contract with unlimited supply that requires a signature from the contract owner to mint a token.

## Scripts

```bash
source .env

# deploy bounties contract
forge script script/DeployBounties.s.sol:DeployBounties --rpc-url mumbai --broadcast --verify -vvvv

# withdraw fees
forge script script/WithdrawFees.s.sol:WithdrawFees --rpc-url mumbai --broadcast -vvvv
```

## Deployment

1. Be sure to set correct last bounty id for your chain id
2. In ILensProtocol change the Types import to `import {Types} from '../../contracts/libraries/constants/Types.sol';` before deploying because otherwise polygonscan verification messes up.
3. Run the deploy script
4. Set contract as verified on MadSBT contract so rewards can be distributed

## Bounties in depth

`rankedSettle` is the default way to pay out from a bounty.

```
    struct RankedSettleInput {
        uint256 bountyId;
        address[] recipients;
        uint256[] bids;
        uint256[] revShares;
        bytes[] paymentSignatures;
        Types.PostParams[] postParams;
        Types.EIP712Signature[] signatures;
        uint24 fee;
    }
```

- bountyId: the id of the bounty
- recipients: the addresses of the recipients
- bids: the amount of the bounty token to be paid to each recipient
- revShares: the percent of the recipient's split to be distributed through their MaadSBT badge. If they don't have this param will do nothing
- paymentSignatures: signatures from the recipients to prove that the correct bid amounts and rev share splits are being included
- postParams: the params for the post to be made to Lens
- signatures: signatures from the recipients to verify the lens posts are correct
- fee: if they include a rev share and the bounty token is not the same as the underlying asset for their mad sbt badge reward super token it will need to be swapped. this fee is the fee for the uniswap pool to swap through. It will be 500, 3000 or 10000 (0.05%, .3% or 1%)

## Deployments

### Mumbai

RevShare: 0x72FB6E048484B44178d9274b2Ab5668c5719E1d7

Bounties: 0x26d6ecD1dFF1cE392e609747c21D92AFde9Fd24C

RewardNft: 0x3D381B1501cf67D06164C60d75fa2B5b42D1F971
