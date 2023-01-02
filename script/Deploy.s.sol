// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Escrow.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // TODO: be sure to set correct network address
        // address lensHubPolygon = 0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d;
        address lensHubMumbai = 0x60Ae865ee4C725cd04353b5AAb364553f56ceF82;
        uint256 protocolFee = 1000;
        Escrow e = new Escrow(lensHubMumbai, protocolFee);

        // remove for mainnet
        e.openTheGates();

        vm.stopBroadcast();
    }
}
