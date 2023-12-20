// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {RewardNft} from "../src/RewardNft.sol";

contract CreateSticker is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        RewardNft rewardNft = RewardNft(0xC85DBF3eEa4b112288dbDCD43C9B8f4DEb1eFb12);

        string memory tokenUri = "ipfs://bafkreiduigb4zpsumwhxd3hgslwkr4jgqa2cznzpmycxezyfm4ooasudfq";
        address creator = 0x7F0408bc8Dfe90C09072D8ccF3a1C544737BcDB6;
        address recipient = 0xB00B28559ae01D962dc72B6AaeDA7395cf8A4ecA;

        uint256 id = rewardNft.createCollection(tokenUri, creator);

        rewardNft.mint(creator, id, 1, "");
        rewardNft.mint(recipient, id, 1, "");

        address[] memory recipients = new address[](2);
        recipients[0] = 0x7F0408bc8Dfe90C09072D8ccF3a1C544737BcDB6;
        recipients[1] = 0xB00B28559ae01D962dc72B6AaeDA7395cf8A4ecA;
        rewardNft.batchMint(recipients, id, "");

        vm.stopBroadcast();
    }
}
