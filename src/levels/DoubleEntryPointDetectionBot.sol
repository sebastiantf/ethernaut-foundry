// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts-08/access/Ownable.sol";
import "openzeppelin-contracts-08/token/ERC20/ERC20.sol";

interface DelegateERC20 {
    function delegateTransfer(
        address to,
        uint256 value,
        address origSender
    ) external returns (bool);
}

interface IDetectionBot {
    function handleTransaction(address user, bytes calldata msgData) external;
}

interface IForta {
    function setDetectionBot(address detectionBotAddress) external;

    function notify(address user, bytes calldata msgData) external;

    function raiseAlert(address user) external;
}

contract DoubleEntryPointDetectionBot is IDetectionBot {
    address public cryptoVault;
    IForta public forta;

    constructor(address vaultAddress, address fortaAddress) {
        forta = IForta(fortaAddress);
        cryptoVault = vaultAddress;
    }

    function handleTransaction(address user, bytes calldata msgData) external {
        bytes4 selector;
        address to;
        uint256 value;
        address origSender;
        assembly {
            // in calldata, first element will be the first element
            // first 4 bytes will be selector since using abi.encodeWithSignature()
            // remaining args would be encoded as 32 byte words
            let selectorOffset := msgData.offset // so `selector` would be first 4 bytes
            let toOffset := add(selectorOffset, 0x04) // `to` will be 32 bytes from after `selector` converted to 20 bytes
            let valueOffset := add(toOffset, 0x20) // `value` will be 32 bytes from after `to` converted to uint256
            let origSenderOffset := add(valueOffset, 0x20) // `origSender` will be 32 bytes from after `value` converted to 20 bytes

            selector := calldataload(selectorOffset)
            to := calldataload(toOffset)
            value := calldataload(valueOffset)
            origSender := calldataload(origSenderOffset)
        }

        // if `delegateTransfer()` was called by Legacy Token as part of a sweepToken(legacyToken) call to the vault,
        // selector would be 0x9cd1a121
        // origSender would be vault
        // In that case we raise an alert:
        if (
            selector == DelegateERC20.delegateTransfer.selector &&
            origSender == cryptoVault
        ) forta.raiseAlert(user);
    }
}
