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
import {IStakeRegistryTypes} from "@eigenlayer-middleware/interfaces/IStakeRegistry.sol";

import {EigenlayerDeploymentLib} from "./utils/EigenlayerDeploymentLib.sol";
import {CoprocessorDeployerBase} from "./utils/CoprocessorDeployerBase.sol";

import {ERC20Mock} from "../src/ERC20Mock.sol";

/*
forge script script/HoleskyForkCoprocessorDeployer.s.sol:HoleskyForkCoprocessorDeployer \
--rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--broadcast \
-vvvv
*/

interface IWETH {
    function deposit() external payable;
    function balanceOf(address src) external view returns (uint256);
}

contract HoleskyForkCoprocessorDeployer is CoprocessorDeployerBase {
    address constant WETH_ADDRESS = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;
    address constant WETH_STRATEGY_ADDRESS = 0x80528D6e9A2BAbFc766965E0E26d5aB08D9CFaF9;
    
    string[] operatorNames;
    uint256[] operatorKeys;
    
    function setUp() public virtual {
        operatorNames = new string[](5);
        operatorNames[0] = "operator1";
        operatorNames[1] = "operator2";
        operatorNames[2] = "operator3";
        operatorNames[3] = "operator4";
        operatorNames[4] = "operator5";
        
        operatorKeys = new uint256[](5);
        operatorKeys[0] = 36407525368377311493796432571598967036725569564492624564850980679192418481618;
        operatorKeys[1] = 18191098147740732280693182866451768943100355768310205068615561759894742424004;
        operatorKeys[2] = 99928376545439830843112220809516518285891625216226249120386397820835427785038;
        operatorKeys[3] = 61335891880194878340472580074183423963030147272304747695685225805187806891438;
        operatorKeys[4] = 81422724954312471246955407297969567897969226523421875976253813863001483564633;
    }
    
    function run() external {
        el_deployment = EigenlayerDeploymentLib.readDeployment("./script/input/holesky_eigenlayer_deployment.json");

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
        }
        
        deployAvs();
        verifyAvsDeployment();

        setupAvsUamPermissions();
        
        IStakeRegistryTypes.StrategyParams[] memory strategyParams =
            new IStakeRegistryTypes.StrategyParams[](1);
        strategyParams[0] = IStakeRegistryTypes.StrategyParams({
            strategy: IStrategy(WETH_STRATEGY_ADDRESS),
            multiplier: 1
        });        
        setupAvsQuorums(strategyParams);

        deployL1L2Bridge();
        
        this.setupOperators();

        writeDeployment("./script/output/holesky_fork_coprocessor_deployment.json");                
    }

    function setupOperators() external payable {
        for (uint256 i = 0; i < operatorKeys.length; i++) {
            uint256 operator = operatorKeys[i];
            address operatorAddress = vm.addr(operator);
            sendEther(operatorAddress, 30 ether);
            registerOperatorWithEigenLayer(operator);
            depositWeth(WETH_ADDRESS, operator, 20 ether);
            depositIntoStrategy(operator, WETH_STRATEGY_ADDRESS, 10 ether);
        }

        // Enable to test that operator registratoin works.
        /*
        for (uint256 i = 0; i < operatorKeys.length; i++) {
            string memory operatorName = operatorNames[i];
            TestOperator memory o = createTestOperator(operatorName);
            console.log(operatorName, "private key:", o.operator.key.privateKey);
            registerOperatorWithAVS(o);
        }
        */
    }

    function sendEther(address to, uint256 value) public payable {
        vm.startBroadcast();
        payable(to).transfer(value);
        vm.stopBroadcast();
    }

    function depositWeth(address weth, uint256 sender, uint256 amount) internal {
        vm.startBroadcast(sender);
        IWETH(weth).deposit{value: amount}();
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
