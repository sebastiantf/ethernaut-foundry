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
        // PUSH1 32 : Push 32 1 byte to stack : second argument `size` to RETURN : 60 20
        // PUSH1 0 : Push 0 1 byte to stack : first argument `offset` to RETURN : 60 00
        // RETURN : Return 32 bytes from memory starting at offset 0 : f3
        /* Bytecode */
        // 0x602a60005260206000f3
        // Hexadecimal literals are prefixed with the keyword hex and are enclosed in double or single-quotes: https://docs.soliditylang.org/en/v0.8.17/types.html#hexadecimal-literals
        // bytes memory bytecode = hex"602a60005260206000f3";
        // vm.etch(address(0x4337), bytecode);
        // assertEq(address(0x4337).code, bytecode);

        // In order to create the contract on a live network instead of using vm.etch(),
        // we need to prepare a calldata comprised of initCode + contractCode
        // initCode has to be bytecode that returns the contractCode that gets stored in an address's code storage
        // so the initCode should actually copy the contractCode bytes from the calldata into memory and return it
        /* Mnemonic */
        // PUSH1 0x0a : Push 0x0a to stack : third argument `size` for CODECOPY : 60 0a
        // PUSH1 0x0c : Push 0x0c to stack : second argument `offset` for CODECOPY : 60 0c
        // PUSH1 0 : Push 0 to stack : first argument `destOffset` for CODECOPY : 60 00
        // CODECOPY : Copy 10 (0x0a) bytes from calldata starting from offset 0x0c and store it in memory at offset 0 : CODECOPY(destOffset, offset, size) : 0x0c can be figured out in the end after laying out all the opcodes: 39
        /*  NOTE: Apparently, a contract creation txn has an empty calldata, but has a special `init` field where the contract creation code is available. Hence CALLDATACOPY would return empty while CODECOPY returns the code from `init`
        Hence we cannot use CALLDATACOPY and need to use CODECOPY
        Read more: https://betterprogramming.pub/solidity-tutorial-all-about-calldata-aebbe998a5fc#ce8d */
        // PUSH1 0x0a : Push 10 1 byte to stack : second argument `size` to RETURN : 60 0a
        // PUSH1 0 : Push 0 1 byte to stack : first argument `offset` to RETURN : 60 00
        // RETURN : Return 10 bytes from memory starting at offset 0 : f3
        // contractCode below:
        // PUSH1 0x2a
        // PUSH1 0
        // MSTORE
        // PUSH1 32
        // PUSH1 0
        // RETURN
        /* Bytecode */
        // 0xinitCode_602a60005260206000f3
        // 0x600a600c600039600a6000f3_602a60005260206000f3
        bytes
            memory creationCode = hex"600a600c600039600a6000f3_602a60005260206000f3";
        // this calldata can be used in a raw transaction to deploy the contractCode
        // We can also use the create() opcode to perform the contract creation:
        address solverAddr;
        assembly {
            // creationCode stored as bytes, which is a dynamic array
            // The length of a dynamic array is stored at the first slot of the array and followed by the array elements.
            // Read more: https://docs.soliditylang.org/en/v0.8.10/internals/layout_in_memory.html#layout-in-memory
            // create(msg.value, offset, size)
            // offset would be the second slot of the creationCode bytes array where the code actually starts
            // size would be the length of the creationCode bytes array which is stored at the first slot of the array
            // which can be loaded by mload(creationCode)
            solverAddr := create(
                0,
                add(creationCode, 0x20),
                mload(creationCode)
            )
            if iszero(eq(extcodesize(solverAddr), 10)) {
                revert(0, 0)
            }
        }

        /* Alternative creation code */
        // initCode only has to return the runtime bytecode
        // So there is an alternative contract creation bytecode
        // PUSH10 602a60005260206000f3 : Push all 10 bytes of the runtime bytecode to stack : second argument `value` to MSTORE : 69 602a60005260206000f3
        // PUSH1 0 : Push 0 1 byte to stack : first argument `offset` to MSTORE : 60 00
        // MSTORE : Store full runtime bytecode at memory offset 0 : MSTORE(offset, value) : 52
        // PUSH1 0x0a : Push 10 1 byte to stack : second argument `size` to RETURN : 60 0a
        // PUSH1 0x16 : Push 22 1 byte to stack : first argument `offset` to RETURN : 60 16
        // RETURN : Return 10 bytes from memory starting at offset 22 : f3
        /* Bytecode */
        // 0x69602a60005260206000f3600052600a6016f3

        instance.setSolver(solverAddr);

        Solver solver = Solver(instance.solver());
        assertEq(address(solver), solverAddr);
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
