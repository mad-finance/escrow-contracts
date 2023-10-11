// SPDX-License-Identifier: MIT

/*

__/\\\\____________/\\\\_____/\\\\\\\\\_____/\\\\\\\\\\\\_____/\\\\\\\\\\\\\\\__/\\\\\\\\\\\_        
 _\/\\\\\\________/\\\\\\___/\\\\\\\\\\\\\__\/\\\////////\\\__\/\\\///////////__\/////\\\///__       
  _\/\\\//\\\____/\\\//\\\__/\\\/////////\\\_\/\\\______\//\\\_\/\\\_________________\/\\\_____      
   _\/\\\\///\\\/\\\/_\/\\\_\/\\\_______\/\\\_\/\\\_______\/\\\_\/\\\\\\\\\\\_________\/\\\_____     
    _\/\\\__\///\\\/___\/\\\_\/\\\\\\\\\\\\\\\_\/\\\_______\/\\\_\/\\\///////__________\/\\\_____    
     _\/\\\____\///_____\/\\\_\/\\\/////////\\\_\/\\\_______\/\\\_\/\\\_________________\/\\\_____   
      _\/\\\_____________\/\\\_\/\\\_______\/\\\_\/\\\_______/\\\__\/\\\_________________\/\\\_____  
       _\/\\\_____________\/\\\_\/\\\_______\/\\\_\/\\\\\\\\\\\\/___\/\\\______________/\\\\\\\\\\\_ 
        _\///______________\///__\///________\///__\////////////_____\///______________\///////////__
                                        
*/

pragma solidity ^0.8.10;

import "openzeppelin/token/ERC20/IERC20.sol";
import "madfi-protocol/interfaces/IMadSBT.sol";
import "./interfaces/IRevShare.sol";

contract RevShare is IRevShare {
    IMadSBT madSBT;

    // collectionId -> token -> amount
    mapping(uint256 => mapping(address => uint256)) creatorPools;

    // address => { collectionId, splitAmount }
    mapping(address => CreatorData) creatorData;

    /// CONSTRUCTOR
    constructor(address _madSbt) {
        madSBT = IMadSBT(_madSbt);
    }

    /// MUTATIVE FUNCTIONS

    /**
     * @notice Allows a user to deposit a specified amount of a specific token into a creator's pool
     * @param collectionId The ID of the collection to which the creator's pool belongs
     * @param amount The amount of the token to deposit
     * @param token The address of the token to deposit
     */
    function deposit(uint256 collectionId, uint256 amount, address token) public override {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        // TODO: wrap as super token
        creatorPools[collectionId][token] += amount;
        emit Deposited(collectionId, token, amount);
    }

    /**
     * @notice Allows a user to claim a specified amount of a specific token from a creator's pool
     * @param collectionId The ID of the collection to which the creator's pool belongs
     * @param token The address of the token to claim
     */
    function distributeRevShare(uint256 collectionId, address token) external {
        uint amount  = creatorPools[collectionId][token];
        // TODO: distribute rev share to badge hodlers
        // address superTokenAddress;
        // madSBT.distributeRevShare(collectionId, amount, superTokenAddress);
        emit Distributed(collectionId, token, amount);
    }

    /**
     * @notice Allows a badge creator to set the data for their creator pool
     * @param collectionId The ID of the collection to which the creator's pool belongs
     * @param splitAmount The amount of the token to split among the creator's pool
     */
    function setCreatorData(uint256 collectionId, uint256 splitAmount) external onlyBadgeCreator(collectionId) {
        require(splitAmount <= 10_000, "Split amount must be <= 10,000");
        CreatorData memory data = CreatorData(collectionId, splitAmount);
        creatorData[msg.sender] = data;
        emit SetCreatorData(msg.sender, data);
    }

    /// VIEWS

    /**
     * @notice Returns the data for a specific creator
     * @param creator The address of the creator
     * @return The ID of the collection to which the creator's pool belongs and the amount of the token to split among the creator's pool
     */
    function getCreatorData(address creator) external view override returns (uint256, uint256) {
        CreatorData storage data = creatorData[creator];
        return (data.collectionId, data.splitAmount);
    }

    /**
     * @notice Returns the amount of a specific token in a creator's pool
     * @param collectionId The ID of the collection to which the creator's pool belongs
     * @param token The address of the token
     * @return The amount of the token in the creator's pool
     */
    function getPoolAmount(uint256 collectionId, address token) external view override returns (uint256) {
        return creatorPools[collectionId][token];
    }

    /// MODIFIERS

    /**
     * @notice Ensures that only the creator of a badge can call a function
     * @param collectionId The ID of the collection to which the badge belongs
     */
    modifier onlyBadgeCreator(uint256 collectionId) {
        (,,,,, address creator,) = madSBT.collectionData(collectionId);
        require(msg.sender == creator, "Only badge creator can call this function");
        _;
    }
}
