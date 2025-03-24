// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";
import "forge-std/StdCheats.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "@eigenlayer/interfaces/IAllocationManager.sol";

import {EigenlayerDeploymentLib} from "./utils/EigenlayerDeploymentLib.sol";
import {CoprocessorDeployerBase} from "./utils/CoprocessorDeployerBase.sol";

// forge script script/DevnetCoprocessorDeployer.s.sol:DevnetCoprocessorDeployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv

contract DevnetCoprocessorDeployer is CoprocessorDeployerBase {
    function run() external {
        el_deployment = EigenlayerDeploymentLib.readDeployment("./script/output/devnet_eigenlayer_deployment.json");

        config.registryCoordinatorOwner = msg.sender;
        config.churnApprover = msg.sender;
        config.ejector = msg.sender;
        config.metdataURI = "ipfs://mock-metadata-uri";
        config.operatorWhitelistEnabled = true;
        config.operatorWhitelist = new address[](1);
        config.operatorWhitelist[0] = 0x02C9ca5313A6E826DC05Bbe098150b3215D5F821;
        
        deployAvs();
        verifyAvsDeployment();

        deployStrategy(); // strategy is required for quorums
        
        setupAvsUamPermissions();
        setupAvsQuorums();

        deployL1L2Bridge();
        
        this.setupOperators();

        writeDeployment("./script/output/devnet_coprocessor_deployment.json");                
    }

    function setupOperators() external payable {
        for (uint256 i = 0; i < config.operatorWhitelist.length; i++) {
            address operator = config.operatorWhitelist[i];
            sendEther(msg.sender, operator, 30000);
            registerOperatorWithEigenLayer(operator);
            mintToken(msg.sender, deployment.strategyToken, operator, 20);
            depositIntoStrategy(operator, deployment.strategy, 10);

            vm.startBroadcast(operator);
            uint32[] memory oids = new uint32[](1);
            oids[0] = 0;
            IAllocationManagerTypes.RegisterParams memory register = IAllocationManagerTypes.RegisterParams({
                avs: deployment.coprocessorServiceManager,
                operatorSetIds: oids,
                data: ""
            });
            IAllocationManager(el_deployment.allocationManager).registerForOperatorSets(
                0x02C9ca5313A6E826DC05Bbe098150b3215D5F821,
                register
            );
            vm.stopBroadcast();
        }
    }
}
