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

import "openzeppelin/token/ERC1155/ERC1155.sol";
import "./interfaces/IRewardNft.sol";

contract RewardNft is ERC1155, IRewardNft {
    address escrow;
    uint256 collectionsCount;

    mapping(uint256 => string) public tokenURIs;

    constructor(address _escrow) ERC1155("") {
        escrow = _escrow;
    }

    function createCollection(string calldata _tokenUri) external override onlyEscrow returns (uint256) {
        collectionsCount++; // start at 1
        tokenURIs[collectionsCount] = _tokenUri;
        return collectionsCount;
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data) external override onlyEscrow {
        require(id <= collectionsCount, "Nonexistant collection");
        _mint(account, id, amount, data);
    }

    function uri(uint256 _id) public view override(ERC1155) returns (string memory) {
        return tokenURIs[_id];
    }

    modifier onlyEscrow() {
        require(msg.sender == escrow, "Only escrow");
        _;
    }
}
