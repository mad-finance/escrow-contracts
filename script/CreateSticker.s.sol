// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import {RewardNft} from "../src/RewardNft.sol";

contract CreateSticker is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address stickerAddress = block.chainid == 137
            ? 0xC45dC3262A024d8962F74237fc7E990aa3Fbb407
            : 0x86d25a4C55F27679c7109E6FEc24c6D85ad28AC6;

        RewardNft rewardNft = RewardNft(stickerAddress);

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
