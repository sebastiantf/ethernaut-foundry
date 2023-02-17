// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Ethernaut.sol";
import "../src/metrics/Statistics.sol";
import "../src/levels/GatekeeperTwoFactory.sol";
import "../src/levels/GatekeeperTwo.sol";
import "../src/levels/GatekeeperTwoHack.sol";

contract GatekeeperTwoTest is Test {
    using stdStorage for StdStorage;

    Ethernaut ethernaut;
    Statistics statistics;
    address eoa = address(0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045); // Vitalik's address

    function setUp() public {
        ethernaut = new Ethernaut();

        // Statistics is actually deployed as upgradeable proxy
        // Deploying and initializing it normally for simplicity
        statistics = new Statistics();
        statistics.initialize(address(ethernaut));

        // Set Statistics contract on Ethernaut
        ethernaut.setStatistics(address(statistics));
    }

    function testGatekeeperTwoHack() public {
        /* Level Setup */
        // Deploy level factory: GatekeeperTwoFactory
        GatekeeperTwoFactory gatekeeperTwoFactory = new GatekeeperTwoFactory();
        // Register level on Ethernaut
        ethernaut.registerLevel(gatekeeperTwoFactory);

        // Set caller to custom address
        // set tx.origin to custom address too, since its being checked
        vm.startPrank(eoa, eoa);
        vm.deal(eoa, 1 ether);

        // Start recording logs to capture new level instance address
        vm.recordLogs();
        // Create new level instance via Ethernaut
        ethernaut.createLevelInstance{value: 0.001 ether}(gatekeeperTwoFactory);

        // Parse emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[0].topics[0],
            keccak256("LevelInstanceCreatedLog(address,address,address)")
            // event LevelInstanceCreatedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelGatekeeperTwoCreatedLog = entries[0];

        // Cast bytes32 log arg into address
        address instanceAddress = address(
            uint160(uint256(levelGatekeeperTwoCreatedLog.topics[2]))
        );
        emit log_named_address("instanceAddress", instanceAddress);

        // Instantiate level instance
        GatekeeperTwo instance = GatekeeperTwo(payable(instanceAddress));

        /* Level Hack */

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
