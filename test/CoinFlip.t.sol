// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Ethernaut.sol";
import "../src/metrics/Statistics.sol";
import "../src/levels/CoinFlipFactory.sol";
import "../src/levels/CoinFlip.sol";
import "../src/levels/CoinFlipHack.sol";

contract CoinFlipTest is Test {
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

    function testCoinFlipHack() public {
        /* Level Setup */
        // Deploy level factory: CoinFlipFactory
        CoinFlipFactory coinFlipFactory = new CoinFlipFactory();
        // Register level on Ethernaut
        ethernaut.registerLevel(coinFlipFactory);

        // Set caller to custom address
        vm.startPrank(eoa);

        // Start recording logs to capture new level instance address
        vm.recordLogs();
        // Create new level instance via Ethernaut
        ethernaut.createLevelInstance(coinFlipFactory);

        // Parse emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[0].topics[0],
            keccak256("LevelInstanceCreatedLog(address,address,address)")
            // event LevelInstanceCreatedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelCoinFlipCreatedLog = entries[0];

        // Cast bytes32 log arg into address
        address instanceAddress = address(
            uint160(uint256(levelCoinFlipCreatedLog.topics[2]))
        );
        emit log_named_address("instanceAddress", instanceAddress);

        // Instantiate level instance
        CoinFlip instance = CoinFlip(payable(instanceAddress));

        /* Level Hack */
        // 0. Check current consecutiveWins
        uint256 consecutiveWins = instance.consecutiveWins();
        emit log_named_uint("consecutiveWins", consecutiveWins);
        assertEq(consecutiveWins, 0);

        // 1. Call coinFlipHack.flip() 10 times
        CoinFlipHack coinFlipHack = new CoinFlipHack(instanceAddress);
        for (uint8 i = 1; i <= 10; i++) {
            emit log_named_uint("block.number", block.number);

            bool flip = coinFlipHack.flip();
            assertTrue(flip);

            // mine new block
            vm.roll(block.number + 1);

            consecutiveWins = instance.consecutiveWins();
            assertEq(consecutiveWins, i);
        }
        emit log_named_uint("consecutiveWins", consecutiveWins);

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
