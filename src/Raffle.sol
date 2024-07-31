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

import {VRFConsumerBaseV2Plus} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

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
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle_UpkeepNotNeeded(uint256 balance, uint256 playerslength, uint256 raffleState);

    /**
     * Type Declarations
     */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    uint256 private immutable i_interval; //Duration of the lottery in seconds
    bytes32 private immutable i_keyHash;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_subscriptionID;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    address private s_recentWinner;
    RaffleState private s_raffleState;
    /**
     * Events
     */

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed s_recentWinner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane, // keyhash,
        uint256 subscriptionID,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionID = subscriptionID;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        // s_vrfCoordinator.requestRandomWords();
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent!");
        if (!(msg.value >= i_entranceFee)) {
            revert Raffle__SendMoreETHtoEnter();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function checkUpKeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upKeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance == 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;

        return (upKeepNeeded, "");
    }

    // Get a random number
    // Use random number to pick a player
    // Be automatically called
    // we can use chainlink automation to atuomate this function
    function performUpKeep(bytes calldata /* performData */ ) external {
        (bool upKeedNeed,) = checkUpKeep("");
        if (!upKeedNeed) {
            revert Raffle_UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;
        // generate a random number
        // 1. request rng
        // 2. get rng
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionID,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        s_vrfCoordinator.requestRandomWords(request);
    }

    // CEI : Checks, Effects, Interactions Pattern
    function fulfillRandomWords(uint256, /* requestID */ uint256[] calldata randomWords) internal virtual override {
        /**
         * Checks
         */

        /**
         * Effects -> updating state variables accordingly
         */
        uint256 indexOFWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOFWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success,) = recentWinner.call{value: address(this).balance}("");
        emit WinnerPicked(s_recentWinner);

        /**
         * Interactions -> External Contract Interactions
         */
        if (!(success)) {
            revert Raffle__TransferFailed();
        }
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }
}
