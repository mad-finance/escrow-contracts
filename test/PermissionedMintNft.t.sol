// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";
import "../src/PermissionedMintNft.sol";

contract PermissionedMintNftTest is Test {
    PermissionedMintNft nft;
    address defaultSender = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    address notary;
    bytes signature =
        hex"fbfcb489689c49cb14424de9df2afb3762e21547f65144bd93978c249b0803ab760fa5a6878b9ce2e055eb38efc11a41af1cd983e077ece405c2883df3a8354b1c";

    function setUp() public {
        nft = new PermissionedMintNft(
            "RewardNFT",
            "RNFT",
            "ipfs://ipfs_root_hash"
        );
        notary = vm.addr(1);
        nft.setNotary(notary);
    }

    function testMintNft() public {
        uint256 nonce = 1;
        address recipient = address(9);
        nft.mint(recipient, nonce, signature);

        assertTrue(nft.ownerOf(0) == recipient);
    }

    function testFailDoubleMintNft() public {
        uint256 nonce = 1;
        address recipient = address(9);

        nft.mint(recipient, nonce, signature);
        assertTrue(nft.ownerOf(0) == recipient);
        nft.mint(recipient, nonce, signature);
    }

    function testFailMintNftBadNotary() public {
        uint256 nonce = 1;
        address recipient = address(9);
        bytes
            memory badSig = hex"84c4ba596bb5fe17732a4ebf3a801926d379b45fca5909cb70d7c54a846d551061cce193018a232d30f4e4d2277ae143ed77ff6dc9ca83ed95d1ae30305e8d331c";
        nft.mint(recipient, nonce, badSig);
    }

    function testFailMintNftBadNonce() public {
        uint256 nonce = 2;
        address recipient = address(9);
        nft.mint(recipient, nonce, signature);
    }

    function testUriEncoding() public {
        uint256 nonce = 1;
        address recipient = address(9);
        nft.mint(recipient, nonce, signature);
        assertTrue(
            keccak256(abi.encodePacked(nft.tokenURI(0))) ==
                keccak256(abi.encodePacked("ipfs://ipfs_root_hash/0"))
        );

        nonce = 2;
        recipient = address(9);
        bytes
            memory sig2 = hex"fb22dc7e091a804ff29e2b5b80f37774d0bdf2a0eedfbd1b38df21fbe938e8117027a5fc65e73516f15613e60f432e1b9196c2d45bab7ddbb0fdac5f5d012e921b";
        nft.mint(recipient, nonce, sig2);
        assertTrue(
            keccak256(abi.encodePacked(nft.tokenURI(1))) ==
                keccak256(abi.encodePacked("ipfs://ipfs_root_hash/1"))
        );
    }

    function testSetNotary() public {
        address newNotary = address(4);
        nft.setNotary(newNotary);
        assertTrue(nft.notary() == newNotary);
    }

    function testFailSetNotary() public {
        address newNotary = address(5);
        vm.prank(address(9));
        nft.setNotary(newNotary);
        assertTrue(nft.notary() == newNotary);
    }
}
