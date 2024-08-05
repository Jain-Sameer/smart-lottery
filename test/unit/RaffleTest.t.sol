// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {console} from "../../lib/forge-std/src/console.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant ENTRANCE_FEE = 1 ether;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane; // keyhash,
    uint256 subscriptionID;
    uint32 callbackGasLimit;
    uint256 private constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed s_recentWinner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionID = config.subscriptionID;
        callbackGasLimit = config.callbackGasLimit;
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleIsInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        //arrange
        vm.prank(PLAYER);

        //act / assert
        vm.expectRevert(Raffle.Raffle__SendMoreETHtoEnter.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayers(0);

        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        //vm.warp and vm.roll are some   more foundry cheatcodes
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating()
        public
        raffleEntered
    {
        raffle.performUpKeep(""); // <- issue here!

        //act
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                             CHECK UP KEEP
    //////////////////////////////////////////////////////////////*/
    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        //arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //act
        (bool upkeepneed, ) = raffle.checkUpKeep("");
        assert(!upkeepneed);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public raffleEntered {
        raffle.performUpKeep("");

        (bool upkeedNeeded, ) = raffle.checkUpKeep("");

        assert(!upkeedNeeded);
    }

    // testcheckupreturnsfalseifenoughtime has passed
    // test checkupkeep returns trie when parameters are good

    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testperformupkeedcanonlyrunifcheckupkeepisTrue()
        public
        raffleEntered
    {
        //act
        raffle.performUpKeep("");
    }

    function testPerformUpkeedRevertsIfCheckUpkeedIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rstate = raffle.getRaffleState();
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        //act // assert
        currentBalance += entranceFee;
        numPlayers = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rstate
            )
        );
        raffle.performUpKeep("");
    }

    function testPerformUpkeepUpdateRaffleStatesandEmitsRequestID()
        public
        raffleEntered
    {
        //act

        //foundry cheatcode vm.recordlogs();

        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        //assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /*//////////////////////////////////////////////////////////////
                          FULFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////*/
    // first ever stateless tests of mine
    // basic fuzz test
    function testFulFillrandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestID
    ) public raffleEntered skipFork {
        //arange
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestID,
            address(raffle)
        );
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFulfillRandomsWordsPicksWinnerResetsandSendsMoney()
        public
        raffleEntered
        skipFork
    {
        //arrange

        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimestamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //assert
        address recentWinner = raffle.getRecentWinnner();

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalannce = recentWinner.balance;
        uint256 endingTimestamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        console.log(winnerBalannce, winnerStartingBalance, prize);
        assert(winnerBalannce == winnerStartingBalance + prize);
        assert(endingTimestamp > startingTimestamp);
    }
}
