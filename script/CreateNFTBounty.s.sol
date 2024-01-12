// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Bounties.sol";

contract CreateNFTBounty is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address bountiesAddress = block.chainid == 137
            ? 0x606E8572e79852Cb0766fd95907FeE7b974e41Be
            : 0xa363AB8e2b4e09AF678Ded095011AbB0A801947b;

        Bounties bounties = Bounties(bountiesAddress);
        bounties.depositNft("ipfs://bafkreibzte5iaclr7k6qwut5acq6gouhwcvctfjvxan7zyfwg7ffgz6dce", 0);

        vm.stopBroadcast();
    }
}
