// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public {
        deployRaffle();
    }

    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionID == 0) {
            //create subscription
            CreateSubscription createSub = new CreateSubscription();
            (config.subscriptionID, config.vrfCoordinator) = createSub
                .createSubscription(config.vrfCoordinator, config.account);

            //funding subscription

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator,
                config.subscriptionID,
                config.linkTokenAddress,
                config.account
            );
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionID,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addconsumer = new AddConsumer();
        addconsumer.addConsumer(
            address(raffle),
            config.vrfCoordinator,
            config.subscriptionID,
            config.account
        );
        return (raffle, helperConfig);
    }
}
