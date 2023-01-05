// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin/token/ERC721/ERC721.sol";

/**
 * Simple token contract for running tests
 */
contract MockNft is ERC721 {
    uint256 public tokenId = 0;

    constructor() ERC721("MockToken", "MT") {}

    function zkClaim(address recipient) external {
        _mint(recipient, tokenId++);
    }
}
