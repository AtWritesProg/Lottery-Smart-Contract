//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test,console2} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstant} from "../../script/HelperConfig.s.sol";

contract RaffleTest is CodeConstant,Test{
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER= makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    function setUp() external{
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle,helperConfig) = deployRaffle.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee=config.entranceFee;
        interval=config.interval;
        vrfCoordinator=config.vrfCoordinator;
        gasLane=config.gasLane;
        subscriptionId=config.subscriptionId;
        callbackGasLimit=config.callbackGasLimit;

        vm.deal(PLAYER,STARTING_BALANCE);

    }

    function testRaffleInitializesInOpenState() public view{
        assertTrue(raffle.getRaffleState()==Raffle.RaffleState.OPEN);
    }

    function testEnterRaffleRevertWhenNotEnoughETH() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughETHEntered.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public{
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayers(0) == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public{
        vm.prank(PLAYER);

        vm.expectEmit(true,false,false,false,address(raffle));
        emit RaffleEntered(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }
    function testCannotEnterRaffleWhenRaffleIsCalculating() public {
    // Player enters raffle
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();

    // Time passes
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);

    // Call upkeep to change state to CALCULATING
    raffle.performUpkeep("");

    // Now entering again should fail
    vm.expectRevert(Raffle.Raffle__NotOpen.selector);
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    }

    ////////////////////////// CHECK UPKEEP //////////////////////////

    function testUpkeepCheckReturnsFalseIfNoBalance() public{
        //THIS WILL RETURN TRUE AS LONG AS THE RAFFLE HAS BALANCE
        // vm.prank(PLAYER);
        // raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }
    function testUpkeepCheckReturnsFalseIfRaffleNotOpen() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        assert(!upKeepNeeded);

    }
    // testCheckUpKeepReturnsTrueIfAllConditionsMet
    //testUpkeepCheckReturnsFalseIfEnoughTimeHasntPassed

    function testUpkeepCheckReturnsFalseIfEnoughTimeHasntPassed() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();

        vm.warp(block.timestamp + interval -1);
        vm.roll(block.number + 1);

        (bool upKeepNeeded,)=raffle.checkUpkeep("");

        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsTrueIfAllConditionsMet() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upKeepNeeded,)= raffle.checkUpkeep("");
        assertTrue(upKeepNeeded);
    }
    
    /////////////////////////// PERFORM UPKEEP //////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfUpkeepNotNeeded() public{

        uint256 currentBalance =0;
        uint256 currentPlayers =0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        currentBalance+=entranceFee;
        currentPlayers+=1;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                currentPlayers,
                uint256(rState)
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered(){
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }
    function testPerformUpkeepUpdatesStateAndEmitsRequestId() public raffleEntered{
        // vm.prank(PLAYER);
        // raffle.enterRaffle{value:entranceFee}();
        // vm.warp(block.timestamp + interval + 1);
        // vm.roll(block.number + 1);

        //ACT
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];

        //ASSERT 
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId)>0);
        assert(uint256(raffleState) == 1);
    }

    /////////////////////////// FULFILL RANDOM WORDS //////////////////////////

    function testFulfillRandomWordsUpdatesStateAndEmitsWinner(uint256 randomRequestId) public raffleEntered {
        //ARRANGE
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

     modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }
    function testFulfillRandomWordsPicksAWinnerAndSendsMoney() public skipFork raffleEntered {
        uint256 additionalEntrances = 5;
        uint256 startingIndex = 1; // start at 1 because address(0) is invalid, and address(1) is expectedWinner
        address expectedWinner = address(uint160(1));

        // Add more players
        for (uint256 i = startingIndex; i < additionalEntrances; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");  // triggers randomness request

        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[1].topics[1]);
        bytes32 requestId = entries[1].topics[1];


        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address winner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(winner == expectedWinner);
        assert(uint256(raffleState) == 0);  // OPEN state after winner picked
        assert(endingTimeStamp > startingTimeStamp);
        assert(winner.balance == winnerStartingBalance + prize);
    }

}
