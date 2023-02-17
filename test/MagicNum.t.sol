// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Ethernaut.sol";
import "../src/metrics/Statistics.sol";
import "../src/levels/MagicNumFactory.sol";
import "../src/levels/MagicNum.sol";

interface ISimpleToken {
    function destroy(address payable _to) external;
}

contract MagicNumTest is Test {
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

    function testMagicNumHack() public {
        /* Level Setup */
        // Deploy level factory: MagicNumFactory
        MagicNumFactory magicNumFactory = new MagicNumFactory();
        // Register level on Ethernaut
        ethernaut.registerLevel(magicNumFactory);

        // Set caller to custom address
        vm.startPrank(eoa);
        vm.deal(eoa, 1 ether);

        // Start recording logs to capture new level instance address
        vm.recordLogs();
        // Create new level instance via Ethernaut
        ethernaut.createLevelInstance{value: 0.001 ether}(magicNumFactory);

        // Parse emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[0].topics[0],
            keccak256("LevelInstanceCreatedLog(address,address,address)")
            // event LevelInstanceCreatedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelMagicNumCreatedLog = entries[0];

        // Cast bytes32 log arg into address
        address instanceAddress = address(
            uint160(uint256(levelMagicNumCreatedLog.topics[2]))
        );
        emit log_named_address("instanceAddress", instanceAddress);

        // Instantiate level instance
        MagicNum instance = MagicNum(payable(instanceAddress));

        /* Level Hack */
        // Easy to develop bytecode and mnemonics in evm.codes playground
        // The bytecode doesn't necessarily have to handle any specific calls
        // It will be executed for whatever / however it is being called
        // So we just need to return the number
        /* Mnemonic */
        // 42 = 0x2a
        // PUSH1 0x2a : Push 0x2a 1 byte to stack : second argument `value` to MSTORE : 60 2a
        // PUSH1 0 : Push 0 1 byte to stack : first argument `offset` to MSTORE : 60 00
        // MSTORE : Store 0x2a at memory offset 0 : MSTORE(offset, value) : 52
        // PUSH1 32 : Push 32 1 byte to stack : second argument `value` to RETURN : 60 20
        // PUSH1 0 : Push 0 1 byte to stack : first argument `offset` to RETURN : 60 00
        // RETURN : Return 32 bytes from memory starting at offset 0 : f3
        /* Bytecode */
        // 0x602a60005260206000f3
        // Hexadecimal literals are prefixed with the keyword hex and are enclosed in double or single-quotes: https://docs.soliditylang.org/en/v0.8.17/types.html#hexadecimal-literals
        bytes memory bytecode = hex"602a60005260206000f3";
        vm.etch(address(0x4337), bytecode);
        assertEq(address(0x4337).code, bytecode);

        instance.setSolver(address(0x4337));

        Solver solver = Solver(instance.solver());
        assertEq(address(solver), address(0x4337));
        uint256 result = uint256(solver.whatIsTheMeaningOfLife());
        assertEq(result, 42);

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
