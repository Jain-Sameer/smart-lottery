// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint96 public MOCK_BASE_FEW = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    int256 public MOCK_WEI_PER_LINK = 4e15;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainID();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane; // keyhash,
        uint256 subscriptionID;
        uint32 callbackGasLimit;
        address linkTokenAddress;
        address account;
    }

    NetworkConfig public localNetworkConfig;

    mapping(uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    function getConfigByChainID(
        uint256 chainID
    ) public returns (NetworkConfig memory) {
        if (networkConfigs[chainID].vrfCoordinator != address(0)) {
            return networkConfigs[chainID];
        } else if (chainID == LOCAL_CHAIN_ID) {
            //getorcreate anvil chain
            return getOrcreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainID();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainID(block.chainid);
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionID: 76842541667191232280402919432467935856675975306778334153970471516604440311444,
                callbackGasLimit: 500000,
                linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                account: 0x2cA1469804EEb60D897499da8DDA674eEae7bFA9
            });
    }

    function getOrcreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }
        //Deploy
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEW,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_LINK
        );
        LinkToken mockLinkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, //doesnt matter
            subscriptionID: 0,
            callbackGasLimit: 500000,
            // linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            linkTokenAddress: address(mockLinkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 //default sender
        });
        return localNetworkConfig;
    }
}
