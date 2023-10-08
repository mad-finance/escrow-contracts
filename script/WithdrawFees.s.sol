// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/Bounties.sol";

contract WithdrawFees is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // address bountiesAddress = 0xE99924ee90c832445AdA389554416C2DaCBaEa78; // MUMBAI TESTNET
        // address[] memory tokens = new address[](1);
        // tokens[0] = 0x11AE455A85DeB9c34E14db1662E269080b408544; // MUMBAI TEST TOKEN

        address bountiesAddress = 0x385B33C3127d5AF5F74fB4193a8dFd86D9a4A166; // POLYGON
        address[] memory tokens = new address[](1);
        tokens[0] = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; // USDC

        Bounties bounties = Bounties(payable(bountiesAddress));
        bounties.withdrawFees(tokens);

        vm.stopBroadcast();
    }
}
