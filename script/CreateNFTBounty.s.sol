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
            ? 0x385B33C3127d5AF5F74fB4193a8dFd86D9a4A166
            : 0x807fF05A7B20a247178ba241A2e6676592de0cCB;

        Bounties bounties = Bounties(payable(bountiesAddress));
        bounties.depositNft("ipfs://bafkreibzte5iaclr7k6qwut5acq6gouhwcvctfjvxan7zyfwg7ffgz6dce");

        vm.stopBroadcast();
    }
}
