//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstant {
    // VRF MOCK VALUES
    uint96 public BASE_FEE = 0.25 ether; // 0.25 LINK per request
    uint96 public GAS_PRICE_LINK = 1e9; // 1000000000 LINK per gas
    //Link / Eth Price
    int256 public MOCK_wEI_PER_UNIT_LINK= 4e15; 

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

}

contract HelperConfig is Script,CodeConstant{
    error HelperConfig__ChainIdNotSupported(uint256 chainId);

    struct NetworkConfig{
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor(){
        networkConfigs[ETH_SEPOLIA_CHAIN_ID]= getSepoliaEthConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory){
        if (networkConfigs[chainId].vrfCoordinator != address(0)){
            return networkConfigs[chainId];
        }else if(chainId==LOCAL_CHAIN_ID){
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__ChainIdNotSupported(chainId);
        }
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory){
        if (localNetworkConfig.vrfCoordinator != address(0)){
            return localNetworkConfig;
        }
        vm.startBroadcast();
            VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
                BASE_FEE,
                GAS_PRICE_LINK,
                MOCK_wEI_PER_UNIT_LINK
            );
            LinkToken link = new LinkToken();
            vm.stopBroadcast();

            localNetworkConfig= NetworkConfig({
                entranceFee:0.01 ether,
                interval:30,
                vrfCoordinator:address(vrfCoordinator),
                gasLane:0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionId: 0,
                callbackGasLimit:50000,
                link: address(link),
                account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
            });
            return localNetworkConfig;
    }

    function getSepoliaEthConfig() public pure returns(NetworkConfig memory){
        return NetworkConfig({
            entranceFee:0.01 ether,
            interval:30,
            vrfCoordinator:0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane:0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 69873624161773746466182461325206134180139938568306248821491754870640522237631,
            callbackGasLimit:50000,
            link:0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account:0xd08ae577D973648f708B7cBFBBF112948F1Ea3fa
        });
    }

    function getConfig() public returns (NetworkConfig memory){
        return getConfigByChainId(block.chainid);
    }
}