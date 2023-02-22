// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Ethernaut.sol";
import "../src/metrics/Statistics.sol";
import "openzeppelin-contracts/utils/Address.sol";
import "../src/metrics/Statistics.sol";
import "../src/levels/AlienCodexHack.sol";

contract AlienCodexTest is Test {
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

    function testAlienCodexHack() public {
        /* Level Setup */
        // Deploy level factory: AlienCodexFactory
        bytes memory bytecode = vm.getCode(
            "AlienCodexFactory.sol:AlienCodexFactory"
        );

        address alienCodexFactoryAddress;
        assembly {
            alienCodexFactoryAddress := create(
                0,
                add(bytecode, 0x20),
                mload(bytecode)
            )
        }

        // Register level on Ethernaut
        ethernaut.registerLevel(Level(alienCodexFactoryAddress));

        // Set caller to custom address
        vm.startPrank(eoa);
        vm.deal(eoa, 1 ether);

        // Start recording logs to capture new level instance address
        vm.recordLogs();
        // Create new level instance via Ethernaut
        ethernaut.createLevelInstance{value: 0.001 ether}(
            Level(alienCodexFactoryAddress)
        );

        // Parse emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[0].topics[0],
            keccak256("LevelInstanceCreatedLog(address,address,address)")
            // event LevelInstanceCreatedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelAlienCodexCreatedLog = entries[0];

        // Cast bytes32 log arg into address
        address instanceAddress = address(
            uint160(uint256(levelAlienCodexCreatedLog.topics[2]))
        );
        emit log_named_address("instanceAddress", instanceAddress);

        Ownable instance = Ownable(instanceAddress);

        /* Level Hack */
        address owner = instance.owner();
        emit log_named_address("owner", owner);
        assertEq(owner, address(alienCodexFactoryAddress));
        address ownerFromSlot = address(
            uint160(uint256(vm.load(instanceAddress, 0)))
        );
        emit log_named_address("ownerFromSlot", ownerFromSlot);
        assertEq(ownerFromSlot, address(alienCodexFactoryAddress));

        AlienCodexHack alienCodexHack = new AlienCodexHack(instanceAddress);
        
        owner = instance.owner();
        emit log_named_address("owner", owner);
        assertEq(owner, address(eoa));
        ownerFromSlot = address(uint160(uint256(vm.load(instanceAddress, 0))));
        emit log_named_address("ownerFromSlot", ownerFromSlot);
        assertEq(ownerFromSlot, address(eoa));

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
