//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details

// Layout of the contract file:
// version
// imports
// errors
// interfaces, libraries, contract
// Inside Contract:
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
// internal & private view & pure functions

// external & public view & pure functions

contract Raffle is VRFConsumerBaseV2Plus {
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    RaffleState private s_raffleState;

    /*State Variables*/
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_raffleTicketPrice;
    uint256 private immutable i_interval;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    address payable private s_recentWinner;

    // contractName__customErorr
    error Raffle__SendMoreETHToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 contractBalance,
        uint256 s_playersLength,
        uint256 s_raffleState
    );

    event PlayerEnteredRaffle(address indexed player);
    event UpdateLastTimestamp();
    event WinnerPicked(address indexed player);

    constructor(
        uint256 raffleTicketPrice,
        uint256 interval,
        uint256 subscriptionId,
        uint32 callbackGasLimit,
        address vrfCoordinator,
        bytes32 keyHash // keyhash,
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_raffleTicketPrice = raffleTicketPrice;
        i_interval = interval;
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        if (msg.value < i_raffleTicketPrice) {
            revert Raffle__SendMoreETHToEnterRaffle();
        }

        s_players.push(payable(msg.sender));

        // emit whenever state variable is being changed, make it a rule of thumb
        emit PlayerEnteredRaffle(msg.sender);
    }

    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (bool, bytes memory /* peroformData */) {
        bool upkeepNeeded;

        bool timeHasPassed = ((block.timestamp - s_lastTimestamp) >=
            i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        s_lastTimestamp = block.timestamp;

        emit UpdateLastTimestamp();
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal virtual override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        s_recentWinner = s_players[indexOfWinner];
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;

        emit UpdateLastTimestamp();
        emit WinnerPicked(s_recentWinner);

        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );

        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    function getRaffleTicketPrice() public view returns (uint256) {
        return i_raffleTicketPrice;
    }
}
