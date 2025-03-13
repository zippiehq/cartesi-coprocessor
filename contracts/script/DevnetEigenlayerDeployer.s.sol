// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {EigenlayerDeploymentLib} from "./utils/EigenlayerDeploymentLib.sol";

// forge script script/DevnetEigenlayerDeployer.s.sol:DevnetEigenlayerDeployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv

contract DevnetEigenlayerDeployer is Script {
    function run() external {
        vm.startBroadcast(msg.sender);

        EigenlayerDeploymentLib.DeploymentConfig memory config =
            EigenlayerDeploymentLib.readDeploymentConfig("./script/input/devnet_eigenlayer_deployment_config.json");
        
        EigenlayerDeploymentLib.Deployment memory deployment =
            EigenlayerDeploymentLib.deployContracts(
                config,
                msg.sender
            );

        EigenlayerDeploymentLib
            .writeDeployment(deployment, "./script/output/devnet_eigenlayer_deployment.json");
                
        vm.stopBroadcast();
    }
}
