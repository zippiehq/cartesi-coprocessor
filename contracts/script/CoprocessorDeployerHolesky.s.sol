// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {CoprocessorDeployer} from "./CoprocessorDeployer.s.sol";

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

contract CoprocessorDeployerHolesky is CoprocessorDeployer {
    function run() external {
        string memory paramFile = "./script/input/deployment_parameters_holesky.json";
        (EigenLayerContracts memory eigenLayer, DeploymentConfig memory config)
             = readDeploymentParameters(paramFile);

        

        vm.startBroadcast();

        StrategyConfig[] memory strategyConfig = new StrategyConfig[](1);
        {
            strategyConfig[0].strategy = eigenLayer.wETH;
            strategyConfig[0].weight = eigenLayer.wETH_Multiplier;
        }
        CoprocessorContracts memory contracts = deployAVS(eigenLayer, config, strategyConfig);
        
        vm.stopBroadcast();

        AuxContract[] memory auxContracts = new AuxContract[](0);
        string memory outputPath = "./script/output/coprocessor_deployment_output_holesky.json";
        writeDeploymentOutput(contracts, auxContracts, outputPath);
    }
}