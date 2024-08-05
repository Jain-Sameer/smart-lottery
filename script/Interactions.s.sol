// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script, CodeConstants {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        //create subscription
        (uint256 subId, ) = createSubscription(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        console.log("creating sub on chain id: ", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console.log("ur sub id is :", subId);
        console.log("please update the sub id in your HelperConfig.s.sol");

        return (subId, vrfCoordinator);
    }

    function run() public {
        // create subscription
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subID = helperConfig.getConfig().subscriptionID;
        address linkToken = helperConfig.getConfig().linkTokenAddress;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subID, linkToken, account);
    }

    function fundSubscription(
        address vrfcoordinator,
        uint256 subID,
        address linkToken,
        address account
    ) public {
        console.log("Funding Subscription : ", subID);
        console.log("Using VRF Coordinator : ", vrfcoordinator);
        console.log("On chainID : ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfcoordinator).fundSubscription(
                subID,
                FUND_AMOUNT * 100
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(
                vrfcoordinator,
                FUND_AMOUNT,
                abi.encode(subID)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subID = helperConfig.getConfig().subscriptionID;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;

        addConsumer(mostRecentlyDeployed, vrfCoordinator, subID, account);
    }

    function addConsumer(
        address contractToAddToVrf,
        address vrfCoordinator,
        uint256 subID,
        address account
    ) public {
        console.log("Adding consumer to VRF Coordinator: ", contractToAddToVrf);
        console.log("to VRF Coordinator: ", vrfCoordinator);
        console.log("On chainid: ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subID,
            contractToAddToVrf
        );
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
