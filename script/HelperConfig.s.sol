// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    // MIGHT CAUSE ERROR LATER
    uint96 public constant BASE_FEE = 1 ether;
    uint96 public constant GAS_PRICE = 20 gwei;
    int256 public constant WEI_PER_UNIT_LINK = 1 ether;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 raffleTicketPrice;
        uint256 interval;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address vrfCoordinator;
        bytes32 keyHash;
        address linkToken;
    }

    // MIGHT CAUSE ERROR LATER NAME DIFF
    NetworkConfig public activeNetwork;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[ANVIL_CHAIN_ID] = getOrCreateAnvilEthConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == ANVIL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getNetworkConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                raffleTicketPrice: 0.01 ether,
                interval: 30,
                subscriptionId: 11444602845039372062572197156360110778940007239868027730611963421232005626774,
                callbackGasLimit: 500000,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetwork.vrfCoordinator != address(0)) {
            return activeNetwork;
        }

        vm.startBroadcast();

        VRFCoordinatorV2_5Mock mockVRFCoordinator = new VRFCoordinatorV2_5Mock(
            BASE_FEE,
            GAS_PRICE,
            WEI_PER_UNIT_LINK
        );

        LinkToken linkToken = new LinkToken();

        vm.stopBroadcast();

        return
            NetworkConfig({
                raffleTicketPrice: 0.01 ether,
                interval: 30,
                // might have to fix this yaar
                subscriptionId: 0,
                callbackGasLimit: 500000,
                vrfCoordinator: address(mockVRFCoordinator),
                // does not matter yaar
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                linkToken: address(linkToken)
            });
    }
}
