// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Ethernaut.sol";
import "../src/metrics/Statistics.sol";
import "../src/levels/InstanceFactory.sol";
import "../src/levels/Instance.sol";

contract InstanceTest is Test {
    Ethernaut ethernaut;
    Statistics statistics;

    function setUp() public {
        ethernaut = new Ethernaut();

        // Statistics is actually deployed as upgradeable proxy
        // Deploying and initializing it normally for simplicity
        statistics = new Statistics();
        statistics.initialize(address(ethernaut));

        // Set Statistics contract on Ethernaut
        ethernaut.setStatistics(address(statistics));
    }

    function testInstanceHack() public {
        /* Level Setup */
        // Deploy level factory: InstanceFactory
        InstanceFactory instanceFactory = new InstanceFactory();
        // Register level on Ethernaut
        ethernaut.registerLevel(instanceFactory);

        // Start recording logs to capture new level instance address
        vm.recordLogs();
        // Create new level instance via Ethernaut
        ethernaut.createLevelInstance(instanceFactory);

        // Parse emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[0].topics[0],
            keccak256("LevelInstanceCreatedLog(address,address,address)")
            // event LevelInstanceCreatedLog(address indexed player, address indexed instance, address indexed level);
        );
        // Cast bytes32 log arg into address
        address instanceAddress = address(
            uint160(uint256(entries[0].topics[2]))
        );
        emit log_named_address("instanceAddress", instanceAddress);

        // Instantiate level instance
        Instance instance = Instance(instanceAddress);
    }
}
