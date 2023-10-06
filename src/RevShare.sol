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

contract RevShare {
    // badgeId -> token -> amount
    mapping(uint256 => mapping(address => uint256)) public creatorPools;

    // badgeId -> split percent in bps (10000 = 100%)
    mapping(uint256 => uint256) public splitAmounts;

    event Deposited(uint256 indexed badgeId, address indexed token, uint256 amount);
    event Claimed(address indexed recipient, uint256 indexed badgeId, address indexed token, uint256 amount);

    constructor() {}

    function deposit(uint256 _badgeId, uint256 _amount, address _token) public {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        creatorPools[_badgeId][_token] += _amount;
        emit Deposited(_badgeId, _token, _amount);
    }

    /// to call from Bounty contract or custom collect 
    function depositWithSplit(uint256 _badgeId, uint256 _amount, address _token) external {
        deposit(_badgeId, splitAmounts[_badgeId] * _amount / 10000, _token);
    }

    function claim(uint256 _badgeId, address _token) external {
        uint256 amount;
        // TODO: calculate your share and claim

        emit Claimed(msg.sender, _badgeId, _token, amount);
    }

    function setSplitAmount(uint256 _badgeId, uint256 _splitAmount) external {
        // TODO: only badge owner
        require(_splitAmount <= 10000, "Split amount must be <= 10000");
        splitAmounts[_badgeId] = _splitAmount;
    }
}
