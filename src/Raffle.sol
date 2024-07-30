// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/*
 * @title A sample Raffle contract
 * @author Sameer Jain
 * @notice This contract is for creating a fiar lottery system
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /*
        Errors
        */
    error Raffle__SendMoreETHtoEnter();
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    uint256 private immutable i_interval; //Duration of the lottery in seconds

    uint256 private s_lastTimeStamp;
    /*
    Events
    */

    event RaffleEntered(address indexed player);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent!");
        if (!(msg.value >= i_entranceFee)) {
            revert Raffle__SendMoreETHtoEnter();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // Get a random number
    // Use random number to pick a player
    // Be automatically called

    function pickWinner() external view {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
        // generate a random number
        // 1. request rng
        // 2. get rng
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: enableNativePayment
                    })
                )
            })
        );
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal virtual override {}

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
