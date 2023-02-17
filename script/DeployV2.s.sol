// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/EscrowV2.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // TODO: be sure to set correct network address
        address lensHubPolygon = 0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d;
        address lensHubMumbai = 0x60Ae865ee4C725cd04353b5AAb364553f56ceF82;
        uint256 protocolFee = 10_00;
        uint lastBountyId = 4;
        EscrowV2 e = new EscrowV2(lensHubPolygon, protocolFee, lastBountyId);

        // remove for mainnet
        e.openTheGates();

        // address[] memory _allowedDepositors = new address[](5);
        // _allowedDepositors[0] = 0xd37D17A6FD45ff4BBE6eA6FcA519dB0Dd8296b2E; // lucas
        // _allowedDepositors[1] = 0xDC4471ee9DFcA619Ac5465FdE7CF2634253a9dc6; // me
        // _allowedDepositors[2] = 0x28ff8e457feF9870B9d1529FE68Fbb95C3181f64; // carlos
        // _allowedDepositors[3] = 0x7F0408bc8Dfe90C09072D8ccF3a1C544737BcDB6; // madfi
        // _allowedDepositors[4] = 0xB00B28559ae01D962dc72B6AaeDA7395cf8A4ecA; // deployer

        // e.addDepositors(_allowedDepositors);

        vm.stopBroadcast();
    }
}
