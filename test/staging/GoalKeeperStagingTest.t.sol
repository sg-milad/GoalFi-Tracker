// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, Vm} from "forge-std/Test.sol";
import {GoalKeeper} from "../../src/GoalKeeper.sol";
import {MockUSDT} from "../mock/MockUSDT.sol";

contract GoalKeeperInteractionTest is Test {
    GoalKeeper public goalkeeper;
    MockUSDT public usdt;

    address public user1;
    address public user2;

    uint256 public constant INITIAL_BALANCE = 1000e6; // 1000 USDT
    uint256 public constant STAKE_AMOUNT = 100e6; // 100 USDT

    function setUp() public {
        usdt = new MockUSDT();
        goalkeeper = new GoalKeeper(address(usdt));

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Fund users with USDT
        usdt.mint(user1, INITIAL_BALANCE);
        usdt.mint(user2, INITIAL_BALANCE);
    }

    function test_MultipleTasksWithPenalties() public {
        // User1 stakes tokens and creates multiple tasks
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);

        // Create 3 tasks
        uint256 deadline1 = block.timestamp + 1 days;
        uint256 deadline2 = block.timestamp + 2 days;
        uint256 deadline3 = block.timestamp + 3 days;

        goalkeeper.createTask("Task 1", deadline1);
        goalkeeper.createTask("Task 2", deadline2);
        goalkeeper.createTask("Task 3", deadline3);

        // Complete task 1, fail task 2, complete task 3
        goalkeeper.completeTask(1);

        // Move time past deadline2
        vm.warp(deadline2 + 1);
        goalkeeper.evaluateTask(2); // Should apply 20% penalty (3 tasks = 30%)

        // Complete task 3 before its deadline
        goalkeeper.completeTask(3);

        // Check final balance after penalties
        uint256 expectedBalance = STAKE_AMOUNT - ((STAKE_AMOUNT * 10) / 100); // 10% penalty
        assertEq(goalkeeper.getStakedBalance(user1), expectedBalance);
        vm.stopPrank();
    }

    function test_MultipleUsersInteraction() public {
        // Setup both users with stakes
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user2);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);
        vm.stopPrank();

        // User1 creates and completes task successfully
        vm.startPrank(user1);
        uint256 deadline1 = block.timestamp + 1 days;
        goalkeeper.createTask("User1 Task", deadline1);
        goalkeeper.completeTask(1);
        vm.stopPrank();

        // User2 creates task but fails to complete
        vm.startPrank(user2);
        uint256 deadline2 = block.timestamp + 1 days;
        goalkeeper.createTask("User2 Task", deadline2);
        vm.warp(deadline2 + 1);
        goalkeeper.evaluateTask(2);
        vm.stopPrank();

        // Verify balances
        assertEq(goalkeeper.getStakedBalance(user1), STAKE_AMOUNT); // User1 keeps full stake
        assertEq(goalkeeper.getStakedBalance(user2), (STAKE_AMOUNT * 90) / 100); // User2 loses 10%
    }

    function test_StakeWithdrawCycle() public {
        vm.startPrank(user1);

        // Initial stake
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);

        // Create and complete a task
        goalkeeper.createTask("Task 1", block.timestamp + 1 days);
        goalkeeper.completeTask(1);

        // Withdraw half
        uint256 withdrawAmount = STAKE_AMOUNT / 2;
        goalkeeper.withdrawTokens(withdrawAmount);

        // Stake more
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);

        // Create another task but fail it
        goalkeeper.createTask("Task 2", block.timestamp + 1 days);
        vm.warp(block.timestamp + 2 days);
        goalkeeper.evaluateTask(2);

        // Final balance check
        uint256 expectedBalance = STAKE_AMOUNT + (STAKE_AMOUNT / 2) - (((STAKE_AMOUNT + (STAKE_AMOUNT / 2)) * 10) / 100);
        assertEq(goalkeeper.getStakedBalance(user1), expectedBalance);
        vm.stopPrank();
    }

    function test_ComplexUserJourney() public {
        vm.startPrank(user1);

        // Stage 1: Initial stake and successful task
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);
        goalkeeper.createTask("Task 1", block.timestamp + 1 days);
        goalkeeper.completeTask(1);

        // Stage 2: Create multiple tasks with mixed results
        goalkeeper.createTask("Task 2", block.timestamp + 2 days);
        goalkeeper.createTask("Task 3", block.timestamp + 3 days);

        // Complete task 2
        goalkeeper.completeTask(2);

        // Fail task 3
        vm.warp(block.timestamp + 4 days);
        goalkeeper.evaluateTask(3);

        // Stage 3: Withdraw some tokens and create new task
        uint256 remainingBalance = goalkeeper.getStakedBalance(user1);
        uint256 withdrawAmount = remainingBalance / 2;
        goalkeeper.withdrawTokens(withdrawAmount);

        goalkeeper.createTask("Task 4", block.timestamp + 1 days);
        goalkeeper.completeTask(4);

        // Verify final state
        uint256[] memory taskIds = goalkeeper.getTaskIds(user1);
        assertEq(taskIds.length, 4);

        GoalKeeper.Task memory task1 = goalkeeper.getTaskDetails(1);
        GoalKeeper.Task memory task2 = goalkeeper.getTaskDetails(2);
        GoalKeeper.Task memory task3 = goalkeeper.getTaskDetails(3);
        GoalKeeper.Task memory task4 = goalkeeper.getTaskDetails(4);

        assertTrue(task1.isCompleted);
        assertTrue(task2.isCompleted);
        assertTrue(task3.isPenalized);
        assertTrue(task4.isCompleted);

        vm.stopPrank();
    }
}
