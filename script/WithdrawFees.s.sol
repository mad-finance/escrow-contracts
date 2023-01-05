// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/Escrow.sol";

contract WithdrawFeesScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address escrowAddress = 0xE99924ee90c832445AdA389554416C2DaCBaEa78; // MUMBAI TESTNET
        address[] memory tokens = new address[](1);
        tokens[0] = 0x11AE455A85DeB9c34E14db1662E269080b408544; // MUMBAI TEST TOKEN

        Escrow escrow = Escrow(payable(escrowAddress));
        escrow.withdrawFees(tokens);

        vm.stopBroadcast();
    }
}
