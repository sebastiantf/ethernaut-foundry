// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Ethernaut.sol";
import "../src/metrics/Statistics.sol";
import "../src/levels/DoubleEntryPointFactory.sol";
import "../src/levels/DoubleEntryPoint.sol";
import {DoubleEntryPointDetectionBot} from "../src/levels/DoubleEntryPointDetectionBot.sol";

contract DoubleEntryPointTest is Test {
    using stdStorage for StdStorage;

    Ethernaut ethernaut;
    Statistics statistics;
    address eoa = address(0x1337);

    function setUp() public {
        ethernaut = new Ethernaut();

        // Statistics is actually deployed as upgradeable proxy
        // Deploying and initializing it normally for simplicity
        statistics = new Statistics();
        statistics.initialize(address(ethernaut));

        // Set Statistics contract on Ethernaut
        ethernaut.setStatistics(address(statistics));
    }

    function testDoubleEntryPointHack() public {
        /* Level Setup */
        // Deploy level factory: DoubleEntryPointFactory
        DoubleEntryPointFactory doubleEntryPointFactory = new DoubleEntryPointFactory();
        // Register level on Ethernaut
        ethernaut.registerLevel(doubleEntryPointFactory);

        // Set caller to custom address
        vm.startPrank(eoa);
        vm.deal(eoa, 1 ether);

        // Start recording logs to capture new level instance address
        vm.recordLogs();
        // Create new level instance via Ethernaut
        ethernaut.createLevelInstance{value: 0.001 ether}(
            doubleEntryPointFactory
        );

        // Parse emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[4].topics[0],
            keccak256("LevelInstanceCreatedLog(address,address,address)")
            // event LevelInstanceCreatedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelDoubleEntryPointCreatedLog = entries[4];

        // Cast bytes32 log arg into address
        address instanceAddress = address(
            uint160(uint256(levelDoubleEntryPointCreatedLog.topics[2]))
        );
        emit log_named_address("instanceAddress", instanceAddress);

        // Instantiate level instance
        DoubleEntryPoint instance = DoubleEntryPoint(payable(instanceAddress));
        Forta forta = instance.forta();

        /* Level Hack */
        DoubleEntryPointDetectionBot bot = new DoubleEntryPointDetectionBot(
            instance.cryptoVault(),
            address(forta)
        );
        forta.setDetectionBot(address(bot));

        /* If callData was in memory, we could've used this: */
        /* bytes memory callData = abi.encodeWithSignature(
            "delegateTransfer(address,uint256,address)",
            address(0x1337),
            25,
            address(0x4337)
        );
        emit log_named_bytes("callData", callData);
        address to;
        uint256 value;
        address origSender;
        assembly {
            // bytes first slot stores length so skip first 32 bytes: add(callData, 0x20)
            // first 4 bytes will be function selector so skip that: add(add(callData, 0x20), 0x04)
            // first 32 bytes would be to: mload(add(add(callData, 0x20), 0x04))
            // second 32 bytes would be value: mload(add(add(add(callData, 0x20), 0x04), 0x20))
            // third 32 bytes would be value: mload(add(add(add(callData, 0x20), 0x04), 0x40))
            to := mload(add(add(callData, 0x20), 0x04))
            value := mload(add(add(add(callData, 0x20), 0x04), 0x20))
            origSender := mload(add(add(add(callData, 0x20), 0x04), 0x40))
        }
        emit log_named_address("to", to);
        emit log_named_uint("value", value);
        emit log_named_address("origSender", origSender); */

        /* Level Submit */
        // Start recording logs to capture level completed log
        vm.recordLogs();
        ethernaut.submitLevelInstance(payable(instanceAddress));

        // Parse emitted logs
        Vm.Log[] memory submitLogsEntries = vm.getRecordedLogs();
        assertEq(
            submitLogsEntries[2].topics[0],
            keccak256("LevelCompletedLog(address,address,address)")
            // event LevelCompletedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelCompletedLog = submitLogsEntries[2];

        // Cast bytes32 log arg into address
        address playerAddress_ = address(
            uint160(uint256(levelCompletedLog.topics[1]))
        );
        emit log_named_address("playerAddress_", playerAddress_);

        address instanceAddress_ = address(
            uint160(uint256(levelCompletedLog.topics[2]))
        );
        emit log_named_address("instanceAddress_", instanceAddress_);

        assertEq(playerAddress_, eoa);
        assertEq(instanceAddress_, instanceAddress);

        vm.stopPrank();
    }
}
