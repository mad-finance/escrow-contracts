// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/EscrowV3.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // TODO: be sure to set correct network address
        address lensHubPolygon = 0xDb46d1Dc155634FbC732f92E853b10B288AD5a1d;
        address lensHubMumbai = 0x60Ae865ee4C725cd04353b5AAb364553f56ceF82;

        uint256 protocolFee = 10_00;

        // TODO: be sure to set correct last bounty id
        uint256 lastBountyId = 8;

        EscrowV3 e = new EscrowV3(lensHubPolygon, protocolFee, lastBountyId);

        // TODO: fill these in
        address _madSBT = address(0);
        uint256 _collectionId = 1;
        uint256 _profileId = 1;
        e.setMadSBT(_madSBT, _collectionId, _profileId);

        vm.stopBroadcast();
    }
}
