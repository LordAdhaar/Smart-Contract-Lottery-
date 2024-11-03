//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig.NetworkConfig public activeNetwork;

    address public USER = makeAddr("Adhaar");
    uint256 public constant STARTING_USER_BALANCE = 1000 ether;
    uint256 public constant GAS_PRICE = 1;

    uint256 public raffleTicketPrice;
    uint256 public interval;
    uint256 public subscriptionId;
    uint32 public callbackGasLimit;
    address public vrfCoordinator;
    bytes32 public keyHash;

    function setUp() public {
        vm.deal(USER, STARTING_USER_BALANCE);

        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, activeNetwork) = deployRaffle.deployContract();

        raffleTicketPrice = activeNetwork.raffleTicketPrice;
        interval = activeNetwork.interval;
        subscriptionId = activeNetwork.subscriptionId;
        callbackGasLimit = activeNetwork.callbackGasLimit;
        vrfCoordinator = activeNetwork.vrfCoordinator;
        keyHash = activeNetwork.keyHash;
    }

    function testRaffleInitialStateIsOpen() public view {
        assertEq(uint8(raffle.getRaffleState()), 0);
    }

    function testContractRevertWhenNotEnoughETHSent() public {
        vm.prank(USER);
        vm.expectRevert(Raffle.Raffle__SendMoreETHToEnterRaffle.selector);
        raffle.enterRaffle{value: 0.0001 ether}();
    }

    function testEnterRaffle() public {
        //ARRANGE > ACT > ASSERT
        vm.prank(USER);
        raffle.enterRaffle{value: raffleTicketPrice}();

        address payable[] memory players = raffle.getPlayers();

        assert(players.length == 1);
        assert(players[0] == USER);
    }

    function testPlayerEnteredRaffleEvent() public {
        vm.prank(USER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.PlayerEnteredRaffle(makeAddr("Adhaar"));
        raffle.enterRaffle{value: 10 ether}();
    }

    function testPlayerCannotEnterWhenRaffleIsCalculating() public {
        vm.prank(USER);
        raffle.enterRaffle{value: raffleTicketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(USER);
        raffle.enterRaffle{value: raffleTicketPrice}();
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        //arrange//act//asssert
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsFalseItIsNotOpen() public {
        vm.prank(USER);
        raffle.enterRaffle{value: raffleTicketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assertEq(upkeepNeeded, false);
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 balance = address(raffle).balance;
        uint256 numPlayers = raffle.getPlayers().length;
        uint256 raffleState = uint256(raffle.getRaffleState());

        // Expect revert with the specific error and its parameters
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                balance, // contractBalance
                numPlayers, // s_playersLength
                raffleState // s_raffleState
            )
        );

        raffle.performUpkeep("");
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        raffleEntered
    {
        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        vm.prank(USER);
        raffle.enterRaffle{value: raffleTicketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assertEq(uint256(raffleState), 1);
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEntered {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRanomWordsPicksWinnerAndTransfersFunds() public {
        uint256 playersToBeAdded = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(uint160(3));

        // ARRANGE
        // All players have entered the raffle
        for (
            uint i = startingIndex;
            i < playersToBeAdded + startingIndex;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 10 ether);
            raffle.enterRaffle{value: raffleTicketPrice}();
        }

        // Recording the timestamp just after the players have entered
        uint256 startingTimestamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance; // 9.99 ether

        // ACT
        //Perform upkeep
        // Record Logs and get RequestId
        vm.warp(block.timestamp + interval + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //ASSERT
        // After calling VRFCoordinatorV2_5Mock:fulfillRandomWords, it calls Raffle.sol:fulfillRandomWords
        // After that we assertEq variables inside Raffle.sol:fulfillRandomWords
        address recentWinner = raffle.getRecentWinner();
        uint256 winnerBalance = recentWinner.balance;
        uint256 lastTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = raffleTicketPrice * (playersToBeAdded); // 0.01*3 = 0.03 ether

        assertEq(expectedWinner, recentWinner);
        assertEq(uint256(raffle.getRaffleState()), 0);
        assertEq(winnerBalance, winnerStartingBalance + prize); // 9.99 + 0.03 = 10.02 ether
        assert(lastTimeStamp > startingTimestamp);
    }
}
