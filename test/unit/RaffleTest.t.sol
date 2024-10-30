//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig.NetworkConfig public activeNetwork;

    address public USER = makeAddr("Adhaar");
    uint256 public constant STARTING_USER_BALANCE = 1000 ether;
    uint256 public constant GAS_PRICE = 1;
    uint256 public constant SENT_VALUE = 10 ether;

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
        raffle.enterRaffle{value: SENT_VALUE}();
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
        raffle.enterRaffle{value: SENT_VALUE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(USER);
        raffle.enterRaffle{value: SENT_VALUE}();
    }
}
