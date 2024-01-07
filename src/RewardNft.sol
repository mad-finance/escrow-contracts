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

import "openzeppelin/token/ERC1155/extensions/ERC1155Supply.sol";
import "openzeppelin/access/Ownable.sol";
import "./interfaces/IRewardNft.sol";

/**
 * @dev This contract is used to mint and track reward NFTs
 */
contract RewardNft is Ownable, ERC1155Supply, IRewardNft {
    mapping(address => bool) public isAdmin;
    uint256 collectionCount;

    mapping(uint256 => string) public tokenURIs; // collectionId => tokenURI
    mapping(uint256 => address) public creators; // collectionId => creator

    constructor(address _bounties) ERC1155("") Ownable() {
        setAdmin(_bounties, true);
    }

    /// @notice creates a new collection, can be called by anyone
    function createCollection(string calldata _tokenUri, address _creator) external override returns (uint256) {
        collectionCount++; // start at 1
        tokenURIs[collectionCount] = _tokenUri;
        creators[collectionCount] = _creator;
        emit CollectionCreated(collectionCount, _creator);
        return collectionCount;
    }

    /// @notice mints a new NFT, can only be called by the creator of the collection or the bounties contract (as an admin)
    function mint(address recipient, uint256 id, uint256 amount, bytes memory data) external override onlyMinter(id) {
        require(id <= collectionCount, "Nonexistant collection");
        _mint(recipient, id, amount, data);
    }

    /// @notice mints a new NFT for each recipient, can only be called by the creator of the collection or the bounties contract (as an admin)
    function batchMint(address[] calldata recipients, uint256 id, bytes memory data) external override onlyMinter(id) {
        require(id <= collectionCount, "Nonexistant collection");
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], id, 1, data);
        }
    }

    /// @notice returns the URI for a given token ID
    function uri(uint256 _id) public view override(ERC1155) returns (string memory) {
        return tokenURIs[_id];
    }

    /// @notice sets an address as an admin, can only be called by the owner
    function setAdmin(address _address, bool _isAdmin) public onlyOwner {
        isAdmin[_address] = _isAdmin;
        emit AdminSet(_address, _isAdmin);
    }

    /// @notice modifier to restrict minting to the creator of the collection or the bounties contract (as an admin)
    modifier onlyMinter(uint256 collectionId) {
        require(isAdmin[msg.sender] || creators[collectionId] == msg.sender, "Only minter");
        _;
    }
}
