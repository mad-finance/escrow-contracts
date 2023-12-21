// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import { IMadSBT } from "madfi-protocol/interfaces/IMadSBT.sol";

import "./helpers/TestHelper.sol";
import "./helpers/SimulationHelper.sol";

// admin functions not exposed
interface IMadSBTExtended is IMadSBT {
    function createAirdropCollection(
        uint256 _creatorProfileId,
        uint256 _availableSupply,
        string memory _uri,
        address[] memory accounts,
        uint128[] memory rewardUnits
    ) external;
}

contract SimulationTest is TestHelper, SimulationHelper {
    uint256 deployerPrivateKey; // madfi wallet
    uint256 madfiProfileId = 209; // test/madfinance
    uint256 genesisCollectionId = 1;

    IMadSBTExtended madSBT;
    address latestMadSBT = 0x3417c5087e344D8F9CE7E69160e1028E99FFA9f6;

    uint256 public constant GENESIS_BADGE_SUPPLY_CAP = 1_000;
    string constant GENESIS_BADGE_URI = "";

    function setUp() public {
        polygonFork = vm.createFork(vm.envString("MUMBAI_RPC_URL"));
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.selectFork(polygonFork);

        madSBT = IMadSBTExtended(latestMadSBT);
        initializeAddresses(); // 42 addresses get 500 points each
        initializeAddressesExtra(); // 18 addresses to get 500 more points

        // TODO: bounty contract

        setDelegatedExecutors(address(bounties));
    }

    function testWithAirdroppedCollection() public {
        // 1. get badges distributed
        vm.startBroadcast(deployerPrivateKey);
        madSBT.createAirdropCollection(
            madfiProfileId,
            GENESIS_BADGE_SUPPLY_CAP,
            GENESIS_BADGE_URI,
            genesisBadgeAddresses,
            genesisRewardPoints
        );

        // 2. get points airdropped - some ppl get more points; give em 500 more points
        madSBT.batchRewardsUpdate(genesisBadgeExtraPointsAddresses, genesisCollectionId, GENESIS_REWARD_POINTS_EXTRA_ENUM);
        madSBT.batchRewardsUpdate(genesisBadgeExtraPointsAddresses, genesisCollectionId, GENESIS_REWARD_POINTS_EXTRA_ENUM);

        uint256 expectedTotalRewardUnits = 30_000;
        assertEq(madSBT.totalRewardUnits(genesisCollectionId), expectedTotalRewardUnits, "someone didn't get their POINTS");

        // TODO:
        // 3. create a bounty
        // 4. settle a bounty payout with revshare
    }
}
