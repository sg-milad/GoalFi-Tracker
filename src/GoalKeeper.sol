// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GoalKeeper
 * @notice A contract that helps users commit to tasks by staking tokens
 * @dev Users stake tokens and create tasks with deadlines. If tasks aren't completed
 *      by deadline, a penalty is applied to their stake.
 */
contract GoalKeeper {
    // Custom errors
    error GoalKeeper__InsufficientBalance(uint256 available, uint256 required);
    error GoalKeeper__NoStakedTokens(address user);
    error GoalKeeper__OnlyOwner();
    error GoalKeeper__TransferFailed();
    error GoalKeeper__InsufficientPenaltyBalance(uint256 available, uint256 required);
    error GoalKeeper__NotTaskOwner();
    error GoalKeeper__DeadlinePassed();
    error GoalKeeper__DeadlineNotPassed();
    error GoalKeeper__TaskCompleted();
    error GoalKeeper__TaskPenalized();
    error GoalKeeper__DeadlineMustBeInFuture();

    struct Task {
        address owner;
        uint256 deadline;
        bool isCompleted;
        bool isPenalized;
        string description;
    }

    // Events
    event TaskCreated(uint256 indexed taskId, address indexed user, string description, uint256 deadline);
    event TaskCompleted(uint256 indexed taskId, address indexed user);
    event PenaltyApplied(uint256 indexed taskId, address indexed user, uint256 amount);
    event TokensStaked(address indexed user, uint256 amount);
    event TokensWithdrawn(address indexed user, uint256 amount);
    event PenaltyWithdrawn(address indexed owner, uint256 amount);

    // State variables
    uint256 private taskIdCounter = 1;
    mapping(uint256 taskId => Task) private tasks;
    mapping(address => uint256[]) private userTaskIds;
    mapping(address => uint256) private s_stakedTokens;

    // Contract owner and accumulated penalties
    address private immutable i_owner;
    uint256 private s_penaltyBalance;

    // Penalty percentage (10% or 10/100)
    uint256 private constant PENALTY_PERCENTAGE = 10;

    IERC20 private immutable i_usdt;

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert GoalKeeper__OnlyOwner();
        }
        _;
    }

    constructor(address _usdt) {
        if (_usdt == address(0)) revert GoalKeeper__TransferFailed();
        i_usdt = IERC20(_usdt);
        i_owner = msg.sender;
    }

    /**
     * @notice Stake tokens to the contract
     * @param _amount Amount of tokens to stake
     */
    function stakeTokens(uint256 _amount) external {
        if (_amount == 0) revert GoalKeeper__InsufficientBalance(0, 1);

        // Using SafeERC20 pattern without the library
        uint256 balanceBefore = i_usdt.balanceOf(address(this));
        bool success = i_usdt.transferFrom(msg.sender, address(this), _amount);
        if (!success || i_usdt.balanceOf(address(this)) - balanceBefore < _amount) {
            revert GoalKeeper__TransferFailed();
        }

        s_stakedTokens[msg.sender] += _amount;
        emit TokensStaked(msg.sender, _amount);
    }

    /**
     * @notice Create a new task with a deadline
     * @param _description Description of the task
     * @param _deadline Timestamp when the task must be completed
     */
    function createTask(string calldata _description, uint256 _deadline) external {
        if (_deadline <= block.timestamp) {
            revert GoalKeeper__DeadlineMustBeInFuture();
        }
        if (s_stakedTokens[msg.sender] == 0) {
            revert GoalKeeper__NoStakedTokens(msg.sender);
        }

        uint256 taskId = taskIdCounter++;
        tasks[taskId] = Task({
            owner: msg.sender,
            description: _description,
            deadline: _deadline,
            isCompleted: false,
            isPenalized: false
        });

        userTaskIds[msg.sender].push(taskId);
        emit TaskCreated(taskId, msg.sender, _description, _deadline);
    }

    /**
     * @notice Mark a task as completed
     * @param _taskId ID of the task to complete
     */
    function completeTask(uint256 _taskId) external {
        Task storage task = tasks[_taskId];

        if (task.owner != msg.sender) revert GoalKeeper__NotTaskOwner();
        if (block.timestamp > task.deadline) revert GoalKeeper__DeadlinePassed();
        if (task.isCompleted) revert GoalKeeper__TaskCompleted();
        if (task.isPenalized) revert GoalKeeper__TaskPenalized();

        task.isCompleted = true;
        emit TaskCompleted(_taskId, msg.sender);
    }

    /**
     * @notice Apply penalty for an incomplete task after deadline
     * @param _taskId ID of the task to evaluate
     */
    function evaluateTask(uint256 _taskId) external {
        Task storage task = tasks[_taskId];

        if (block.timestamp <= task.deadline) revert GoalKeeper__DeadlineNotPassed();
        if (task.isCompleted) revert GoalKeeper__TaskCompleted();
        if (task.isPenalized) revert GoalKeeper__TaskPenalized();

        address owner = task.owner;
        uint256 penalty = (s_stakedTokens[owner] * PENALTY_PERCENTAGE) / 100;

        // Take what we can, up to the full penalty amount
        uint256 actualPenalty = penalty <= s_stakedTokens[owner] ? penalty : s_stakedTokens[owner];
        s_stakedTokens[owner] -= actualPenalty;
        s_penaltyBalance += actualPenalty;

        task.isPenalized = true;
        emit PenaltyApplied(_taskId, owner, actualPenalty);
    }

    /**
     * @notice Withdraw staked tokens, evaluating all pending tasks first
     * @param _amount Amount of tokens to withdraw
     */
    function withdrawTokens(uint256 _amount) external {
        _evaluateAllTasks(msg.sender);

        if (s_stakedTokens[msg.sender] < _amount) {
            revert GoalKeeper__InsufficientBalance(s_stakedTokens[msg.sender], _amount);
        }

        s_stakedTokens[msg.sender] -= _amount;

        // Using SafeERC20 pattern without the library
        uint256 balanceBefore = i_usdt.balanceOf(msg.sender);
        bool success = i_usdt.transfer(msg.sender, _amount);
        if (!success || i_usdt.balanceOf(msg.sender) - balanceBefore < _amount) {
            revert GoalKeeper__TransferFailed();
        }

        emit TokensWithdrawn(msg.sender, _amount);
    }

    /**
     * @notice Allow owner to withdraw accumulated penalties
     * @param _amount Amount of penalties to withdraw
     */
    function withdrawPenalties(uint256 _amount) external onlyOwner {
        if (s_penaltyBalance < _amount) {
            revert GoalKeeper__InsufficientPenaltyBalance(s_penaltyBalance, _amount);
        }

        s_penaltyBalance -= _amount;

        // Using SafeERC20 pattern without the library
        uint256 balanceBefore = i_usdt.balanceOf(i_owner);
        bool success = i_usdt.transfer(i_owner, _amount);
        if (!success || i_usdt.balanceOf(i_owner) - balanceBefore < _amount) {
            revert GoalKeeper__TransferFailed();
        }

        emit PenaltyWithdrawn(i_owner, _amount);
    }

    /**
     * @notice Evaluate all tasks for a user and apply penalties if needed
     * @param _user Address of the user
     */
    function _evaluateAllTasks(address _user) private {
        uint256[] memory taskIds = userTaskIds[_user];
        uint256 totalPenalty = 0;

        for (uint256 i = 0; i < taskIds.length; i++) {
            Task storage task = tasks[taskIds[i]];
            if (block.timestamp > task.deadline && !task.isCompleted && !task.isPenalized) {
                task.isPenalized = true;

                // Calculate 10% penalty for this task
                uint256 penaltyForTask = (s_stakedTokens[_user] * PENALTY_PERCENTAGE) / 100;

                // Track total penalties to apply once at the end
                totalPenalty += penaltyForTask;

                emit PenaltyApplied(taskIds[i], _user, penaltyForTask);
            }
        }

        // Apply all penalties at once to save gas
        if (totalPenalty > 0) {
            // Take what we can, up to the full penalty amount
            uint256 actualTotalPenalty = totalPenalty <= s_stakedTokens[_user] ? totalPenalty : s_stakedTokens[_user];

            s_stakedTokens[_user] -= actualTotalPenalty;
            s_penaltyBalance += actualTotalPenalty;
        }
    }

    // View functions

    /**
     * @notice Get the current staked balance of the caller
     * @return Current staked balance
     */
    function getUserBalance() external view returns (uint256) {
        return s_stakedTokens[msg.sender];
    }

    /**
     * @notice Get the staked balance of any user
     * @param _user Address of the user
     * @return Staked balance of the user
     */
    function getStakedBalance(address _user) external view returns (uint256) {
        return s_stakedTokens[_user];
    }

    /**
     * @notice Get all task IDs for a user
     * @param _user Address of the user
     * @return Array of task IDs
     */
    function getTaskIds(address _user) external view returns (uint256[] memory) {
        return userTaskIds[_user];
    }

    /**
     * @notice Get details of a specific task
     * @param _taskId ID of the task
     * @return Task details
     */
    function getTaskDetails(uint256 _taskId) external view returns (Task memory) {
        return tasks[_taskId];
    }

    /**
     * @notice Get the current balance of accumulated penalties
     * @return Current penalty balance
     */
    function getPenaltyBalance() external view returns (uint256) {
        return s_penaltyBalance;
    }

    /**
     * @notice Get the contract owner address
     * @return Address of the contract owner
     */
    function getContractOwner() external view returns (address) {
        return i_owner;
    }

    /**
     * @notice Get the penalty percentage
     * @return Penalty percentage
     */
    function getPenaltyPercentage() external pure returns (uint256) {
        return PENALTY_PERCENTAGE;
    }
}
