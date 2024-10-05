//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

/*
 * @title Smart Contract Lottery
 * @author Adhaar Jain
 * @about This contract is for creating a sample lottery
 * @dev We are using Chainlink VRFv2 and Chainlink Automation
 */

contract Raffle {
    uint256 private immutable i_raffleTicketPrice;

    constructor(uint256 raffleTicketPrice) {
        i_raffleTicketPrice = raffleTicketPrice;
    }

    function enterRaffle() public {}

    function pickWinner() public {}

    /* GETTER FUNCTION */

    function getRaffleTicketPrice() external view returns (uint256) {
        return i_raffleTicketPrice;
    }
}
