// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {GoalKeeper} from "../src/GoalKeeper.sol";

contract GoalKeeperScript is Script {
    GoalKeeper public goalKeeper;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        goalKeeper = new GoalKeeper();

        vm.stopBroadcast();
    }
}
