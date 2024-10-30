// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRaffle is Script {
    function run() external {
        deployContract();
    }

    function deployContract()
        public
        returns (Raffle, HelperConfig.NetworkConfig memory)
    {
        HelperConfig helperconfig = new HelperConfig();
        HelperConfig.NetworkConfig memory activeNetwork = helperconfig
            .getNetworkConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            activeNetwork.raffleTicketPrice,
            activeNetwork.interval,
            activeNetwork.subscriptionId,
            activeNetwork.callbackGasLimit,
            activeNetwork.vrfCoordinator,
            activeNetwork.keyHash
        );
        vm.stopBroadcast();

        return (raffle, activeNetwork);
    }
}
