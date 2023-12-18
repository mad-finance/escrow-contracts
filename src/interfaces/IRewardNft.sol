// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IRewardNft {
    event CollectionCreated(uint256 indexed id, address creator);
    event AdminSet(address indexed admin, bool isAdmin);

    function createCollection(string calldata _tokenUri, address _creator) external returns (uint256);

    function mint(address recipient, uint256 id, uint256 amount, bytes memory data) external;

    function batchMint(address[] calldata recipients, uint256 id, bytes memory data) external;
}
