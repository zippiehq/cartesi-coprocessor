// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {EigenlayerDeploymentLib} from "./utils/EigenlayerDeploymentLib.sol";
import {CoprocessorDeploymentLib} from "./utils/CoprocessorDeploymentLib.sol";
import {FundOperatorLib} from "./utils/FundOperatorLib.sol";

// # To deploy and verify our contract
// forge script script/IncredibleSquaringDeployer.s.sol:IncredibleSquaringDeployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv

contract DevnetCoprocessorDeployer is Script {
    function run() external {
        // Eigenlayer contracts
        vm.startBroadcast(msg.sender);

        EigenlayerDeploymentLib.Deployment memory el_deployment = 
            EigenlayerDeploymentLib.readDeployment("./script/output/devnet_eigenlayer_deployment.json");

        CoprocessorDeploymentLib.DeploymentConfig memory config;
        config.operatorWhitelistEnabled = true;
        config.operatorWhitelist = new address[](1);
        config.operatorWhitelist[0] = 0x02C9ca5313A6E826DC05Bbe098150b3215D5F821;
        
        CoprocessorDeploymentLib.Deployment memory deployment =
            CoprocessorDeploymentLib.deployContracts(
                el_deployment,
                config,
                true,
                true,
                msg.sender
            );

        CoprocessorDeploymentLib
            .writeDeployment(deployment, "./script/output/devnet_eigenlayer_deployment.json");
                
        vm.stopBroadcast();
    }
}
