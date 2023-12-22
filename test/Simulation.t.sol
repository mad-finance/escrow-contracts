// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import {IMadSBT} from "madfi-protocol/interfaces/IMadSBT.sol";
import {ISuperToken} from "madfi-protocol/interfaces/ISuperToken.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

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

interface ISuperfluid {
    function callAgreement(
         address agreementClass,
         bytes calldata callData,
         bytes calldata userData
     ) external returns(bytes memory returnedData);
}

interface IIDAV1 {
    function approveSubscription(
        address token,
        address publisher,
        uint32 indexId,
        bytes calldata ctx
    ) external returns(bytes memory newCtx);
}

contract SimulationTest is TestHelper, SimulationHelper {
    uint256 deployerPrivateKey; // madfi wallet
    address deployer = 0x7F0408bc8Dfe90C09072D8ccF3a1C544737BcDB6;
    uint256 madfiProfileId = 209; // test/madfinance
    uint256 genesisCollectionId = 1;
    uint256 devPrivateKey; // to approve units

    IMadSBTExtended madSBT;
    address constant latestMadSBT = 0x16d4EF45Ce129b6D7bE32E341984682b3050e7cb;
    address constant sfHost = 0xEB796bdb90fFA0f28255275e16936D25d3418603;
    address constant idaV1 = 0x804348D4960a61f2d5F9ce9103027A3E849E09b8;

    uint256 public constant GENESIS_BADGE_SUPPLY_CAP = 1_000;
    string constant GENESIS_BADGE_URI = "";

    bytes public basicCollectionCalldata;

    function setUp() public {
        polygonFork = vm.createFork(vm.envString("MUMBAI_RPC_URL"));
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        devPrivateKey = vm.envUint("DEV_PRIVATE_KEY");
        vm.selectFork(polygonFork);

        madSBT = IMadSBTExtended(latestMadSBT);
        initializeAddresses(); // 42 addresses get 500 points each
        initializeAddressesExtra(); // 18 addresses to get 500 more points

        // TODO: bounty contract

        setDelegatedExecutors(address(bounties));

        // with no referrer
        basicCollectionCalldata = abi.encode(GENESIS_BADGE_SUPPLY_CAP, GENESIS_BADGE_URI, address(0));
    }

    function testWithAirdroppedCollection() public {
        vm.startBroadcast(deployerPrivateKey);
        // 1. get badges distributed
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

        vm.stopBroadcast();

        uint256 expectedTotalRewardUnits = 30_000;
        assertEq(madSBT.totalRewardUnits(genesisCollectionId), expectedTotalRewardUnits, "someone didn't get their POINTS");

        // TODO:
        // 3. create a bounty
        // 4. settle a bounty payout with revshare
    }

    function testWithMultipleCollections() public {
        vm.startBroadcast(deployerPrivateKey);
        madSBT.createAirdropCollection(madfiProfileId, GENESIS_BADGE_SUPPLY_CAP, GENESIS_BADGE_URI, genesisBadgeAddresses, genesisRewardPoints);
        madSBT.batchRewardsUpdate(genesisBadgeExtraPointsAddresses, genesisCollectionId, GENESIS_REWARD_POINTS_EXTRA_ENUM);
        madSBT.batchRewardsUpdate(genesisBadgeExtraPointsAddresses, genesisCollectionId, GENESIS_REWARD_POINTS_EXTRA_ENUM);
        vm.stopBroadcast();

        uint256 expectedTotalRewardUnits = 30_000;
        assertEq(madSBT.totalRewardUnits(genesisCollectionId), expectedTotalRewardUnits, "someone didn't get their POINTS");

        // someone makes their own badge; mints it for another person; gives them 250 points
        vm.startPrank(bidderAddress);
        uint256 otherCollectionId = madSBT.createCollection(bidderAddress, bidderProfileId, basicCollectionCalldata);
        madSBT.mint(bidderAddress2, otherCollectionId);
        madSBT.handleRewardsUpdate(bidderAddress2, otherCollectionId, 0);
        uint256 expectedRewards = 350; // 100 for minting, 250 for extra
        assertEq(madSBT.totalRewardUnits(otherCollectionId), expectedRewards);
        vm.stopPrank();

        // we do a usdc distribtution of 100 fusdcx to genesis badge holders
        IERC20 superToken = IERC20(address(madSBT.rewardsToken()));
        uint256 amountToDistribute = 100 ether;

        // they must approve the IDA subscription before auto-receiving their rewards
        vm.startBroadcast(devPrivateKey);
        ISuperfluid(sfHost).callAgreement(
            idaV1,
            abi.encodeCall(
                IIDAV1.approveSubscription,
                (
                    address(superToken),
                    address(madSBT),
                    uint32(genesisCollectionId),
                    new bytes(0) // ctx placeholder
                )
            ),
            new bytes(0)
        );
        vm.stopBroadcast();

        address userWithExtraPoints = 0x28ff8e457feF9870B9d1529FE68Fbb95C3181f64; // or address of `devPrivateKey`
        uint256 usdcxBalanceExtraBefore = superToken.balanceOf(userWithExtraPoints);

        vm.startBroadcast(deployerPrivateKey);
        superToken.approve(address(madSBT), amountToDistribute);
        madSBT.distributeRewards(genesisCollectionId, amountToDistribute);
        vm.stopBroadcast();

        uint256 usdcxBalanceExtra = superToken.balanceOf(userWithExtraPoints);
        uint256 usdcxDelta = usdcxBalanceExtra - usdcxBalanceExtraBefore;

        uint256 rewardUnits = madSBT.rewardUnitsOf(userWithExtraPoints, genesisCollectionId);
        assertEq(rewardUnits, 1000);

        // rewardUnits / totalRewardUnits => 1000 / 30000
        assertEq(usdcxDelta, 3333333333333333000, "did not get new fusdcx....");
    }
}
