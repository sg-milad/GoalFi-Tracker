// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, Vm} from "forge-std/Test.sol";
import {GoalKeeper} from "../src/GoalKeeper.sol";
import {MockUSDT} from "./mock/MockUSDT.sol";

contract GoalKeeperTest is Test {
    GoalKeeper public goalkeeper;
    MockUSDT public usdt;

    address public user1;
    address public user2;

    uint256 public constant INITIAL_BALANCE = 1000e6; // 1000 USDT
    uint256 public constant STAKE_AMOUNT = 100e6; // 100 USDT

    event TaskCreated(
        uint256 indexed taskId,
        address indexed user,
        string description,
        uint256 deadline
    );
    event TaskCompleted(uint256 indexed taskId, address indexed user);
    event PenaltyApplied(
        uint256 indexed taskId,
        address indexed user,
        uint256 amount
    );
    event TokensStaked(address indexed user, uint256 amount);
    event TokensWithdrawn(address indexed user, uint256 amount);

    function setUp() public {
        usdt = new MockUSDT();
        goalkeeper = new GoalKeeper(address(usdt));

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

        vm.expectRevert(
            abi.encodeWithSelector(
                GoalKeeper.GoalKeeper__InsufficientBalance.selector,
                INITIAL_BALANCE,
                INITIAL_BALANCE * 2
            )
        );
        goalkeeper.stakeTokens(INITIAL_BALANCE * 2);
        vm.stopPrank();
    }

    function test_StakeTokens_InsufficientAllowance() public {
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                GoalKeeper.GoalKeeper__InsufficientAllowance.selector,
                STAKE_AMOUNT - 1,
                STAKE_AMOUNT
            )
        );
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

    function testFail_CompleteTask_NotOwner() public {
        vm.prank(user1);
        uint256 deadline = block.timestamp + 1 days;
        goalkeeper.createTask("Complete unit tests", deadline);

        vm.prank(user2);
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

        assertEq(
            goalkeeper.getStakedBalance(user1),
            STAKE_AMOUNT - withdrawAmount
        );
        assertEq(
            usdt.balanceOf(user1),
            INITIAL_BALANCE - STAKE_AMOUNT + withdrawAmount
        );
        vm.stopPrank();
    }

    function test_WithdrawTokens_InsufficientBalance() public {
        vm.startPrank(user1);
        usdt.approve(address(goalkeeper), STAKE_AMOUNT);
        goalkeeper.stakeTokens(STAKE_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                GoalKeeper.GoalKeeper__InsufficientBalance.selector,
                STAKE_AMOUNT,
                STAKE_AMOUNT * 2
            )
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
}
