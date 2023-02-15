// SPDX-License-Identifier: MIT
// pragma solidity ^0.6.12; // original
pragma solidity ^0.8.0; // changed to compile

// import 'openzeppelin-contracts-06/math/SafeMath.sol'; // original
import 'openzeppelin-contracts/utils/math/SafeMath.sol'; // changed to compile

contract Reentrance {
  
  using SafeMath for uint256;
  mapping(address => uint) public balances;

  function donate(address _to) public payable {
    balances[_to] = balances[_to].add(msg.value);
  }

  function balanceOf(address _who) public view returns (uint balance) {
    return balances[_who];
  }

  function withdraw(uint _amount) public {
    if(balances[msg.sender] >= _amount) {
      (bool result,) = msg.sender.call{value:_amount}("");
      if(result) {
        _amount;
      }
      // using unchecked to disable under/overflow checks
      unchecked {
        balances[msg.sender] -= _amount;
      }
    }
  }

  receive() external payable {}
}
