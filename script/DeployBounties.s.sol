// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/Bounties.sol";
import {RewardNft} from "../src/RewardNft.sol";

contract DeployBounties is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address lensHub = block.chainid == 137
            ? 0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d // polygon
            : 0x4fbffF20302F3326B20052ab9C217C44F6480900; // mumbai

        uint256 protocolFee = 10_00;

        // TODO: be sure to set correct last bounty id before each run
        uint256 lastBountyId = block.chainid == 137 ? 46 : 129;

        address swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

        address socialClubReferrals = block.chainid == 137
            ? 0x712bAa2E7b005d6c27902e427De9E329D6CfA4Be // polygon
            : 0x7f1fB3DcCB8bED821e639DcEBCCb69AeE1Bb7797; // mumbai

        Bounties bounties = new Bounties(lensHub, protocolFee, lastBountyId, swapRouter, socialClubReferrals);

        address _madSBT = block.chainid == 137
            ? 0x22209D6eAe6cEBA2d059ebfE67b67837BCC1b428 // TODO: polygon
            : 0x37aB71116E2A89dA7d27c918aBE6B9Bb8bEE5d12; // TODO: mumbai
        uint256 _collectionId = 1;
        uint256 _profileId = block.chainid == 137 ? 8640 : 209;
        bounties.setMadSBT(_madSBT, _collectionId, _profileId); // TODO: optional

        bounties.setReferralHandler(socialClubReferrals);

        RewardNft rewardNft = new RewardNft(address(bounties));

        bounties.setRewardNft(address(rewardNft));

        vm.stopBroadcast();
    }
}
