// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, Vm} from "forge-std/Test.sol";
import {GoalKeeper} from "../src/GoalKeeper.sol";
import {MockUSDT} from "./mock/MockUSDT.sol";

contract GoalKeeperTest is Test {
    GoalKeeper public goalkeeper;
    MockUSDT public usdt;

    address public owner;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_BALANCE = 1000e6; // 1000 USDT
    uint256 public constant INITIAL_USDT_BALANCE = 1e24; // 1000 USDT
    uint256 public constant STAKE_AMOUNT = 100e6; // 100 USDT
    uint256 public constant PENALTY_PERCENTAGE = 10; // 10%

    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    event TaskCreated(uint256 indexed taskId, address indexed user, string description, uint256 deadline);
    event TaskCompleted(uint256 indexed taskId, address indexed user);
    event TokensStaked(address indexed user, uint256 amount);
    event TokensWithdrawn(address indexed user, uint256 amount);
    event PenaltyWithdrawn(address indexed owner, uint256 amount);
    event PenaltyApplied(uint256 indexed taskId, address indexed user, uint256 amount);

    function setUp() public {
        usdt = new MockUSDT();
        goalkeeper = new GoalKeeper(address(usdt));
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Fund users with USDT
        usdt.mint(user1, INITIAL_BALANCE);
        usdt.mint(user2, INITIAL_BALANCE);
    }

    function test_Deploy() public view {
        assertTrue(address(goalkeeper) != address(0));
        assertTrue(address(usdt) != address(0));
    }

    function test_StakeTokens() public {
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);

        vm.expectEmit(true, false, false, true);
        emit TokensStaked(user1, STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);

        assertEq(goalkeeper.getStakedBalance(user1), STAKE_AMOUNT);
        assertEq(usdt.balanceOf(address(goalkeeper)), STAKE_AMOUNT);
        vm.stopPrank();
    }

    function test_StakeTokens_InsufficientBalance() public {
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), INITIAL_BALANCE * 2);

        vm.expectRevert();
        goalkeeper.stakeTokens(INITIAL_BALANCE * 2);
        vm.stopPrank();
    }

    function test_StakeTokens_InsufficientAllowance() public {
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT - 1);

        vm.expectRevert();
        goalkeeper.stakeTokens(STAKE_AMOUNT);
        vm.stopPrank();
    }

    function test_CreateTask() public {
        string memory description = "Complete unit tests";
        uint256 deadline = block.timestamp + 1 days;

        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);

        goalkeeper.stakeTokens(STAKE_AMOUNT);
        vm.expectEmit(true, true, false, true);
        emit TaskCreated(1, user1, description, deadline);

        goalkeeper.createTask(description, deadline);

        uint256[] memory taskIds = goalkeeper.getTaskIds(user1);
        assertEq(taskIds.length, 1);
        assertEq(taskIds[0], 1);

        GoalKeeper.Task memory task = goalkeeper.getTaskDetails(taskIds[0]);
        assertEq(task.owner, user1);
        assertEq(task.description, description);
        assertEq(task.deadline, deadline);
        assertEq(task.isCompleted, false);
        assertEq(task.isPenalized, false);
        vm.stopPrank();
    }

    function test_CreateTask_PastDeadline() public {
        vm.startPrank(user1);
        vm.expectRevert("Deadline must be in future");
        goalkeeper.createTask("Test task", block.timestamp - 1);
        vm.stopPrank();
    }

    function test_CompleteTask() public {
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);

        uint256 deadline = block.timestamp + 1 days;
        goalkeeper.createTask("Complete unit tests", deadline);

        vm.expectEmit(true, true, false, false);
        emit TaskCompleted(1, user1);
        goalkeeper.completeTask(1);

        GoalKeeper.Task memory task = goalkeeper.getTaskDetails(1);
        assertTrue(task.isCompleted);
        vm.stopPrank();
    }

    function test_Revert_CompleteTask_NotOwner() public {
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);

        uint256 deadline = block.timestamp + 1 days;
        goalkeeper.createTask("Complete unit tests", deadline);
        vm.stopPrank();
        vm.prank(user2);
        vm.expectRevert("Not task owner");
        goalkeeper.completeTask(1);
    }

    function test_CompleteTask_AfterDeadline() public {
        vm.startPrank(user1);
        uint256 deadline = block.timestamp + 1 days;
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);

        goalkeeper.stakeTokens(STAKE_AMOUNT);

        goalkeeper.createTask("Complete unit tests", deadline);

        vm.warp(deadline + 1);
        vm.expectRevert("Deadline passed");
        goalkeeper.completeTask(1);
        vm.stopPrank();
    }

    function test_EvaluateTask() public {
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);

        uint256 deadline = block.timestamp + 1 days;
        goalkeeper.createTask("Complete unit tests", deadline);

        vm.warp(deadline + 1);

        vm.expectEmit(true, true, false, true);
        emit PenaltyApplied(1, user1, STAKE_AMOUNT / 10);
        goalkeeper.evaluateTask(1);

        assertEq(goalkeeper.getStakedBalance(user1), (STAKE_AMOUNT * 90) / 100);

        GoalKeeper.Task memory task = goalkeeper.getTaskDetails(1);
        assertTrue(task.isPenalized);
        vm.stopPrank();
    }

    function test_EvaluateTask_BeforeDeadline() public {
        vm.startPrank(user1);
        uint256 deadline = block.timestamp + 1 days;
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);
        goalkeeper.createTask("Complete unit tests", deadline);

        vm.expectRevert("Deadline not passed");
        goalkeeper.evaluateTask(1);
        vm.stopPrank();
    }

    function test_WithdrawTokens() public {
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);

        uint256 withdrawAmount = STAKE_AMOUNT / 2;
        vm.expectEmit(true, false, false, true);
        emit TokensWithdrawn(user1, withdrawAmount);
        goalkeeper.withdrawTokens(withdrawAmount);

        assertEq(goalkeeper.getStakedBalance(user1), STAKE_AMOUNT - withdrawAmount);
        assertEq(usdt.balanceOf(user1), INITIAL_BALANCE - STAKE_AMOUNT + withdrawAmount);
        vm.stopPrank();
    }

    function test_WithdrawTokens_InsufficientBalance() public {
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(GoalKeeper.GoalKeeper__InsufficientBalance.selector, STAKE_AMOUNT, STAKE_AMOUNT * 2)
        );
        goalkeeper.withdrawTokens(STAKE_AMOUNT * 2);
        vm.stopPrank();
    }

    function test_GetUserBalance() public {
        vm.startPrank(user1);
        assertEq(goalkeeper.getUserBalance(), 0);

        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);
        assertEq(goalkeeper.getUserBalance(), STAKE_AMOUNT);
        vm.stopPrank();
    }

    function test_GetTaskDetails_NonexistentTask() public view {
        GoalKeeper.Task memory task = goalkeeper.getTaskDetails(999);
        assertEq(task.id, 0);
        assertEq(task.owner, address(0));
        assertEq(task.description, "");
        assertEq(task.deadline, 0);
        assertEq(task.isCompleted, false);
        assertEq(task.isPenalized, false);
    }

    function test_SingleTaskPenalty() public {
        // User stakes tokens
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);

        // Create task
        uint256 deadline = block.timestamp + 1 days;
        goalkeeper.createTask("Test task", deadline);
        vm.stopPrank();

        // Advance time past deadline
        vm.warp(deadline + 1);

        // Evaluate the task (apply penalty)
        vm.expectEmit(true, true, false, true);
        emit PenaltyApplied(1, user1, (STAKE_AMOUNT * PENALTY_PERCENTAGE) / 100);
        goalkeeper.evaluateTask(1);

        // Check penalty balance (should be 10% of staked amount)
        uint256 expectedPenalty = (STAKE_AMOUNT * PENALTY_PERCENTAGE) / 100;
        assertEq(goalkeeper.getPenaltyBalance(), expectedPenalty);

        // Check user's remaining balance (should be 90% of staked amount)
        assertEq(goalkeeper.getStakedBalance(user1), STAKE_AMOUNT - expectedPenalty);
    }

    function test_MultipleTaskPenalties() public {
        // User stakes tokens
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
        vm.stopPrank();

        // Advance time past first deadline
        vm.warp(deadline1 + 1);

        // Evaluate first task - 10% penalty of original stake
        goalkeeper.evaluateTask(1);
        uint256 firstPenalty = (STAKE_AMOUNT * PENALTY_PERCENTAGE) / 100;
        assertEq(goalkeeper.getPenaltyBalance(), firstPenalty);

        // Remaining stake after first penalty
        uint256 remainingStake = STAKE_AMOUNT - firstPenalty;

        // Advance time past second deadline
        vm.warp(deadline2 + 1);

        // Evaluate second task - 10% penalty of remaining stake
        goalkeeper.evaluateTask(2);
        uint256 secondPenalty = (remainingStake * PENALTY_PERCENTAGE) / 100;
        assertEq(goalkeeper.getPenaltyBalance(), firstPenalty + secondPenalty);

        // Remaining stake after second penalty
        remainingStake = remainingStake - secondPenalty;

        // Advance time past third deadline
        vm.warp(deadline3 + 1);

        // Evaluate third task - 10% penalty of remaining stake
        goalkeeper.evaluateTask(3);
        uint256 thirdPenalty = (remainingStake * PENALTY_PERCENTAGE) / 100;
        assertEq(goalkeeper.getPenaltyBalance(), firstPenalty + secondPenalty + thirdPenalty);

        // Final user balance should be approximately 72.9% of original stake
        // (90% of 90% of 90% = 72.9%)
        uint256 expectedFinalBalance = STAKE_AMOUNT - (firstPenalty + secondPenalty + thirdPenalty);
        assertEq(goalkeeper.getStakedBalance(user1), expectedFinalBalance);
    }

    function test_PenaltyWithdrawal() public {
        // User stakes and fails a task
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);
        uint256 deadline = block.timestamp + 1 days;
        goalkeeper.createTask("Test task", deadline);
        vm.stopPrank();

        // Advance time and apply penalty
        vm.warp(deadline + 1);
        goalkeeper.evaluateTask(1);

        uint256 penaltyAmount = goalkeeper.getPenaltyBalance();

        // Owner withdraws penalty
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit PenaltyWithdrawn(owner, penaltyAmount);
        goalkeeper.withdrawPenalties(penaltyAmount);

        // Verify penalty balance is zero
        assertEq(goalkeeper.getPenaltyBalance(), 0);

        // Verify owner received the tokens

        assertEq(usdt.balanceOf(owner) - INITIAL_USDT_BALANCE, penaltyAmount);
        vm.stopPrank();
    }

    function test_EvaluateAllTasks() public {
        // User stakes tokens
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);

        // Create 2 tasks
        uint256 deadline1 = block.timestamp + 1 days;
        uint256 deadline2 = block.timestamp + 2 days;

        goalkeeper.createTask("Task 1", deadline1);
        goalkeeper.createTask("Task 2", deadline2);
        vm.stopPrank();

        // Advance time past both deadlines
        vm.warp(deadline2 + 1);

        // Withdraw tokens to trigger evaluateAllTasks
        vm.prank(user1);
        goalkeeper.withdrawTokens(0);

        // Calculate expected penalties
        uint256 firstPenalty = (STAKE_AMOUNT * PENALTY_PERCENTAGE) / 100;
        uint256 remainingAfterFirst = STAKE_AMOUNT - firstPenalty;
        uint256 secondPenalty = (remainingAfterFirst * PENALTY_PERCENTAGE) / 100;

        // Verify penalty balance
        assertEq(goalkeeper.getPenaltyBalance(), firstPenalty + secondPenalty);

        // Verify user's remaining balance
        assertEq(goalkeeper.getStakedBalance(user1), STAKE_AMOUNT - (firstPenalty + secondPenalty));
    }

    function test_CompleteAndFailMixedTasks() public {
        // User stakes tokens
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

        // Complete task 1 and 3
        goalkeeper.completeTask(1);
        goalkeeper.completeTask(3);
        vm.stopPrank();

        // Advance time past all deadlines
        vm.warp(deadline3 + 1);

        // Evaluate task 2 (should fail)
        goalkeeper.evaluateTask(2);

        // Only task 2 should have penalty (10% of original stake)
        uint256 expectedPenalty = (STAKE_AMOUNT * PENALTY_PERCENTAGE) / 100;
        assertEq(goalkeeper.getPenaltyBalance(), expectedPenalty);

        // User's balance should be 90% of original
        assertEq(goalkeeper.getStakedBalance(user1), STAKE_AMOUNT - expectedPenalty);
    }
}
