// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract GoalKeeper {
    mapping(address => uint256) private s_stakedTokens;

    function stakeTokens(uint256 _amount) public {
        s_stakedTokens[msg.sender] += _amount;
    }

    function getUserBalance() public view returns (uint256) {
        return s_stakedTokens[msg.sender];
    }
}
