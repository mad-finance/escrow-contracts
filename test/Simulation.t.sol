// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "./helpers/TestHelper.sol";

contract SimulationTest is TestHelper {
    function setUp() public {
        polygonFork = vm.createFork(vm.envString("MUMBAI_RPC_URL"));
        vm.selectFork(polygonFork);

        // TODO: set up contracts

        setDelegatedExecutors(address(bounties));
    }

    function testOne() public {
        // TODO:
        // 1. get badges distributed
        // 2. get points airdropped
        // 3. create a bounty
        // 4. settle a bounty payout with revshare
    }
}
