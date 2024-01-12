// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/Bounties.sol";

contract WithdrawFees is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address bountiesAddress = block.chainid == 137
            ? 0x606E8572e79852Cb0766fd95907FeE7b974e41Be // Polygon
            : 0xa363AB8e2b4e09AF678Ded095011AbB0A801947b; // Mumbai

        address[] memory tokens = new address[](1);
        tokens[0] = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; // USDC

        Bounties bounties = Bounties(bountiesAddress);
        bounties.withdrawFees(tokens);

        vm.stopBroadcast();
    }
}
