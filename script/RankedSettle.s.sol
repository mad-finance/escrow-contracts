// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Bounties.sol";

/**
 * @dev This script is used to test the rankedSettle function/sigs of the Bounties contract on a live testnet
 */
contract RankedSettle is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_SPONSOR");
        vm.startBroadcast(deployerPrivateKey);

        // address bountiesAddress = block.chainid == 137
        //     ? 0x385B33C3127d5AF5F74fB4193a8dFd86D9a4A166
        //     : 0xF02FA0e639b3615cc20B89db5Ea722F29EFa08D8;

        // Bounties bounties = Bounties(payable(bountiesAddress));

        Bounties bounties =
        new Bounties(0xC1E77eE73403B8a7478884915aA599932A677870, 10_00, 116, 0xE592427A0AEce92De3Edee1F18E0157C05861564);

        Types.PostParams memory post = Types.PostParams({
            profileId: 0xec,
            contentURI: "ipfs://bafkreifnli4e4alhtquf77bsf3ebgcdeyovc3gjl5ncusnznwmrk5v3jz4",
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

        Bounties.FollowParams memory follow = Bounties.FollowParams({
            followerProfileId: 0,
            idsOfProfilesToFollow: new uint256[](0),
            followTokenIds: new uint256[](0),
            datas: new bytes[](0)
        });

        Bounties.RankedSettleInput[] memory input = new Bounties.RankedSettleInput[](1);
        input[0] = Bounties.RankedSettleInput({
            bid: 5,
            recipient: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            revShare: 0,
            signature: hex"aa0733dc513e3708d2b425ed5a95d7f9ac4488107ce73ed9ca8e87d466af45b64ad1bed79cbe19cd99132c4395a001f750daeea5019de79c49d6857d2e08444d1c",
            postParams: post,
            mirrorParams: mirror,
            followParams: follow
        });

        bounties.rankedSettle(117, input, 500);

        vm.stopBroadcast();
    }
}
