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
import {ISwapRouter} from "../interfaces/IUniswap.sol";
import {ISuperToken} from "../interfaces/ISuperToken.sol";

library RevShare {
    /**
     * @dev Distribute rewards to a collection
     * @param madSBT The MadSBT contract
     * @param revShareAmount The amount of rewards to distribute
     * @param collectionId The collection to distribute rewards to
     * @param token The token to distribute
     * @param swapRouter The swap router to use
     */
    function distribute(IMadSBT madSBT, uint256 revShareAmount, uint256 collectionId, address token, address swapRouter)
        public
    {
        address rewardsToken = madSBT.rewardsToken();
        address underlying = ISuperToken(rewardsToken).getUnderlyingToken();

        // check if token is underlying
        if (token != underlying) {
            // swap token to underlying
            ISwapRouter uniswapV3Router = ISwapRouter(swapRouter);

            IERC20(token).approve(address(uniswapV3Router), revShareAmount);

            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: token,
                tokenOut: underlying,
                fee: 1000,
                recipient: address(this),
                deadline: block.timestamp + 15,
                amountIn: revShareAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            uniswapV3Router.exactInputSingle(params);
        }

        // wrap as super usdc
        IERC20(token).approve(rewardsToken, revShareAmount);
        ISuperToken(rewardsToken).upgrade(revShareAmount);

        // instant distribution
        IERC20(rewardsToken).approve(address(madSBT), revShareAmount);
        madSBT.distributeRewards(collectionId, revShareAmount);
    }
}
