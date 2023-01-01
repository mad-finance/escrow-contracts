// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/ERC721.sol";

/**
 * Simple token contract for running tests
 */
contract MockNft is ERC721 {
    constructor() ERC721("MockToken", "MT") {}
}
