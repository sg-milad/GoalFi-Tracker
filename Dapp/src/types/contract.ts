export interface Task {
  owner: string;
  deadline: bigint;
  isCompleted: boolean;
  isPenalized: boolean;
  description: string;
}

export interface ContractError {
  code: string;
  message: string;
}

export const CONTRACT_ABI = [
  {
    "inputs": [{ "internalType": "address", "name": "_usdt", "type": "address" }],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [],
    "name": "GoalKeeper__DeadlineMustBeInFuture",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "GoalKeeper__DeadlineNotPassed",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "GoalKeeper__DeadlinePassed",
    "type": "error"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "available", "type": "uint256" },
      { "internalType": "uint256", "name": "required", "type": "uint256" }
    ],
    "name": "GoalKeeper__InsufficientBalance",
    "type": "error"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "available", "type": "uint256" },
      { "internalType": "uint256", "name": "required", "type": "uint256" }
    ],
    "name": "GoalKeeper__InsufficientPenaltyBalance",
    "type": "error"
  },
  {
    "inputs": [{ "internalType": "address", "name": "user", "type": "address" }],
    "name": "GoalKeeper__NoStakedTokens",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "GoalKeeper__NotTaskOwner",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "GoalKeeper__OnlyOwner",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "GoalKeeper__TaskCompleted",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "GoalKeeper__TaskPenalized",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "GoalKeeper__TransferFailed",
    "type": "error"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "taskId", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "user", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256" }
    ],
    "name": "PenaltyApplied",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "owner", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256" }
    ],
    "name": "PenaltyWithdrawn",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "taskId", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "user", "type": "address" }
    ],
    "name": "TaskCompleted",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "taskId", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "user", "type": "address" },
      { "indexed": false, "internalType": "string", "name": "description", "type": "string" },
      { "indexed": false, "internalType": "uint256", "name": "deadline", "type": "uint256" }
    ],
    "name": "TaskCreated",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "user", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256" }
    ],
    "name": "TokensStaked",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "address", "name": "user", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256" }
    ],
    "name": "TokensWithdrawn",
    "type": "event"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "_taskId", "type": "uint256" }],
    "name": "completeTask",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "string", "name": "_description", "type": "string" },
      { "internalType": "uint256", "name": "_deadline", "type": "uint256" }
    ],
    "name": "createTask",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "_taskId", "type": "uint256" }],
    "name": "evaluateTask",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getContractOwner",
    "outputs": [{ "internalType": "address", "name": "", "type": "address" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getPenaltyBalance",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getPenaltyPercentage",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "pure",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "address", "name": "_user", "type": "address" }],
    "name": "getStakedBalance",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "_taskId", "type": "uint256" }],
    "name": "getTaskDetails",
    "outputs": [{
      "components": [
        { "internalType": "address", "name": "owner", "type": "address" },
        { "internalType": "uint256", "name": "deadline", "type": "uint256" },
        { "internalType": "bool", "name": "isCompleted", "type": "bool" },
        { "internalType": "bool", "name": "isPenalized", "type": "bool" },
        { "internalType": "string", "name": "description", "type": "string" }
      ],
      "internalType": "struct GoalKeeper.Task",
      "name": "",
      "type": "tuple"
    }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "address", "name": "_user", "type": "address" }],
    "name": "getTaskIds",
    "outputs": [{ "internalType": "uint256[]", "name": "", "type": "uint256[]" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getUserBalance",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "_amount", "type": "uint256" }],
    "name": "stakeTokens",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "_amount", "type": "uint256" }],
    "name": "withdrawPenalties",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint256", "name": "_amount", "type": "uint256" }],
    "name": "withdrawTokens",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

export const USDT_ABI = [
  {
    "constant": true,
    "inputs": [{ "name": "_owner", "type": "address" }],
    "name": "balanceOf",
    "outputs": [{ "name": "balance", "type": "uint256" }],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      { "name": "_spender", "type": "address" },
      { "name": "_value", "type": "uint256" }
    ],
    "name": "approve",
    "outputs": [{ "name": "", "type": "bool" }],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      { "name": "_owner", "type": "address" },
      { "name": "_spender", "type": "address" }
    ],
    "name": "allowance",
    "outputs": [{ "name": "", "type": "uint256" }],
    "type": "function"
  }
];