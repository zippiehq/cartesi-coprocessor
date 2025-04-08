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
    string[] operatorNames;
    uint256[] operatorKeys;
    
    function setUp() public virtual {
        operatorNames = new string[](1);
        operatorNames[0] = "operator1";
        
        operatorKeys = new uint256[](1);
        operatorKeys[0] = 36407525368377311493796432571598967036725569564492624564850980679192418481618;
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
        config.operatorWhitelist = new address[](operatorKeys.length);
        for (uint256 i = 0; i < operatorKeys.length; i++) {
            config.operatorWhitelist[i] = vm.addr(operatorKeys[i]);
            // Enable to check that whitelist blocks unknown testing operator
            // config.operatorWhitelist[i] = vm.addr(1);
        }
        

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
            for (uint256 i = 0; i < operatorKeys.length; i++) {
                string memory operatorName = operatorNames[i];
                TestOperator memory o = createTestOperator(operatorName);
                console.log(operatorName, "private key:", o.operator.key.privateKey);
                registerOperatorWithAVS(o);
            }
            */
        }
    }
}
