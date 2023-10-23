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
            ? 0x385B33C3127d5AF5F74fB4193a8dFd86D9a4A166 // Polygon
            : 0x21D076fA57B2da9d8A703464e6E17A22bE2FbB90; // Mumbai

        address[] memory tokens = new address[](1);
        tokens[0] = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; // USDC

        Bounties bounties = Bounties(payable(bountiesAddress));
        bounties.withdrawFees(tokens);

        vm.stopBroadcast();
    }
}
