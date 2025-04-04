// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/console.sol";

import {IStrategy} from "@eigenlayer/interfaces/IStrategy.sol";

import {IStakeRegistryTypes} from "@eigenlayer-middleware/interfaces/IStakeRegistry.sol";

import {EigenlayerDeploymentLib} from "./utils/EigenlayerDeploymentLib.sol";
import {CoprocessorDeployerTest} from "./utils/CoprocessorDeployerTest.sol";

/*
forge script script/DevnetCoprocessorDeployer.s.sol:DevnetCoprocessorDeployer \
--rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--broadcast \
--ffi \
-vvvv
*/

contract DevnetCoprocessorDeployer is CoprocessorDeployerTest {
    uint256[] operatorKeys;
    
    function setUp() public virtual {
        operatorKeys = new uint256[](1);
        // for testing setup-operator
        operatorKeys[0] = 0xc276a0e2815b89e9a3d8b64cb5d745d5b4f6b84531306c97aad82156000a7dd7; 
        // for testing operator registration
        //operatorKeys[0] = 60320572042965013730371936825825955422769740388281116725376228375435893381276;
    }
    
    function run() external {
        el_deployment = EigenlayerDeploymentLib.readDeployment("./script/output/devnet_eigenlayer_deployment.json");

        // Prepare deployment config
        // Use deployer account for all roles
        config.registryCoordinatorOwner = msg.sender;
        config.churnApprover = msg.sender;
        config.ejector = msg.sender;
        config.metdataURI = "ipfs://mock-metadata-uri";
        config.operatorWhitelistEnabled = true;
        config.operatorWhitelist = new address[](1);
        config.operatorWhitelist[0] = vm.addr(operatorKeys[0]);
        
        deployAvs();
        verifyAvsDeployment();

        deployStrategy(); // strategy is required for quorums
        
        setupAvsUamPermissions();
        
        IStakeRegistryTypes.StrategyParams[] memory strategyParams =
            new IStakeRegistryTypes.StrategyParams[](1);
        strategyParams[0] = IStakeRegistryTypes.StrategyParams({
            strategy: IStrategy(deployment.strategy),
            multiplier: 1
        });
        setupAvsQuorums(strategyParams);

        deployL1L2Bridge();
        
        this.setupOperators();

        writeDeployment("./script/output/devnet_coprocessor_deployment.json");                
    }

    function setupOperators() external payable {
        for (uint256 i = 0; i < operatorKeys.length; i++) {
            uint256 operator = operatorKeys[i];
            address operatorAddress = vm.addr(operator);
            sendEther(operatorAddress, 1 ether);
            registerOperatorWithEigenLayer(operator);
            mintToken(deployment.strategyToken, operatorAddress, 20 ether);
            depositIntoStrategy(operator, deployment.strategy, 10 ether);

            // Enable to test operator registration.
            /*
            TestOperator memory o = createTestOperator("operator");
            console.log("operator private key:", o.operator.key.privateKey);
            registerOperatorWithAVS(o);
            */
        }
    }
}
