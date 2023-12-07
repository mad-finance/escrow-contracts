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
        uint256 lastBountyId = block.chainid == 137 ? 44 : 128;

        address swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

        address socialClubReferrals = block.chainid == 137
            ? 0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d // TODO: polygon
            : 0x7C64D7d2E3028fd76aCBf875DaC4ADA83B90b84F; // TODO: mumbai

        Bounties bounties = new Bounties(lensHub, protocolFee, lastBountyId, swapRouter, socialClubReferrals);

        address _madSBT = block.chainid == 137
            ? 0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d // TODO: polygon?
            : 0x0c437264f4a7799a3E70D4DD58B05511bf5F29a6; // mumbai
        uint256 _collectionId = 1;
        uint256 _profileId = block.chainid == 137 ? 8640 : 209;
        bounties.setMadSBT(_madSBT, _collectionId, _profileId);

        RewardNft rewardNft = new RewardNft(address(bounties));

        bounties.setRewardNft(address(rewardNft));

        vm.stopBroadcast();
    }
}
