// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";
import "forge-std/StdCheats.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "@eigenlayer/interfaces/IDelegationManager.sol";
import "@eigenlayer/interfaces/IAllocationManager.sol";
import {IStrategyManager} from "@eigenlayer/interfaces/IStrategyManager.sol";

import {SlashingRegistryCoordinator} from"@eigenlayer-middleware/SlashingRegistryCoordinator.sol";
import {OperatorWalletLib, Operator} from "@eigenlayer-middleware-test/utils/OperatorWalletLib.sol";
import {ISlashingRegistryCoordinatorTypes} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {IBLSApkRegistryTypes} from "@eigenlayer-middleware/interfaces/IBLSApkRegistry.sol";
import {BN254} from "@eigenlayer-middleware/libraries/BN254.sol";
import {Operator, OperatorWalletLib, SigningKeyOperationsLib} from "@eigenlayer-middleware-test/utils/OperatorWalletLib.sol";


import {EigenlayerDeploymentLib} from "./utils/EigenlayerDeploymentLib.sol";
import {CoprocessorDeployerBase} from "./utils/CoprocessorDeployerBase.sol";

import {ERC20Mock} from "../src/ERC20Mock.sol";


// forge script script/DevnetCoprocessorDeployer.s.sol:DevnetCoprocessorDeployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv

contract DevnetCoprocessorDeployer is CoprocessorDeployerBase {
    //uint256 deployerKey;
    uint256[] operatorKeys;
    
    function setUp() public virtual {
        //deployerKey = vm.envUint("PRIVATE_KEY");
        
        operatorKeys = new uint256[](1);
        operatorKeys[0] = 0xc276a0e2815b89e9a3d8b64cb5d745d5b4f6b84531306c97aad82156000a7dd7; 
    }
    
    function run() external {
        el_deployment = EigenlayerDeploymentLib.readDeployment("./script/output/devnet_eigenlayer_deployment.json");

        // Prepare deployment config
        config.registryCoordinatorOwner = msg.sender;
        config.churnApprover = msg.sender;
        config.ejector = msg.sender;
        config.metdataURI = "ipfs://mock-metadata-uri";
        config.operatorWhitelistEnabled = true;
        config.operatorWhitelist = new address[](1);
        config.operatorWhitelist[0] = vm.addr(operatorKeys[0]);
        //config.operatorWhitelist[0] = vm.addr(0x02C9ca5313A6E826DC05Bbe098150b3215D5F821);
        //config.operatorWhitelist[0] = 0xbc38a31ac80BaFeD58945ca9aF62500E0f2FeF60;
        
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
        for (uint256 i = 0; i < operatorKeys.length; i++) {
            uint256 operator = operatorKeys[i];
            address operatorAddress = vm.addr(operator);
            sendEther(vm.addr(operator), 1 ether);
            registerOperatorWithEigenLayer(operator);
            mintToken(deployment.strategyToken, operatorAddress, 20);
            depositIntoStrategy(operator, deployment.strategy, 10);

           // !!!
           /*
           TestOperator memory o = createTestOperator("operator");
           console.log(o.operator.key.addr);
           registerOperatorWithAVS(o);
           //registerOperatorWithAVS(o);
           */
        }
    }

    function sendEther(address to, uint256 value) public payable {
        vm.startBroadcast();
        payable(to).transfer(value);
        vm.stopBroadcast();
    }

    function mintToken(address erc20, address to, uint256 amount) internal {
        vm.startBroadcast();
        ERC20Mock(erc20).mint(to, amount);
        vm.stopBroadcast();
    }

    function registerOperatorWithEigenLayer(uint256 operator) internal {
        vm.startBroadcast(operator);
        IDelegationManager(el_deployment.delegationManager).registerAsOperator(
            0x0000000000000000000000000000000000000000,
            0,
            "https://raw.githubusercontent.com/tantatnhan/chainbase/refs/heads/main/metadata.json"
        ); 
        vm.stopBroadcast();
    }

    function depositIntoStrategy(
        uint256 operator,
        address startegy,
        uint256 amount
    ) internal {
        vm.startBroadcast(operator);
        IERC20 erc20 = IStrategy(startegy).underlyingToken();
        erc20.approve(el_deployment.strategyManager, amount);
        IStrategyManager(el_deployment.strategyManager)
            .depositIntoStrategy(IStrategy(startegy), erc20, amount);
        vm.stopBroadcast();
    }

    struct TestOperator {
        Operator operator;
        IBLSApkRegistryTypes.PubkeyRegistrationParams pubKeyParams;
    }

    function createTestOperator(string memory name) internal returns (TestOperator memory) {
        Operator memory operator = OperatorWalletLib.createOperator(name);
        
        bytes32 messageHash =
            SlashingRegistryCoordinator(deployment.registryCoordinator)
            .calculatePubkeyRegistrationMessageHash(operator.key.addr);
        BN254.G1Point memory signature =
            SigningKeyOperationsLib.sign(operator.signingKey, messageHash);
        IBLSApkRegistryTypes.PubkeyRegistrationParams memory pubKeyParams = IBLSApkRegistryTypes.PubkeyRegistrationParams({
            pubkeyRegistrationSignature: signature,
            pubkeyG1: operator.signingKey.publicKeyG1,
            pubkeyG2: operator.signingKey.publicKeyG2
        });

        return TestOperator(operator, pubKeyParams);
    }

    function registerOperatorWithAVS(TestOperator memory operator) internal {
        vm.startBroadcast(operator.operator.key.privateKey);
        uint32[] memory oids = new uint32[](1);
        oids[0] = 0;
        IAllocationManagerTypes.RegisterParams memory params = IAllocationManagerTypes.RegisterParams({
            avs: deployment.coprocessorServiceManager,
            operatorSetIds: oids,
            data: abi.encode(
                ISlashingRegistryCoordinatorTypes.RegistrationType.NORMAL, "socket", operator.pubKeyParams
            )
        });
        IAllocationManager(el_deployment.allocationManager).registerForOperatorSets(
            operator.operator.key.addr,
            params
        );
        vm.stopBroadcast();
    }
}
