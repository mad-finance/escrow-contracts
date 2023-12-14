// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {RewardNft} from "../src/RewardNft.sol";

contract CreateSticker is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        RewardNft rewardNft = RewardNft(0xC7924C6Be44c9f663b181989c263b6A15434b3e8);

        string memory tokenUri = "ipfs://bafkreiduigb4zpsumwhxd3hgslwkr4jgqa2cznzpmycxezyfm4ooasudfq";
        address creator = 0x63756D38260C6E4f391E75435377493930a8C370;
        address recipient = 0xB00B28559ae01D962dc72B6AaeDA7395cf8A4ecA;

        uint256 id = rewardNft.createCollection(tokenUri, creator);

        rewardNft.mint(creator, id, 1, "");
        rewardNft.mint(recipient, id, 1, "");

        vm.stopBroadcast();
    }
}
