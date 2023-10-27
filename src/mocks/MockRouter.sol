// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {ISwapRouter} from "madfi-protocol/interfaces/IUniswap.sol";
import "./MockToken.sol";

contract MockRouter is ISwapRouter {
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        MockToken(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        MockToken(params.tokenOut).mint(msg.sender, params.amountIn);

        return params.amountIn;
    }
}
