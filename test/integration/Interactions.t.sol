// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployRaffle} from "..//../script/DeployRaffle.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/DeployRaffle.s.sol";

contract InteractionsTest {
    address USER = makeAddr("TEST");
    Raffle public raffle;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        raffle = deployRaffle.run();
        vm.deal(USER, 10 ether);
    }
}
