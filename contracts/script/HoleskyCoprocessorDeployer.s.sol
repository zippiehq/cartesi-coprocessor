// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/console.sol";

import {IStrategy} from "@eigenlayer/interfaces/IStrategy.sol";

import {IStakeRegistryTypes} from "@eigenlayer-middleware/interfaces/IStakeRegistry.sol";

import {EigenlayerDeploymentLib} from "./utils/EigenlayerDeploymentLib.sol";
import {CoprocessorDeployerTest} from "./utils/CoprocessorDeployerTest.sol";

/*
forge script script/HoleskyForkCoprocessorDeployer.s.sol:HoleskyForkCoprocessorDeployer \
--rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--broadcast \
--ffi \
-vvvv
*/

interface IWETH {
    function deposit() external payable;
    function balanceOf(address src) external view returns (uint256);
}

contract HoleskyForkCoprocessorDeployer is CoprocessorDeployerTest {
    address constant WETH_ADDRESS = 0x94373a4919B3240D86eA41593D5eBa789FEF3848;
    address constant WETH_STRATEGY_ADDRESS = 0x80528D6e9A2BAbFc766965E0E26d5aB08D9CFaF9;

    string[] operatorNames;
    uint256[] operatorKeys;

    function setUp() public virtual {
        operatorNames = new string[](0);
        operatorKeys = new uint256[](0);
    }

    function run() external {
        el_deployment = EigenlayerDeploymentLib.readDeployment("./script/input/holesky_eigenlayer_deployment.json");

        // Prepare deployment config
        // Use deployer account for all roles
        config.registryCoordinatorOwner = msg.sender;
        config.churnApprover = msg.sender;
        config.ejector = msg.sender;
        config.metdataURI =
            "https://raw.githubusercontent.com/cartesi/coprocessor-infra/refs/heads/main/avs_dev_metadata_v2.json";
        config.operatorWhitelistEnabled = true;
        config.operatorWhitelist = new address[](operatorKeys.length);
        for (uint256 i = 0; i < operatorKeys.length; i++) {
            config.operatorWhitelist[i] = vm.addr(operatorKeys[i]);
            // Enable to check that whitelist blocks unknown testing operator
            // config.operatorWhitelist[i] = vm.addr(1);
        }

        deployAvs();
        verifyAvsDeployment();

        setupAvsUamPermissions();

        IStakeRegistryTypes.StrategyParams[] memory strategyParams = new IStakeRegistryTypes.StrategyParams[](1);
        strategyParams[0] =
            IStakeRegistryTypes.StrategyParams({strategy: IStrategy(WETH_STRATEGY_ADDRESS), multiplier: 1 ether});
        setupAvsQuorums(strategyParams);

        //deployL1L2Bridge();

        this.setupOperators();

        writeDeployment("./script/output/holesky_dev_coprocessor_deployment.json");
    }

    function setupOperators() external payable {
        for (uint256 i = 0; i < operatorKeys.length; i++) {
            uint256 operator = operatorKeys[i];
            address operatorAddress = vm.addr(operator);
            sendEther(operatorAddress, 30 ether);
            registerOperatorWithEigenLayer(operator);
            depositWeth(WETH_ADDRESS, operator, 20 ether);
            depositIntoStrategy(operator, WETH_STRATEGY_ADDRESS, 10);
        }

        // Enable to test operator registratoin.
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
