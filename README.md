# **Token-Based Goal Tracker with Rewards and Penalties (USDT Staking)**

## **Overview**

The **Token-Based Goal Tracker** is a decentralized application built using Ethereum smart contracts. This system incentivizes positive behavior (completing tasks, goals, or homework) by allowing users to stake **USDT (Tether)** tokens. If tasks are completed successfully, users keep their staked USDT tokens; however, if tasks are not completed, they lose a set amount of tokens as a penalty. This smart contract system is designed to help you stay motivated and focused by tracking your progress in real-time.

## **Key Features**

- **Stake USDT Tokens**: Start with a base stake (e.g., 100 USDT) to commit to completing a set of tasks or goals.
- **Track Task Completion**: Log and track your tasks, such as homework, exercises, or productivity goals.
- **Penalty for Failure**: If you fail to complete a task, you lose tokens (e.g., -10 USDT).
- **Reward for Success**: If you successfully complete your task, you keep your staked USDT tokens.
- **Goal Tracking**: Set multiple goals with different reward/penalty conditions.
- **Decentralized**: Fully trustless and transparent using blockchain technology.

## **How it Works**

1. **Stake USDT Tokens**:
   - When you start, you stake a certain amount of USDT (e.g., 100 USDT) in the contract.
2. **Set a Task**:

   - Define a task (e.g., "Complete Homework by 6 PM").
   - Set deadlines or timeframes for when the task should be completed.

3. **Task Completion**:

   - If you complete the task (e.g., submitting homework on time), you keep your staked USDT tokens.
   - If you fail to complete the task, the contract deducts a penalty from your staked USDT tokens (e.g., -10 USDT).

4. **Track Goals and Penalties**:

   - The contract logs your task completion and updates your balance based on success or failure.
   - You can check your token balance anytime to see how much you have left.

5. **Consistency Bonuses** (Optional):
   - Completing all tasks within a week or month can unlock a bonus reward (e.g., 10% more USDT).

## **How to Use the Contract**

### **1. Staking USDT Tokens**

First, you’ll need to stake your USDT tokens into the contract:

```solidity
stakeUSDT(uint256 _amount);
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```
