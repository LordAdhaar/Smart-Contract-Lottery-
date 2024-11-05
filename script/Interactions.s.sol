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
        address account = helperconfig.getNetworkConfig().account;
        (uint256 subId, ) = createSubscription(vrfCoordinator, account);
        //create subscription
        return (subId, vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        uint256 subId;
        vm.startBroadcast(account);
        subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        (, , , address owner, ) = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .getSubscription(subId);

        console2.log("CREATE SUBSCRIPTION");
        console2.log("Created subscription with ID:", subId);
        console2.log("VRF Coordinator:", vrfCoordinator);
        console2.log("Owner:", owner);

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
        address account = helperconfig.getNetworkConfig().account;

        fundSubscriptionId(vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fundSubscriptionId(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken,
        address account
    ) public {
        (, , , address subscriptionIdOwner, ) = VRFCoordinatorV2_5Mock(
            vrfCoordinator
        ).getSubscription(subscriptionId);

        console2.log("FUND SUBSCRIPTION");
        console2.log("Funding subscription with ID:", subscriptionId);
        console2.log("VRF Coordinator:", vrfCoordinator);
        console2.log("Link Token:", linkToken);
        console2.log("Account:", account);
        console2.log("Owner", subscriptionIdOwner);

        if (block.chainid == ANVIL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
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
        address account = helperconfig.getNetworkConfig().account;

        addConsumer(
            mostRecentlyDeployed,
            vrfCoordinator,
            subscriptionId,
            account
        );
    }

    function addConsumer(
        address contractToAddToVRF,
        address vrfCoordinator,
        uint256 subscriptionId,
        address account
    ) public {
        vm.startBroadcast(account);
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
