// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GatekeeperOne {

  address public entrant;

  modifier gateOne() {
    // only requires that the caller into this contract is not the tx.origin
    // i.e, this contract should be called into by a contract that the tx.origin initially calls
    require(msg.sender != tx.origin);
    _;
  }

  modifier gateTwo() {
    require(gasleft() % 8191 == 0);
    _;
  }

  modifier gateThree(bytes8 _gateKey) {
      // solving the two gates below should solve this one too
      require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "GatekeeperOne: invalid gateThree part one");
      // see below for the initial step to calculating _gateKey
      // uint64(bytes8) will be the same number
      // uint32 will remove the higher order 4 bytes
      // so the higher order 4 bytes should be non-zero so that removing them gives a different number from the original _gateKey
      // Hence _gateKey = bytes8(uint64(uint32(uint16(uint160(tx.origin))))) | bytes8(bytes4(some non-zero number))
      require(uint32(uint64(_gateKey)) != uint64(_gateKey), "GatekeeperOne: invalid gateThree part two");
      // convert tx.origin address into uint160, then into uint16
      // it removes the higher order bits leaving the last 2 bytes of the address
      // uint64(bytes8) will be the same number
      // converting that into uint32 will remove the higher order bits
      // 16bit number will be the same number whether its converted to 64bit or 32bit number
      // to make the equality, _gateKey should have 2 higher order bytes that gets removed on converting to uint32
      // we can pad higher order zero bytes by converting to a higher type
      // we need to pad 2 bytes from uint16 i.e, convert it into uint32
      // Hence _gateKey = bytes8(uint64(uint32(uint16(uint160(tx.origin)))))
      require(uint32(uint64(_gateKey)) == uint16(uint160(tx.origin)), "GatekeeperOne: invalid gateThree part three");
    _;
  }

  function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
    entrant = tx.origin;
    return true;
  }
}
