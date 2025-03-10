// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {GoalKeeper} from "../src/GoalKeeper.sol";
import {MockUSDT} from "./../test/mock/MockUSDT.sol";

contract GoalKeeperScript is Script {
    GoalKeeper public goalKeeper;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    // uint256 public constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;

    uint256 public constant LOCAL_CHAIN_ID = 31337;
    MockUSDT public mockUsdt;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        if (block.chainid == LOCAL_CHAIN_ID) {
            mockUsdt = new MockUSDT();
        } else if (block.chainid == ETH_SEPOLIA_CHAIN_ID) {
            mockUsdt = MockUSDT(0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0);
        }
        goalKeeper = new GoalKeeper(address(mockUsdt));
        console.log(address(mockUsdt));
        console.log(address(goalKeeper));

        vm.stopBroadcast();
    }
}
