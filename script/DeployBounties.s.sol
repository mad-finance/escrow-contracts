// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/Bounties.sol";
import "../src/RewardNft.sol";

contract DeployBounties is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address lensHub = block.chainid == 137
            ? 0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d // polygon
            : 0xC1E77eE73403B8a7478884915aA599932A677870; // mumbai

        uint256 protocolFee = 10_00;

        // TODO: be sure to set correct last bounty id
        uint256 lastBountyId = 108;

        address swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

        Bounties bounties = new Bounties(lensHub, protocolFee, lastBountyId, swapRouter);

        // TODO: fill these in
        address _madSBT = address(0);
        uint256 _collectionId = 1;
        uint256 _profileId = 1;
        bounties.setMadSBT(_madSBT, _collectionId, _profileId);

        RewardNft rewardNft = new RewardNft(address(bounties));

        bounties.setRewardNft(address(rewardNft));

        vm.stopBroadcast();
    }
}