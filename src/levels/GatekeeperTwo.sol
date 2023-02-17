// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GatekeeperTwo {

  address public entrant;

  modifier gateOne() {
    // only requires that the caller into this contract is not the tx.origin
    // i.e, this contract should be called into by a contract that the tx.origin initially calls
    require(msg.sender != tx.origin);
    _;
  }

  modifier gateTwo() {
    uint x;
    // extcodesize() will return 0 if its checked during caller's construction
    // since the bytecode is stored only after the txn ends and mined
    // So it is required that the call should happen in the hack contract's constructor
    assembly { x := extcodesize(caller()) }
    require(x == 0);
    _;
  }

  modifier gateThree(bytes8 _gateKey) {
    // type(uint64).max == 0xffffffffffffffff
    // abi.encodePacked(msg.sender) = address of the sender = address of hack contract
    // address of hack contract can be pre-computed from tx.origin and its nonce
    // it can also be easily accessed by address(this) in the hack contract
    // bytes8() will return the first 8 bytes of that hash
    // hence _gateKey would be the diff of 0xffffffffffffffff and the first 8 bytes of this hash
    require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max);
    _;
  }

  function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
    entrant = tx.origin;
    return true;
  }
}
