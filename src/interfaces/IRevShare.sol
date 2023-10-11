// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IRevShare {
    struct CreatorData {
        uint256 collectionId;
        uint256 splitAmount;
    }

    event Deposited(uint256 indexed collectionId, address indexed token, uint256 amount);
    event Distributed(uint256 indexed collectionId, address indexed token, uint256 amount);
    event SetCreatorData(address indexed creator, CreatorData data);

    function deposit(uint256 _collectionId, uint256 _amount, address _token) external;

    function getCreatorData(address) external view returns (uint256, uint256);

    function getPoolAmount(uint256 collectionId, address token) external view returns (uint256);
}
