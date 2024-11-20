// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "@eigenlayer/contracts/permissions/PauserRegistry.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import "@eigenlayer/contracts/core/DelegationManager.sol";
import {IAVSDirectory, AVSDirectory} from "@eigenlayer/contracts/core/AVSDirectory.sol";
import {IStrategyManager, IStrategy} from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import "@eigenlayer/contracts/core/StrategyManager.sol";
import {ISlasher} from "@eigenlayer/contracts/interfaces/ISlasher.sol";
import {StrategyBaseTVLLimits} from "@eigenlayer/contracts/strategies/StrategyBaseTVLLimits.sol";
import "@eigenlayer/test/mocks/EmptyContract.sol";

import {
    IBLSApkRegistry,
    IIndexRegistry,
    IStakeRegistry,
    IRegistryCoordinator,
    RegistryCoordinator
} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";
import {IndexRegistry} from "@eigenlayer-middleware/src/IndexRegistry.sol";
import {StakeRegistry} from "@eigenlayer-middleware/src/StakeRegistry.sol";
import "@eigenlayer-middleware/src/OperatorStateRetriever.sol";

import {CoprocessorServiceManager, IServiceManager} from "../eigenlayer/CoprocessorServiceManager.sol";
import {Coprocessor} from "../src/Coprocessor.sol";
import "../src/ERC20Mock.sol";

import {Utils} from "./utils/Utils.sol";

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

contract CoprocessorDeployer is Script, Utils {
    struct EigenLayerContracts {
        IAVSDirectory avsDirectory;
        DelegationManager delegationManager;
        StrategyManager strategyManager;
        ProxyAdmin proxyAdmin;
        PauserRegistry pauserRegistry;
        StrategyBaseTVLLimits baseStrategy;
        address wETH;
        uint96 wETH_Multiplier;
        address rETH;
        uint96 rETH_Multiplier;
    }

    struct DeploymentConfig {
        uint32 taskResponseWindowBlock;
        address taskGenerator;
        address aggregator;
        address communityMultisig;
        address pauser;
        address churner;
        address ejector;
        address whitelister;
        address confirmer;
        uint256 numQuorum;
        uint32 maxOperatorCount;
        uint16 kickBIPsOfOperatorStake; // an operator needs to have kickBIPsOfOperatorStake / 10000 times the stake of the operator with the least stake to kick them out
        uint16 kickBIPsOfTotalStake; // an operator needs to have less than kickBIPsOfTotalStake / 10000 of the total stake to be kicked out
        uint96 minimumStake;
        bool operatorWhitelistEnabled;
        address[] operatorWhitelist;
    }

    struct StrategyConfig {
        address strategy;
        uint96 weight;
    }

    struct AuxContract {
        string name;
        address addr;
    }

    struct CoprocessorContracts {
        Coprocessor coprocessor;
        Coprocessor coprocessorImplementation;
        CoprocessorServiceManager serviceManager;
        CoprocessorServiceManager serviceManagerImplementation;
        IRegistryCoordinator registryCoordinator;
        IRegistryCoordinator registryCoordinatorImplementation;
        IIndexRegistry indexRegistry;
        IIndexRegistry indexRegistryImplementation;
        IStakeRegistry stakeRegistry;
        IStakeRegistry stakeRegistryImplementation;
        BLSApkRegistry apkRegistry;
        BLSApkRegistry apkRegistryImplementation;
        OperatorStateRetriever operatorStateRetriever;
        PauserRegistry pauserRegistry;
        ProxyAdmin proxyAdmin;
    }

    function readDeploymentParameters(string memory filePath)
        internal
        view
        returns (EigenLayerContracts memory, DeploymentConfig memory)
    {
        EigenLayerContracts memory eigenLayer;
        DeploymentConfig memory config;

        {
            string memory configData = vm.readFile(filePath);

            eigenLayer.strategyManager = StrategyManager(stdJson.readAddress(configData, ".strategyManager"));
            eigenLayer.avsDirectory = AVSDirectory(stdJson.readAddress(configData, ".avsDirectory"));
            eigenLayer.delegationManager = DelegationManager(stdJson.readAddress(configData, ".delegationManager"));
            eigenLayer.proxyAdmin = ProxyAdmin(stdJson.readAddress(configData, ".proxyAdmin"));
            eigenLayer.pauserRegistry = PauserRegistry(stdJson.readAddress(configData, ".pauserRegistry"));
            eigenLayer.baseStrategy =
                StrategyBaseTVLLimits(stdJson.readAddress(configData, ".baseStrategyImplementation"));
            eigenLayer.wETH = stdJson.readAddress(configData, ".wETH");
            eigenLayer.wETH_Multiplier = uint96(stdJson.readUint(configData, ".wETH_Multiplier"));
            eigenLayer.rETH = stdJson.readAddress(configData, ".rETH");
            eigenLayer.rETH_Multiplier = uint96(stdJson.readUint(configData, ".rETH_Multiplier"));

            {
                config.taskResponseWindowBlock = uint32(stdJson.readUint(configData, ".taskResponseWindowBlock"));
                config.taskGenerator = stdJson.readAddress(configData, ".taskGenerator");
                config.aggregator = stdJson.readAddress(configData, ".aggregator");
                config.communityMultisig = stdJson.readAddress(configData, ".owner");
                config.churner = stdJson.readAddress(configData, ".churner");
                config.ejector = stdJson.readAddress(configData, ".ejector");
                config.confirmer = stdJson.readAddress(configData, ".confirmer");
                config.whitelister = stdJson.readAddress(configData, ".whitelister");
                config.operatorWhitelistEnabled = stdJson.readBool(configData, ".operatorWhitelistEnabled");
                config.operatorWhitelist = stdJson.readAddressArray(configData, ".operatorWhitelist");
            }
        }

        config.numQuorum = 1;
        config.maxOperatorCount = 50;
        config.kickBIPsOfOperatorStake = 11000;
        config.kickBIPsOfTotalStake = 1001;
        config.minimumStake = 0;

        return (eigenLayer, config);
    }

    function deployAVS(
        EigenLayerContracts memory eigenLayer,
        DeploymentConfig memory config,
        StrategyConfig[] memory strategyConfig
    ) internal returns (CoprocessorContracts memory) {
        CoprocessorContracts memory contracts;

        // deploy proxy admin for ability to upgrade proxy contracts
        contracts.proxyAdmin = new ProxyAdmin();

        // deploy pauser registry
        {
            address[] memory pausers = new address[](1);
            pausers[0] = config.communityMultisig;
            contracts.pauserRegistry = new PauserRegistry(pausers, config.communityMultisig);
        }

        EmptyContract emptyContract = new EmptyContract();

        /**
         * First, deploy upgradeable proxy contracts that **will point** to the implementations. Since the implementation contracts are
         * not yet deployed, we give these proxies an empty contract as the initial implementation, to act as if they have no code.
         */
        contracts.indexRegistry = IIndexRegistry(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(contracts.proxyAdmin), ""))
        );

        contracts.stakeRegistry = IStakeRegistry(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(contracts.proxyAdmin), ""))
        );
        contracts.apkRegistry = BLSApkRegistry(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(contracts.proxyAdmin), ""))
        );
        contracts.registryCoordinator = RegistryCoordinator(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(contracts.proxyAdmin), ""))
        );
        contracts.coprocessor = Coprocessor(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(contracts.proxyAdmin), ""))
        );
        contracts.serviceManager = CoprocessorServiceManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(contracts.proxyAdmin), ""))
        );

        contracts.operatorStateRetriever = new OperatorStateRetriever();

        // Second, deploy the *implementation* contracts, using the *proxy contracts* as inputs
        contracts.indexRegistryImplementation = new IndexRegistry(contracts.registryCoordinator);
        contracts.proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(contracts.indexRegistry))),
            address(contracts.indexRegistryImplementation)
        );

        contracts.stakeRegistryImplementation =
            new StakeRegistry(contracts.registryCoordinator, eigenLayer.delegationManager);
        contracts.proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(contracts.stakeRegistry))),
            address(contracts.stakeRegistryImplementation)
        );

        contracts.apkRegistryImplementation = new BLSApkRegistry(contracts.registryCoordinator);
        contracts.proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(contracts.apkRegistry))),
            address(contracts.apkRegistryImplementation)
        );

        contracts.registryCoordinatorImplementation = new RegistryCoordinator(
            contracts.serviceManager,
            IStakeRegistry(address(contracts.stakeRegistry)),
            IBLSApkRegistry(address(contracts.apkRegistry)),
            IndexRegistry(address(contracts.indexRegistry))
        );

        {
            // for each quorum to setup, we need to define
            // QuorumOperatorSetParam, minimumStakeForQuorum, and strategyParams
            IRegistryCoordinator.OperatorSetParam[] memory quorumsOperatorSetParams =
                new IRegistryCoordinator.OperatorSetParam[](config.numQuorum);
            for (uint256 i = 0; i < config.numQuorum; i++) {
                // hard code these for now
                quorumsOperatorSetParams[i] = IRegistryCoordinator.OperatorSetParam({
                    maxOperatorCount: config.maxOperatorCount,
                    kickBIPsOfOperatorStake: config.kickBIPsOfOperatorStake,
                    kickBIPsOfTotalStake: config.kickBIPsOfTotalStake
                });
            }

            // set to 0 for every quorum
            uint96[] memory minimumStakeForQuourm = new uint96[](config.numQuorum);
            for (uint256 i = 0; i < config.numQuorum; i++) {
                minimumStakeForQuourm[i] = config.minimumStake;
            }

            IStakeRegistry.StrategyParams[][] memory strategyParams =
                new IStakeRegistry.StrategyParams[][](config.numQuorum);
            for (uint256 i = 0; i < config.numQuorum; i++) {
                IStakeRegistry.StrategyParams[] memory params =
                    new IStakeRegistry.StrategyParams[](strategyConfig.length);
                for (uint256 j = 0; j < strategyConfig.length; j++) {
                    params[j] = IStakeRegistry.StrategyParams({
                        strategy: IStrategy(strategyConfig[j].strategy),
                        multiplier: strategyConfig[j].weight
                    });
                }
                strategyParams[i] = params;
            }

            // initialize registry coordinator
            contracts.proxyAdmin.upgradeAndCall(
                TransparentUpgradeableProxy(payable(address(contracts.registryCoordinator))),
                address(contracts.registryCoordinatorImplementation),
                abi.encodeWithSelector(
                    RegistryCoordinator.initialize.selector,
                    config.communityMultisig,
                    config.churner,
                    config.ejector,
                    contracts.pauserRegistry,
                    0, // 0 initialPausedStatus means everything unpaused
                    quorumsOperatorSetParams,
                    minimumStakeForQuourm,
                    strategyParams
                )
            );
        }

        // Third, upgrade the proxy contracts to use the correct implementation contracts and initialize them.
        contracts.coprocessorImplementation = new Coprocessor(contracts.registryCoordinator);
        contracts.proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(contracts.coprocessor))),
            address(contracts.coprocessorImplementation),
            abi.encodeWithSelector(
                Coprocessor.initialize.selector,
                contracts.pauserRegistry,
                config.communityMultisig,
                config.aggregator,
                config.taskGenerator
            )
        );

        contracts.serviceManagerImplementation = new CoprocessorServiceManager(
            eigenLayer.avsDirectory, contracts.registryCoordinator, contracts.stakeRegistry
        );
        contracts.proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(contracts.serviceManager))),
            address(contracts.serviceManagerImplementation),
            abi.encodeWithSelector(
                CoprocessorServiceManager.initialize.selector,
                contracts.coprocessor,
                config.operatorWhitelistEnabled,
                config.operatorWhitelist
            )
        );

        return contracts;
    }

    function writeDeploymentOutput(
        CoprocessorContracts memory contracts,
        AuxContract[] memory auxContracts,
        string memory outputPath
    ) internal {
        string memory parent_object = "parent object";
        string memory addresses = "addresses";
        for (uint256 i = 0; i < auxContracts.length; i++) {
            vm.serializeAddress(addresses, auxContracts[i].name, address(auxContracts[i].addr));
        }
        vm.serializeAddress(addresses, "coprocessor", address(contracts.coprocessor));
        vm.serializeAddress(addresses, "coprocessorImpl", address(contracts.coprocessorImplementation));
        vm.serializeAddress(addresses, "serviceManager", address(contracts.serviceManager));
        vm.serializeAddress(addresses, "serviceManagerImpl", address(contracts.serviceManagerImplementation));
        vm.serializeAddress(addresses, "registryCoordinator", address(contracts.registryCoordinator));
        vm.serializeAddress(addresses, "registryCoordinatorImpl", address(contracts.registryCoordinatorImplementation));
        vm.serializeAddress(addresses, "indexRegistry", address(contracts.indexRegistry));
        vm.serializeAddress(addresses, "indexRegistryImpl", address(contracts.indexRegistryImplementation));
        vm.serializeAddress(addresses, "stakeRegistry", address(contracts.stakeRegistry));
        vm.serializeAddress(addresses, "stakeRegistryImpl", address(contracts.stakeRegistryImplementation));
        vm.serializeAddress(addresses, "apkRegistry", address(contracts.apkRegistry));
        vm.serializeAddress(addresses, "apkRegistryImpl", address(contracts.apkRegistryImplementation));
        vm.serializeAddress(addresses, "operatorStateRetriever", address(contracts.operatorStateRetriever));
        vm.serializeAddress(addresses, "pauserRegistry", address(contracts.pauserRegistry));
        string memory addresses_output = vm.serializeAddress(addresses, "proxyAdmin", address(contracts.proxyAdmin));
        string memory finalJson = vm.serializeString(parent_object, addresses, addresses_output);
        vm.writeJson(finalJson, outputPath);
    }
}
