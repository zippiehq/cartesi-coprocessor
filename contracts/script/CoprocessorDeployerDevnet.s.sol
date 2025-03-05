// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "@eigenlayer/permissions/PauserRegistry.sol";
import "@eigenlayer/core/StrategyManager.sol";
import {StrategyBaseTVLLimits} from "@eigenlayer/strategies/StrategyBaseTVLLimits.sol";

import "../src/CoprocessorToL2.sol";
import "../src/Mock_L2Coprocessor.sol";
import "../src/Mock_L1_Sender.sol";
import "../src/Mock_L2CoprocessorCaller.sol";

import "../src/ERC20Mock.sol";
import {Utils} from "./utils/Utils.sol";
import {CoprocessorDeployer} from "./CoprocessorDeployer.s.sol";

contract CoprocessorDeployerDevnet is CoprocessorDeployer {
    function run() external {
        string memory paramFile = "./script/input/deployment_parameters_devnet.json";
        (EigenLayerContracts memory eigenLayer, DeploymentConfig memory config) = readDeploymentParameters(paramFile);

        vm.startBroadcast();

        (address erc20MockStrategy, address erc20Mock) = deployERC20MockStrategy(
            eigenLayer.proxyAdmin, eigenLayer.pauserRegistry, eigenLayer.baseStrategy, eigenLayer.strategyManager
        );

        StrategyConfig[] memory strategyConfig = new StrategyConfig[](1);
        {
            strategyConfig[0].strategy = erc20MockStrategy;
            strategyConfig[0].weight = eigenLayer.wETH_Multiplier;
        }
        CoprocessorContracts memory contracts = deployAVS(eigenLayer, config, strategyConfig);

        Mock_L2Coprocessor mockL2Coprocessor = new Mock_L2Coprocessor(address(0));
        Mock_L1_Sender mockL1Sender = new Mock_L1_Sender(IMock_L2Coprocessor(address(mockL2Coprocessor)));
        mockL2Coprocessor.setL1Sender(address(mockL1Sender));

        CoprocessorToL2 coprocessorToL2 = new CoprocessorToL2(contracts.registryCoordinator);
        MockL2CoprocessorCaller mockL2CoprocessorCaller = new MockL2CoprocessorCaller(address(mockL2Coprocessor));

        vm.stopBroadcast();

        AuxContract[] memory auxContracts = new AuxContract[](6);
        {
            auxContracts[0].name = "erc20Mock";
            auxContracts[0].addr = erc20Mock;
            auxContracts[1].name = "erc20MockStrategy";
            auxContracts[1].addr = erc20MockStrategy;
            auxContracts[2].name = "Mock_L2Coprocessor";
            auxContracts[2].addr = address(mockL2Coprocessor);
            auxContracts[3].name = "Mock_L1_Sender";
            auxContracts[3].addr = address(mockL1Sender);
            auxContracts[4].name = "CoprocessorToL2";
            auxContracts[4].addr = address(coprocessorToL2);
            auxContracts[5].name = "Mock_L2CoprocessorCaller";
            auxContracts[5].addr = address(mockL2CoprocessorCaller);
        }
        string memory outputPath = "./script/output/coprocessor_deployment_output_devnet.json";
        writeDeploymentOutput(contracts, auxContracts, outputPath);
    }

    function deployERC20MockStrategy(
        ProxyAdmin eigenLayerProxyAdmin,
        PauserRegistry eigenLayerPauserReg,
        StrategyBaseTVLLimits baseStrategyImplementation,
        IStrategyManager strategyManager
    ) internal returns (address, address) {
        ERC20Mock erc20Mock = new ERC20Mock();
        // TODO(samlaf): any reason why we are using the strategybase with tvl limits instead of just using strategybase?
        // the maxPerDeposit and maxDeposits below are just arbitrary values.
        StrategyBaseTVLLimits erc20MockStrategy = StrategyBaseTVLLimits(
            address(
                new TransparentUpgradeableProxy(
                    address(baseStrategyImplementation),
                    address(eigenLayerProxyAdmin),
                    abi.encodeWithSelector(
                        StrategyBaseTVLLimits.initialize.selector,
                        1 ether, // maxPerDeposit
                        100 ether, // maxDeposits
                        IERC20(erc20Mock),
                        eigenLayerPauserReg
                    )
                )
            )
        );
        IStrategy[] memory strats = new IStrategy[](1);
        strats[0] = erc20MockStrategy;
        bool[] memory thirdPartyTransfersForbiddenValues = new bool[](1);
        thirdPartyTransfersForbiddenValues[0] = false;
        strategyManager.addStrategiesToDepositWhitelist(strats, thirdPartyTransfersForbiddenValues);

        return (address(erc20MockStrategy), address(erc20Mock));
    }
}