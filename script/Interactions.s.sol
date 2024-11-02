//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperconfig = new HelperConfig();
        address vrfCoordinator = helperconfig.getNetworkConfig().vrfCoordinator;
        (uint256 subId, ) = createSubscription(vrfCoordinator);
        //create subscription
        return (subId, vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint256, address) {
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        return (subId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperconfig = new HelperConfig();
        address vrfCoordinator = helperconfig.getNetworkConfig().vrfCoordinator;
        uint256 subscriptionId = helperconfig.getNetworkConfig().subscriptionId;
        address linkToken = helperconfig.getNetworkConfig().linkToken;

        fundSubscriptionId(vrfCoordinator, subscriptionId, linkToken);
    }

    function fundSubscriptionId(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken
    ) public {
        if (block.chainid == ANVIL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperconfig = new HelperConfig();
        address vrfCoordinator = helperconfig.getNetworkConfig().vrfCoordinator;
        uint256 subscriptionId = helperconfig.getNetworkConfig().subscriptionId;

        addConsumer(mostRecentlyDeployed, vrfCoordinator, subscriptionId);
    }

    function addConsumer(
        address contractToAddToVRF,
        address vrfCoordinator,
        uint256 subscriptionId
    ) public {
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            contractToAddToVRF
        );
        vm.stopBroadcast();
    }

    function run() public {
        address mostRecentlyDeployedContract = DevOpsTools
            .get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployedContract);
    }
}
