// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GoalKeeper {
    error GoalKeeper__InsufficientAllowance(uint256 available, uint256 required);
    error GoalKeeper__InsufficientBalance(uint256 available, uint256 required);
    error GoalKeeper__NoStakedTokens(address user);
    error GoalKeeper__OnlyOwner();
    error GoalKeeper__TransferFailed();
    error GoalKeeper__InsufficientPenaltyBalance(uint256 available, uint256 required);

    struct Task {
        uint256 id;
        address owner;
        string description;
        uint256 deadline;
        bool isCompleted;
        bool isPenalized;
    }

    event TaskCreated(uint256 indexed taskId, address indexed user, string description, uint256 deadline);
    event TaskCompleted(uint256 indexed taskId, address indexed user);
    event PenaltyApplied(uint256 indexed taskId, address indexed user, uint256 amount);
    event TokensStaked(address indexed user, uint256 amount);
    event TokensWithdrawn(address indexed user, uint256 amount);
    event PenaltyWithdrawn(address indexed owner, uint256 amount);

    uint256 private taskIdCounter = 1;
    mapping(uint256 => Task) private tasks;
    mapping(address => uint256[]) private userTaskIds;
    mapping(address => uint256) private s_stakedTokens;

    // Contract owner and accumulated penalties
    address private immutable i_owner;
    uint256 private s_penaltyBalance;

    // Penalty percentage (10% or 10/100)
    uint256 private constant PENALTY_PERCENTAGE = 10;

    IERC20 private immutable usdt;

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert GoalKeeper__OnlyOwner();
        }
        _;
    }

    constructor(address _usdt) {
        usdt = IERC20(_usdt);
        i_owner = msg.sender;
        s_penaltyBalance = 0;
    }

    function stakeTokens(uint256 _amount) public {
        uint256 userBalance = usdt.balanceOf(msg.sender);
        if (userBalance < _amount) {
            revert GoalKeeper__InsufficientBalance(userBalance, _amount);
        }

        uint256 allowance = usdt.allowance(msg.sender, address(this));
        if (allowance < _amount) {
            revert GoalKeeper__InsufficientAllowance(allowance, _amount);
        }

        bool succuss = usdt.transferFrom(msg.sender, address(this), _amount);
        if (!succuss) {
            revert GoalKeeper__TransferFailed();
        }
        s_stakedTokens[msg.sender] += _amount;

        emit TokensStaked(msg.sender, _amount);
    }

    function createTask(string memory _description, uint256 _deadline) public {
        require(_deadline > block.timestamp, "Deadline must be in future");
        if (getStakedBalance(msg.sender) == 0) {
            revert GoalKeeper__NoStakedTokens(msg.sender);
        }
        uint256 taskId = taskIdCounter++;
        tasks[taskId] = Task({
            id: taskId,
            owner: msg.sender,
            description: _description,
            deadline: _deadline,
            isCompleted: false,
            isPenalized: false
        });

        userTaskIds[msg.sender].push(taskId);
        emit TaskCreated(taskId, msg.sender, _description, _deadline);
    }

    function completeTask(uint256 _taskId) public {
        Task storage task = tasks[_taskId];
        require(task.owner == msg.sender, "Not task owner");
        require(block.timestamp <= task.deadline, "Deadline passed");
        require(!task.isCompleted, "Task completed");
        require(!task.isPenalized, "Task penalized");

        task.isCompleted = true;
        emit TaskCompleted(_taskId, msg.sender);
    }

    function calculatePenalty(address _user) private view returns (uint256) {
        // Flat 10% penalty of user's current staked tokens
        uint256 stakedAmount = s_stakedTokens[_user];
        return (stakedAmount * PENALTY_PERCENTAGE) / 100;
    }

    function evaluateTask(uint256 _taskId) public {
        Task storage task = tasks[_taskId];
        require(block.timestamp > task.deadline, "Deadline not passed");
        require(!task.isCompleted, "Task completed");
        require(!task.isPenalized, "Penalty applied");

        address owner = task.owner;
        uint256 penalty = calculatePenalty(owner);

        if (s_stakedTokens[owner] >= penalty) {
            s_stakedTokens[owner] -= penalty;
        } else {
            penalty = s_stakedTokens[owner];
            s_stakedTokens[owner] = 0;
        }

        task.isPenalized = true;
        s_penaltyBalance += penalty; // Add penalty to penalty balance
        emit PenaltyApplied(_taskId, owner, penalty);
    }

    function withdrawTokens(uint256 _amount) public {
        evaluateAllTasks(msg.sender);

        if (s_stakedTokens[msg.sender] < _amount) {
            revert GoalKeeper__InsufficientBalance(s_stakedTokens[msg.sender], _amount);
        }

        s_stakedTokens[msg.sender] -= _amount;
        bool succuss = usdt.transfer(msg.sender, _amount);
        if (!succuss) {
            revert GoalKeeper__TransferFailed();
        }
        emit TokensWithdrawn(msg.sender, _amount);
    }

    function withdrawPenalties(uint256 _amount) public onlyOwner {
        if (s_penaltyBalance < _amount) {
            revert GoalKeeper__InsufficientPenaltyBalance(s_penaltyBalance, _amount);
        }

        s_penaltyBalance -= _amount;
        bool succuss = usdt.transfer(i_owner, _amount);
        if (!succuss) {
            revert GoalKeeper__TransferFailed();
        }
        emit PenaltyWithdrawn(i_owner, _amount);
    }

    function getUserBalance() public view returns (uint256) {
        return s_stakedTokens[msg.sender];
    }

    function getStakedBalance(address _user) public view returns (uint256) {
        return s_stakedTokens[_user];
    }

    function getTaskIds(address _user) public view returns (uint256[] memory) {
        return userTaskIds[_user];
    }

    function getTaskDetails(uint256 _taskId) public view returns (Task memory) {
        return tasks[_taskId];
    }

    function getPenaltyBalance() public view returns (uint256) {
        return s_penaltyBalance;
    }

    function getContractOwner() public view returns (address) {
        return i_owner;
    }

    function getPenaltyPercentage() public pure returns (uint256) {
        return PENALTY_PERCENTAGE;
    }

    function evaluateAllTasks(address _user) private {
        uint256[] memory taskIds = userTaskIds[_user];

        for (uint256 i = 0; i < taskIds.length; i++) {
            Task storage task = tasks[taskIds[i]];
            if (block.timestamp > task.deadline && !task.isCompleted && !task.isPenalized) {
                // Calculate 10% penalty for each failed task
                uint256 penaltyAmount = (s_stakedTokens[_user] * PENALTY_PERCENTAGE) / 100;

                if (s_stakedTokens[_user] >= penaltyAmount) {
                    s_stakedTokens[_user] -= penaltyAmount;
                    s_penaltyBalance += penaltyAmount; // Add penalty to penalty balance
                } else {
                    penaltyAmount = s_stakedTokens[_user];
                    s_stakedTokens[_user] = 0;
                    s_penaltyBalance += penaltyAmount; // Add penalty to penalty balance
                }

                task.isPenalized = true;
                emit PenaltyApplied(task.id, _user, penaltyAmount);
            }
        }
    }
}
