// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

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

        if (activeNetwork.subscriptionId == 0) {
            // create subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (uint256 subId, address vrfCoordinator) = createSubscription
                .createSubscription(activeNetwork.vrfCoordinator);
            activeNetwork.subscriptionId = subId;
            activeNetwork.vrfCoordinator = vrfCoordinator;

            //fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscriptionId(
                activeNetwork.vrfCoordinator,
                activeNetwork.subscriptionId,
                activeNetwork.linkToken
            );
        }

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

        // Add consumer
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            activeNetwork.vrfCoordinator,
            activeNetwork.subscriptionId
        );

        return (raffle, activeNetwork);
    }
}
