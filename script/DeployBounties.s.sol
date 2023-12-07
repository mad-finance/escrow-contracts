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

        address referralHandler = block.chainid == 137
            ? 0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d // TODO: polygon
            : 0x90B57ad79672DC8461E59709eB954D256934095d; // TODO: mumbai

        Bounties bounties = new Bounties(lensHub, protocolFee, lastBountyId, swapRouter, referralHandler);

        address _madSBT = block.chainid == 137
            ? 0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d // TODO: polygon?
            : 0x31A1bb7c375e457523441d064961c1ddED687dC6; // mumbai
        uint256 _collectionId = 1;
        uint256 _profileId = block.chainid == 137 ? 8640 : 349;
        bounties.setMadSBT(_madSBT, _collectionId, _profileId);

        RewardNft rewardNft = new RewardNft(address(bounties));

        bounties.setRewardNft(address(rewardNft));

        vm.stopBroadcast();
    }
}
