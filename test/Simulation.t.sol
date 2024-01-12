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

    function setVerifiedAddress(address _minter, bool _verified) external;

    function owner() external returns(address);
}

interface ISubscriptionHandler {
    function creatorFees(
        address creator
    ) external view returns (int96 flowRate, int96 minSeconds, bool burnBadgeOnUnsubscribe );

    function activeSubscriptions(
        address sender,
        address receiver
    ) external view returns (uint256 id, uint256 tokenId, uint64 wormholeSequence, bool active);

    function setCreatorFee(address creator, int96 flowRate, int96 minSeconds, bool burnBadgeOnUnsubscribe) external;

    function protocolFeePct() view external returns (int96);
}

interface ISuperfluid {
    function callAgreement(
         address agreementClass,
         bytes calldata callData,
         bytes calldata userData
     ) external returns (bytes memory returnedData);

     function isAppJailed(address superApp) external view returns (bool);
}

interface IIDAV1 {
    function approveSubscription(
        address token,
        address publisher,
        uint32 indexId,
        bytes calldata ctx
    ) external returns(bytes memory newCtx);
}

interface ICFAV1 {
    function createFlow(
        address token,
        address receiver,
        int96 flowRate,
        bytes calldata ctx
    ) external returns(bytes memory newCtx);

    function updateFlow(
        address token,
        address receiver,
        int96 flowRate,
        bytes calldata ctx
    ) external returns(bytes memory newCtx);

    function deleteFlow(
        address token,
        address sender,
        address receiver,
        bytes calldata ctx
    ) external returns(bytes memory newCtx);

    function getFlow(
        address token,
        address sender,
        address receiver
    ) external view returns (uint256 timestamp, int96 flowRate, uint256 deposit, uint256 owedDeposit);
}

contract SimulationTest is TestHelper, SimulationHelper {
    uint256 deployerPrivateKey; // madfi wallet
    address deployer = 0x7F0408bc8Dfe90C09072D8ccF3a1C544737BcDB6;
    uint256 madfiProfileId = 209; // test/madfinance
    uint256 genesisCollectionId = 1;
    uint256 devPrivateKey; // to approve units
    uint256 SECONDS_ONE_MONTH = 2_592_000;
    uint256 SECONDS_ONE_DAY = 86_400;

    IMadSBTExtended madSBT;
    ISubscriptionHandler subscriptionHandler;
    address constant latestMadSBT = 0x37aB71116E2A89dA7d27c918aBE6B9Bb8bEE5d12;
    address constant latestSubscriptionHandler = 0x06e0A31095d611A6b075D358ae13c390759815E1;
    address constant sfHost = 0xEB796bdb90fFA0f28255275e16936D25d3418603;
    address constant idaV1 = 0x804348D4960a61f2d5F9ce9103027A3E849E09b8;
    address constant cfaV1 = 0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873;

    uint256 public constant GENESIS_BADGE_SUPPLY_CAP = 0; // no cap fr
    string constant GENESIS_BADGE_URI = "";

    bytes public basicCollectionCalldata;

    function setUp() public override {
        super.setUp();

        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        devPrivateKey = vm.envUint("DEV_PRIVATE_KEY");

        madSBT = IMadSBTExtended(latestMadSBT);
        subscriptionHandler = ISubscriptionHandler(latestSubscriptionHandler);
        initializeAddresses(); // 42 addresses get 500 points each
        initializeAddressesExtra(); // 18 addresses to get 500 more points

        // with no referrer
        basicCollectionCalldata = abi.encode(GENESIS_BADGE_SUPPLY_CAP, GENESIS_BADGE_URI, address(0));

        // setup bounties
        vm.prank(madSBT.owner());
        madSBT.setVerifiedAddress(address(bounties), true);
        vm.prank(bounties.owner());
        bounties.setMadSBT(address(madSBT), genesisCollectionId, 1);
    }

    function testWithAirdroppedCollection() public {
        // 0. add bidders to genesis badge drop
        initializeAddressesBidders();

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

        madSBT.mint(bidderAddress, genesisCollectionId);
        madSBT.mint(bidderAddress2, genesisCollectionId);

        vm.stopBroadcast();

        // FIXME: this number is wrong now - should be 51000? (51700 with 2 added addresses)
        uint256 expectedTotalRewardUnits = 51700;
        assertEq(madSBT.totalRewardUnits(genesisCollectionId), expectedTotalRewardUnits, "someone didn't get their POINTS");

        // 3. create a bounty
        vm.startBroadcast(deployerPrivateKey);
        uint bountyAmount = 100_000000; // 100 usdc
        helperMintApproveTokens(bountyAmount, deployer, usdc);
        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount, genesisCollectionId);

        uint256 rewardUnits1 = madSBT.rewardUnitsOf(bidderAddress, genesisCollectionId);
        uint256 rewardUnits2 = madSBT.rewardUnitsOf(bidderAddress2, genesisCollectionId);

        // 4. settle a bounty payout with no revshare
        Structs.RankedSettleInput[] memory input = createSettleDataTwoBidders(newBountyId, 0, 1);
        bounties.rankedSettle(newBountyId, input, uniswapFee);
        vm.stopBroadcast();

        // 5. check balances of bidders - receive bid amount
        assertEq(usdc.balanceOf(bidderAddress), bidAmount1);
        assertEq(usdc.balanceOf(bidderAddress2), bidAmount2);

        // 6. check points of bidders - receive genesis collection points
        assertEq(madSBT.rewardUnitsOf(bidderAddress, genesisCollectionId), rewardUnits1 + 100);
        assertEq(madSBT.rewardUnitsOf(bidderAddress2, genesisCollectionId), rewardUnits2 + 100);
    }

    function testWithRevShareSponsorPoints() public {
        address sponsor = 0x63756D38260C6E4f391E75435377493930a8C370;
        uint sponsorProfileId = 541;

        // 1. create badge on sponsor address
        vm.startBroadcast(deployerPrivateKey);
        address[] memory newBadgeAddresses = new address[](1);
        newBadgeAddresses[0] = bidderAddress;
        uint128[] memory newBadgePoints = new uint128[](1);
        newBadgePoints[0] = 1000;
        madSBT.createAirdropCollection(
            sponsorProfileId,
            GENESIS_BADGE_SUPPLY_CAP,
            GENESIS_BADGE_URI,
            newBadgeAddresses,
            newBadgePoints
        );

        uint sponsorCollectionId = 4;

        // 2. mint sponsor badge to bidder 1
        madSBT.mint(bidderAddress, sponsorCollectionId);
        assertEq(madSBT.totalRewardUnits(sponsorCollectionId), 1000, "someone didn't get their POINTS");
        assertEq(madSBT.rewardUnitsOf(bidderAddress, sponsorCollectionId), 1000);

        // 3. create a badge on bidder
        newBadgeAddresses[0] = bidderAddress2;
        newBadgePoints[0] = 500;
        madSBT.createAirdropCollection(
            bidderProfileId,
            GENESIS_BADGE_SUPPLY_CAP,
            GENESIS_BADGE_URI,
            newBadgeAddresses,
            newBadgePoints
        );

        uint bidderCollectionId = 5;

        // 4. mint bidder badge to bidder 2
        madSBT.mint(bidderAddress2, bidderCollectionId);
        assertEq(madSBT.totalRewardUnits(bidderCollectionId), 500, "someone didn't get their POINTS");
        assertEq(madSBT.rewardUnitsOf(bidderAddress2, bidderCollectionId), 500);
        vm.stopBroadcast();

        IERC20 superToken = IERC20(address(madSBT.rewardsToken()));

        // bidder 2 must approve the IDA subscription before auto-receiving their rewards
        vm.startBroadcast(bidderPrivateKey2);
        ISuperfluid(sfHost).callAgreement(
            idaV1,
            abi.encodeCall(
                IIDAV1.approveSubscription,
                (
                    address(superToken),
                    address(madSBT),
                    uint32(bidderCollectionId),
                    new bytes(0) // ctx placeholder
                )
            ),
            new bytes(0)
        );
        vm.stopBroadcast();

        // 3. create a bounty
        vm.startPrank(sponsor);
        uint bountyAmount = 100_000000; // 100 usdc
        helperMintApproveTokens(bountyAmount, sponsor, usdc);
        uint256 newBountyId = bounties.deposit(address(usdc), bountyAmount, sponsorCollectionId);

        // 4. settle a bounty payout with revshare
        Structs.RankedSettleInput[] memory input = createSettleDataWithRevshare(newBountyId, 10_00, bidderCollectionId);
        bounties.rankedSettle(newBountyId, input, uniswapFee);

        // 5. check balances of bidder and bidder2 (revshare recipient)
        assertEq(usdc.balanceOf(bidderAddress), 90 * bidAmount1 / 100, "bidder didn't get the right amount of USDC");

        assertEq(superToken.balanceOf(bidderAddress2), 10 * bidAmount1 / 100, "bidder2 didn't get the right amount of USDCX");

        // 6. check points of bidder on sponsor badge
        assertEq(madSBT.rewardUnitsOf(bidderAddress, sponsorCollectionId), 1050, "bidder didn't get their POINTS");
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

    function testSubscriptions_basic() public {
        // setup: send the bidders some supertokens
        vm.startBroadcast(devPrivateKey);
        IERC20 superToken = IERC20(address(madSBT.rewardsToken()));
        superToken.transfer(bidderAddress, 20 ether);
        superToken.transfer(bidderAddress2, 20 ether);
        vm.stopBroadcast();

        // 1. both bidders subscribe
        _createFlow(superToken, bidderPrivateKey, address(0), deployer, genesisCollectionId);
        _createFlow(superToken, bidderPrivateKey2, address(0), deployer, genesisCollectionId);

        // 2. fast forward 1 month
        skip(SECONDS_ONE_MONTH);

        // 3. bidder 2 unsubs
        _deleteFlow(superToken, bidderPrivateKey2, bidderAddress2);

        // 4. bidder unsubs
        vm.recordLogs();
        _deleteFlow(superToken, bidderPrivateKey, bidderAddress);

        // emits an event from our superapp, meaning we did not get jailed
        assertEq(validateLogEmitted(vm.getRecordedLogs(), "StreamDeleted(address,address,uint256)"), true);

        // not jailed
        assertEq(ISuperfluid(sfHost).isAppJailed(latestSubscriptionHandler), false);

        // flow rate between the superapp and the receiver should be 0
        (, int96 flowRate,,) = ICFAV1(cfaV1).getFlow(address(superToken), latestSubscriptionHandler, deployer);
        assertEq(flowRate, 0, "flow rate with the creator should now be 0");
    }

    /// forge-config: default.fuzz.runs = 10
    /// forge-config: default.invariant.fail-on-revert = false
    function testSubscriptions_fuzz(
        address subscriber1,
        address subscriber2,
        address subscriber3,
        address subscriber4,
        address subscriber5,
        uint256 flowDurationSeconds,
        uint256 deleteFlowGapsSeconds
    ) public {
        // subscription up to 2 months
        vm.assume(flowDurationSeconds < SECONDS_ONE_MONTH * 2);
        // gaps up to 10 days betweeen unsubs
        vm.assume(deleteFlowGapsSeconds < SECONDS_ONE_DAY * 10);

        // setup: send the subscribers some supertokens, enough to cover the `flowDurationSeconds`
        vm.startBroadcast(devPrivateKey);
        IERC20 superToken = IERC20(address(madSBT.rewardsToken()));
        superToken.transfer(subscriber1, 25 ether);
        superToken.transfer(subscriber2, 25 ether);
        superToken.transfer(subscriber3, 25 ether);
        superToken.transfer(subscriber4, 25 ether);
        superToken.transfer(subscriber5, 25 ether);
        vm.stopBroadcast();

        // 1. all subscribe to the genesis badge creator
        _createFlow(superToken, 0, subscriber1, deployer, genesisCollectionId);
        _createFlow(superToken, 0, subscriber2, deployer, genesisCollectionId);
        _createFlow(superToken, 0, subscriber3, deployer, genesisCollectionId);
        _createFlow(superToken, 0, subscriber4, deployer, genesisCollectionId);
        _createFlow(superToken, 0, subscriber5, deployer, genesisCollectionId);

        // 2. fast forward variable amount of time
        skip(flowDurationSeconds);

        // 3. they sporadically unsubscribe
        _deleteFlow(superToken, 0, subscriber1);
        // not jailed
        assertEq(ISuperfluid(sfHost).isAppJailed(latestSubscriptionHandler), false);
        skip(deleteFlowGapsSeconds);
        _deleteFlow(superToken, 0, subscriber2);
        // not jailed
        assertEq(ISuperfluid(sfHost).isAppJailed(latestSubscriptionHandler), false);
        skip(deleteFlowGapsSeconds);
        _deleteFlow(superToken, 0, subscriber3);
        // not jailed
        assertEq(ISuperfluid(sfHost).isAppJailed(latestSubscriptionHandler), false);
        skip(deleteFlowGapsSeconds);
        _deleteFlow(superToken, 0, subscriber4);
        // not jailed
        assertEq(ISuperfluid(sfHost).isAppJailed(latestSubscriptionHandler), false);
        skip(deleteFlowGapsSeconds);

        // 4. last one unsubs
        vm.recordLogs();
        _deleteFlow(superToken, 0, subscriber5);

        // emits an event from our superapp, meaning we did not get jailed
        assertEq(validateLogEmitted(vm.getRecordedLogs(), "StreamDeleted(address,address,uint256)"), true);

        // not jailed
        assertEq(ISuperfluid(sfHost).isAppJailed(latestSubscriptionHandler), false);

        // flow rate between the superapp and the receiver should be 0
        (, int96 flowRate,,) = ICFAV1(cfaV1).getFlow(address(superToken), latestSubscriptionHandler, deployer);
        assertEq(flowRate, 0, "flow rate with the creator should now be 0");
    }

    /// forge-config: default.fuzz.runs = 10
    /// forge-config: default.invariant.fail-on-revert = false
    function testSubscriptionsMultiCreators_fuzz(
        address subscriber1,
        address subscriber2,
        uint256 flowDurationSeconds,
        uint256 deleteFlowGapsSeconds
    ) public {
        // subscription up to 2 months
        vm.assume(flowDurationSeconds < SECONDS_ONE_MONTH * 2);
        // gaps up to 10 days betweeen unsubs
        vm.assume(deleteFlowGapsSeconds < SECONDS_ONE_DAY * 10);

        // setup: send the subscribers some supertokens, enough to cover the `flowDurationSeconds`
        vm.startBroadcast(devPrivateKey);
        IERC20 superToken = IERC20(address(madSBT.rewardsToken()));
        superToken.transfer(subscriber1, 25 ether);
        superToken.transfer(subscriber2, 25 ether);
        vm.stopBroadcast();

        (int96 defaultFlowRate,,) = subscriptionHandler.creatorFees(deployer);
        int96 includingFee = defaultFlowRate + (defaultFlowRate * subscriptionHandler.protocolFeePct() / 10000);

        // setup: another creator makes their badge
        vm.startPrank(bidderAddress);
        uint256 otherCollectionId = madSBT.createCollection(bidderAddress, bidderProfileId, basicCollectionCalldata);
        subscriptionHandler.setCreatorFee(bidderAddress, defaultFlowRate, 86400, false);
        vm.stopPrank();

        // 1. all subscribe to the genesis badge creator + the other one
        _createFlow(superToken, 0, subscriber1, deployer, genesisCollectionId);
        _createFlow(superToken, 0, subscriber2, deployer, genesisCollectionId);

        (, int96 latestFlowRate,,) = ICFAV1(cfaV1).getFlow(address(superToken), subscriber1, latestSubscriptionHandler);
        _updateFlow(superToken, 0, subscriber1, bidderAddress, otherCollectionId, latestFlowRate + includingFee, false);
        _updateFlow(superToken, 0, subscriber2, bidderAddress, otherCollectionId, latestFlowRate + includingFee, false);

        // 2. fast forward variable amount of time
        skip(flowDurationSeconds);

        // 3. they sporadically unsubscribe
        _deleteFlow(superToken, 0, subscriber1);
        // not jailed
        assertEq(ISuperfluid(sfHost).isAppJailed(latestSubscriptionHandler), false);
        skip(deleteFlowGapsSeconds);

        // 4. last one deletes first via #updateFlow and then #deleteFlow
        (, int96 totalFlowRate,,) = ICFAV1(cfaV1).getFlow(address(superToken), subscriber2, latestSubscriptionHandler);
        _updateFlow(superToken, 0, subscriber2, bidderAddress, genesisCollectionId, totalFlowRate - includingFee, true);
        skip(flowDurationSeconds);
        vm.recordLogs();
        _deleteFlow(superToken, 0, subscriber2);

        // emits an event from our superapp, meaning we did not get jailed
        assertEq(validateLogEmitted(vm.getRecordedLogs(), "StreamDeleted(address,address,uint256)"), true);

        // not jailed
        assertEq(ISuperfluid(sfHost).isAppJailed(latestSubscriptionHandler), false);

        // flow rate between the superapp and the receiver should be 0
        (, int96 flowRate,,) = ICFAV1(cfaV1).getFlow(address(superToken), latestSubscriptionHandler, deployer);
        assertEq(flowRate, 0, "flow rate with the creator should now be 0");
    }

    function _createFlow(IERC20 superToken, uint256 senderPrivateKey, address sender, address receiver, uint256 collectionId) internal {
        (int96 flowRate,,) = subscriptionHandler.creatorFees(receiver);
        senderPrivateKey == 0 ? vm.prank(sender) : vm.startBroadcast(senderPrivateKey);
        ISuperfluid(sfHost).callAgreement(
            cfaV1,
            abi.encodeCall(
                ICFAV1.createFlow,
                (address(superToken), latestSubscriptionHandler, flowRate, new bytes(0))
            ),
            abi.encode(receiver, collectionId, false)
        );
        if (senderPrivateKey != 0) vm.stopBroadcast();
    }

    function _updateFlow(
        IERC20 superToken,
        uint256 senderPrivateKey,
        address sender,
        address receiver,
        uint256 collectionId,
        int96 newFlowRate,
        bool isCanceling
    ) internal {
        senderPrivateKey == 0 ? vm.prank(sender) : vm.startBroadcast(senderPrivateKey);
        ISuperfluid(sfHost).callAgreement(
            cfaV1,
            abi.encodeCall(
                ICFAV1.updateFlow,
                (address(superToken), latestSubscriptionHandler, newFlowRate, new bytes(0))
            ),
            abi.encode(receiver, collectionId, isCanceling)
        );
        if (senderPrivateKey != 0) vm.stopBroadcast();
    }

    function _deleteFlow(IERC20 superToken, uint256 senderPrivateKey, address sender) internal {
        senderPrivateKey == 0 ? vm.prank(sender) : vm.startBroadcast(senderPrivateKey);
        ISuperfluid(sfHost).callAgreement(
            cfaV1,
            abi.encodeCall(
                ICFAV1.deleteFlow,
                (address(superToken), sender, latestSubscriptionHandler, new bytes(0))
            ),
            new bytes(0)
        );
        if (senderPrivateKey != 0) vm.stopBroadcast();
    }
}
