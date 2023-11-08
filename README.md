# MadFi Bounties Smart Contracts

Smart contracts for escrowing funds for bounties and issuing funds/rewards.

## Usage

1. [install Foundry](https://book.getfoundry.sh/getting-started/installation.html)
2. `forge update` to download dependencies
3. `forge build` to compile contracts
4. `forge test` to run tests

## Bounties

Manages Bounties.

Functions:

- deposit: Specify amount and address of token. Transfers tokens into contract. Returns a id for the bounty.

- depositNft: Specify token uri and create a bounty with an nft as reward instead of cash

- rankedSettle: settles the bounty by distributing funds to each recipient that has a verified signature. Then posts to Lens and mirrors and/or follows if specified.

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

# test create nft bounty
forge script script/CreateNFTBounty.s.sol:CreateNFTBounty --rpc-url mumbai -vvvv
```

## Deployment

1. Be sure to set correct last bounty id for your chain id
2. In ILensProtocol change the Types import to `import {Types} from '../../contracts/libraries/constants/Types.sol';` before deploying because otherwise polygonscan verification messes up.
3. Run the deploy script
4. Set contract as verified on MadSBT contract so rewards can be distributed

## Bounties in depth

`rankedSettle` is the default way to pay out from a bounty.

```
function rankedSettle(uint256 bountyId, RankedSettleInput[] calldata input, uint24 fee) external

struct RankedSettleInput {
    uint256 bid;
    address recipient;
    uint256 revShare;
    bytes signature;
    Types.PostParams postParams;
    Types.MirrorParams mirrorParams;
    FollowParams followParams;
}
```

`input` struct

- bid: the amount of the bounty token to be the recipient
- recipient: the address of the recipients
- revShare: the percent of the recipient's split to be distributed through their MaadSBT badge. If they don't have this param will do nothing
- signature: signature of the entire struct (except signature) signed by the recipient
- postParams: the params for the post to be made to Lens
- mirrorParams: the params for the mirror to be made to Lens (if any)
- followParams: the params for the follow to be made to Lens (if any)

Other Params

- bountyId: the id of the bounty
- fee: if they include a rev share and the bounty token is not the same as the underlying asset for their mad sbt badge reward super token it will need to be swapped. this fee is the fee for the uniswap pool to swap through. It will be 500, 3000 or 10000 (0.05%, .3% or 1%)

## Deployments

### Mumbai

RevShare: 0x908FbA53600ddFC25A5BB04781d1CBeeCf8C77bc

Bounties: 0x62ABd2780954f2451dcb4DB9d7E599FB527f104B

RewardNft: 0x6394C9E90d583a660AE76E6E02398467e4eF3ecc

### Polygon

RevShare:

Bounties:

RewardNft:
