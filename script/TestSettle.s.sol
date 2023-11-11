// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Bounties.sol";

/**
 * @dev This script is used to test the rankedSettle function/sigs of the Bounties contract on a live testnet
 */
contract TestSettle is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_SPONSOR");
        vm.startBroadcast(deployerPrivateKey);

        address bountiesAddress = block.chainid == 137
            ? 0x385B33C3127d5AF5F74fB4193a8dFd86D9a4A166
            : 0xEB19265435306432667D7653A03A18134C03FE00;

        Bounties bounties = Bounties(payable(bountiesAddress));

        Types.PostParams memory post = Types.PostParams({
            profileId: 0x0333,
            contentURI: "ipfs://bafkreiesgeo56qqeylq3qnoixw46flqhhxe2vtnrmifa7zijj6pl2ai23a",
            actionModules: new address[](0),
            actionModulesInitDatas: new bytes[](0),
            referenceModule: 0x0000000000000000000000000000000000000000,
            referenceModuleInitData: ""
        });

        Types.MirrorParams memory mirror = Types.MirrorParams({
            profileId: 0,
            metadataURI: "",
            pointedProfileId: 0,
            pointedPubId: 0,
            referrerProfileIds: new uint256[](0),
            referrerPubIds: new uint256[](0),
            referenceModuleData: ""
        });

        uint256[] memory profileIds = new uint[](2);
        profileIds[0] = 0x015d;
        profileIds[1] = 0xec;
        uint256[] memory followTokenIds = new uint[](2);
        followTokenIds[0] = 0;
        followTokenIds[1] = 0;
        bytes[] memory datas = new bytes[](2);
        datas[0] = "";
        datas[1] = "";
        Bounties.FollowParams memory follow = Bounties.FollowParams({
            followerProfileId: 0x0333,
            idsOfProfilesToFollow: profileIds,
            followTokenIds: followTokenIds,
            datas: datas
        });

        Bounties.NftSettleInput[] memory input = new Bounties.NftSettleInput[](1);
        input[0] = Bounties.NftSettleInput({
            nonce: 2,
            recipient: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            signature: hex"fb9414e2b599f65a40f6616e3ccead083437c245d9e1219748fea034611b03da02317b0ac01fd0a17421b0cc85dcb737eb44d2e08558bd31b73ec4740fea2ebe1b",
            postParams: post,
            mirrorParams: mirror,
            followParams: follow
        });

        bounties.nftSettle(120, input);

        vm.stopBroadcast();
    }
}
