// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/Escrow.sol";

contract AddDepScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address escrowAddress = 0x385B33C3127d5AF5F74fB4193a8dFd86D9a4A166; // POLYGON
        address[] memory users = new address[](1);
        users[0] = 0x000000b104d4C918AcaC32AdA679606bc31ae9Bb; // FILL IN NEW ADDRESS HERE

        Escrow escrow = Escrow(payable(escrowAddress));
        escrow.addDepositors(users);

        vm.stopBroadcast();
    }
}
