// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IRewardNft {
    function createCollection(string calldata _tokenUri) external returns (uint256);

    function mint(address account, uint256 id, uint256 amount, bytes memory data) external;
}
