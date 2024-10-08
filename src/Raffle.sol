//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details

contract Raffle {
    uint256 private immutable i_raffleTicketPrice;

    error Raffle__SendMoreETHToEnterRaffle();

    constructor(uint256 raffleTicketPrice) {
        i_raffleTicketPrice = raffleTicketPrice;
    }

    function buyRaffleTicket() public payable {
        if (msg.value < i_raffleTicketPrice) {
            revert Raffle__SendMoreETHToEnterRaffle();
        }
    }

    function pickWinner() public {}

    function getRaffleTicketPrice() public view returns (uint256) {
        return i_raffleTicketPrice;
    }
}
