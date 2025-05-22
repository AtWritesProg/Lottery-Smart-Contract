//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstant} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function creatSubsricptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;

        (uint256 subId,) = createSubsricption(vrfCoordinator, account);
        return (subId, vrfCoordinator);

        //create subricpition
    }

    function createSubsricption(address vrfCoordinator, address account) public returns (uint256, address) {
        //create subricpition
        console.log("Creating subscription", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("SubscriptionId", subId);
        console.log("Subscription created");

        return (subId, vrfCoordinator);
    }

    function run() public {
        uint256 chainId = block.chainid;
        if (chainId == 11155111) {
            creatSubsricptionUsingConfig();
        } else {
            revert("ChainId not supported");
        }
    }
}

contract FundSubscription is Script {
    uint256 public constant FUND_AMOUNT = 3 ether; //3 Link

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subsrciptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subsrciptionId, linkToken, account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subsrciptionId, address linkToken, address account)
        public
    {
        console.log("On ChainID", block.chainid);
        console.log("Funding subscription", subsrciptionId);
        console.log("Using vrfCoordinator", vrfCoordinator);

        if (block.chainid == 31337) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subsrciptionId, FUND_AMOUNT * 100);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subsrciptionId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentRaffle) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subsrciptionId = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account;
        addConsumer(vrfCoordinator, subsrciptionId, mostRecentRaffle, account);
    }

    function addConsumer(address vrfCoordinator, uint256 subsrciptionId, address raffle, address account) public {
        console.log("On ChainID", block.chainid);
        console.log("Adding consumer to subscription", subsrciptionId);
        console.log("Using vrfCoordinator", vrfCoordinator);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subsrciptionId, raffle);
        vm.stopBroadcast();
    }

    function run() public {
        address mostRecentRaffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentRaffle);
    }
}
