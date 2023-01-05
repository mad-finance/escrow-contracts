// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/PermissionedMintVerifier.sol";
import "../src/mocks/MockNft.sol";

contract PermissionedMintVerifierTest is Test {
    PermissionedMintVerifier verifier;
    MockNft nft;
    bytes signature =
        hex"95cd9c1b8818567c2e11ac4bd9b8532ffa5f6c959db2721c0fd541530585c5dc5e5c7b3d6e9ad4d3ef29d549c08bc408506ec5812d82e6d08b818e25c030eee81c";

    address recipient = address(9);
    address notary = 0xB00B28559ae01D962dc72B6AaeDA7395cf8A4ecA;
    uint256 groupId = 1;
    address dcntCollection;
    uint256 lensPubId = 1;
    uint256 lensProfileId = 1;

    function setUp() public {
        verifier = new PermissionedMintVerifier();
        verifier.setNotary(notary);
        nft = new MockNft();
        dcntCollection = address(nft);
        verifier.createGroup(groupId, dcntCollection, lensPubId, lensProfileId);
    }

    function testMintNft() public {
        uint256 nonce = 1;
        verifier.mint(recipient, nonce, groupId, signature);
        assertTrue(nft.ownerOf(0) == recipient);
    }

    function testFailDoubleMintNft() public {
        uint256 nonce = 1;
        verifier.mint(recipient, nonce, groupId, signature);
        assertTrue(nft.ownerOf(0) == recipient);
        verifier.mint(recipient, nonce, groupId, signature);
    }

    function testFailMintNftBadNotary() public {
        uint256 nonce = 1;
        bytes memory badSig =
            hex"84c4ba596bb5fe17732a4ebf3a801926d379b45fca5909cb70d7c54a846d551061cce193018a232d30f4e4d2277ae143ed77ff6dc9ca83ed95d1ae30305e8d331c";
        verifier.mint(recipient, nonce, groupId, badSig);
    }

    function testFailMintNftBadNonce() public {
        uint256 nonce = 2;
        verifier.mint(recipient, nonce, groupId, signature);
    }

    function testSetNotary() public {
        address newNotary = address(4);
        verifier.setNotary(newNotary);
        assertTrue(verifier.notary() == newNotary);
    }

    function testFailSetNotary() public {
        address newNotary = address(5);
        vm.prank(address(6));
        verifier.setNotary(newNotary);
        assertTrue(verifier.notary() == newNotary);
    }
}
