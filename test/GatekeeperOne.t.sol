// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Ethernaut.sol";
import "../src/metrics/Statistics.sol";
import "../src/levels/GatekeeperOneFactory.sol";
import "../src/levels/GatekeeperOne.sol";
import "../src/levels/GatekeeperOneHack.sol";

contract GatekeeperOneTest is Test {
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

    function testGatekeeperOneHack() public {
        /* Level Setup */
        // Deploy level factory: GatekeeperOneFactory
        GatekeeperOneFactory gatekeeperOneFactory = new GatekeeperOneFactory();
        // Register level on Ethernaut
        ethernaut.registerLevel(gatekeeperOneFactory);

        // Set caller to custom address
        // set tx.origin to custom address too, since its being checked
        vm.startPrank(eoa, eoa);
        vm.deal(eoa, 1 ether);

        // Start recording logs to capture new level instance address
        vm.recordLogs();
        // Create new level instance via Ethernaut
        ethernaut.createLevelInstance{value: 0.001 ether}(gatekeeperOneFactory);

        // Parse emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[0].topics[0],
            keccak256("LevelInstanceCreatedLog(address,address,address)")
            // event LevelInstanceCreatedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelGatekeeperOneCreatedLog = entries[0];

        // Cast bytes32 log arg into address
        address instanceAddress = address(
            uint160(uint256(levelGatekeeperOneCreatedLog.topics[2]))
        );
        emit log_named_address("instanceAddress", instanceAddress);

        // Instantiate level instance
        GatekeeperOne instance = GatekeeperOne(payable(instanceAddress));

        /* Level Hack */
        address entrant = instance.entrant();
        emit log_named_address("entrant", entrant);
        assertEq(entrant, address(0));

        // Solution comments in GatekeeperOne.sol
        // Read docs about conversion: https://docs.soliditylang.org/en/latest/types.html#conversions-between-elementary-types
        // tx.origin will be eoa since we're pranking it
        // uint160(eoa) = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045
        // uint16(uin160(eoa)) = 0x6045
        // uint32(uint16(uint160(eoa))) = 0x00 00 60 45  // pad 2 zero bytes to left to make it 32 bits = 4 bytes
        // uint64(uint32(uint16(uint160(eoa)))) = 0x00 00 00 00 00 00 60 45 // pad 4 more zero bytes to left to make it 64 bits = 8 bytes
        // bytes8(uint64(uint32(uint16(uint160(eoa))))) = same number
        // bytes4(0x00000011) = 0x00 00 00 11
        // bytes8(bytes4(0x00000011)) = 0x00 00 00 11 00 00 00 00  // pad 4 zero bytes to the right to make it 8 bytes
        // OR the two:
        // 0x00 00 00 00 00 00 60 45 OR
        // 0x00 00 00 11 00 00 00 00
        // -----------------------------
        // 0x00 00 00 11 00 00 60 45  = _gateKey

        // uint64(_gateKey) = same number
        // uint32(uint64(_gateKey)) = 0x00 00 60 45 // remove 4 bytes from left to make it 4 bytes

        // uint16(uint64(_gateKey)) = 0x60 45 // remove 6 bytes from left to make it 2 bytes
        // uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)) is thus true

        // uint64(_gateKey) = same number
        // uint32(uint64(_gateKey)) != uint64(_gateKey) is thus true

        // uint16(uint160(eoa)) = 0x60 45
        // uint32(uint64(_gateKey)) == uint16(uint160(eoa)) is this true

        bytes8 _gateKey = bytes8(uint64(uint32(uint16(uint160(eoa))))) |
            bytes8(bytes4(0x00000011));
        // Assert all gate checks from GatekeeperOne's gateThree
        assertTrue(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)));
        assertTrue(uint32(uint64(_gateKey)) != uint64(_gateKey));
        assertTrue(uint32(uint64(_gateKey)) == uint16(uint160(eoa)));

        GatekeeperOneHack gatekeeperOneHack = new GatekeeperOneHack(
            instanceAddress
        );

        entrant = instance.entrant();
        emit log_named_address("entrant", entrant);
        assertEq(entrant, address(eoa));

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
