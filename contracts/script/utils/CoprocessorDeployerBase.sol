// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IAVSDirectory} from "@eigenlayer/interfaces/IAVSDirectory.sol";
import {IPermissionController} from "@eigenlayer/interfaces/IPermissionController.sol";
import {IDelegationManager} from "@eigenlayer/interfaces/IDelegationManager.sol";
import {IAllocationManager} from "@eigenlayer/interfaces/IAllocationManager.sol";
import {IStrategy} from "@eigenlayer/interfaces/IStrategyManager.sol";
import {IRewardsCoordinator} from "@eigenlayer/interfaces/IRewardsCoordinator.sol";
import {StrategyFactory} from "@eigenlayer/strategies/StrategyFactory.sol";
import {IAVSRegistrar} from "@eigenlayer/interfaces/IAVSRegistrar.sol";

import {IServiceManager} from "@eigenlayer-middleware/interfaces/IServiceManager.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/BLSApkRegistry.sol";
import {IndexRegistry} from "@eigenlayer-middleware/IndexRegistry.sol";
import {InstantSlasher} from "@eigenlayer-middleware/slashers/InstantSlasher.sol";
import {StakeRegistry} from "@eigenlayer-middleware/StakeRegistry.sol";
import {IRegistryCoordinator} from "@eigenlayer-middleware/interfaces/IRegistryCoordinator.sol";
import {ISocketRegistry, SocketRegistry} from "@eigenlayer-middleware/SocketRegistry.sol";
import {
    ISlashingRegistryCoordinator,
    ISlashingRegistryCoordinatorTypes
} from "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import {SlashingRegistryCoordinator} from
    "@eigenlayer-middleware/SlashingRegistryCoordinator.sol";
import {RegistryCoordinator} from "@eigenlayer-middleware/RegistryCoordinator.sol";
import {
    RegistryCoordinator,
    IBLSApkRegistry,
    IIndexRegistry,
    IStakeRegistry
} from
"@eigenlayer-middleware/RegistryCoordinator.sol";
import {IStakeRegistryTypes} from "@eigenlayer-middleware/interfaces/IStakeRegistry.sol";
import {
    PauserRegistry, IPauserRegistry
} from "@eigenlayer/permissions/PauserRegistry.sol";
import {OperatorStateRetriever} from "@eigenlayer-middleware/OperatorStateRetriever.sol";

import {EigenlayerDeploymentLib} from "./EigenlayerDeploymentLib.sol";
import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";

import {ICoprocessor} from "../../src/ICoprocessor.sol";
import {Coprocessor} from "../../src/Coprocessor.sol";
import {CoprocessorServiceManager} from "../../eigenlayer/CoprocessorServiceManager.sol";
import {ERC20Mock} from "../../src/ERC20Mock.sol";
import {Mock_L2Coprocessor} from "../../src/Mock_L2Coprocessor.sol";
import {MockL2CoprocessorCaller} from "../../src/Mock_L2CoprocessorCaller.sol";
import {Mock_L1_Sender, IMock_L2Coprocessor} from "../../src/Mock_L1_Sender.sol";
import {CoprocessorToL2} from "../../src/CoprocessorToL2.sol";

import "./EigenlayerDeploymentLib.sol";

contract CoprocessorDeployerBase is Script {
    using stdJson for *;
    using Strings for *;
    using UpgradeableProxyLib for address;

    string internal constant MIDDLEWARE_VERSION = "v1.4.0-testnet-holesky";

    struct DeploymentConfig {
        address registryCoordinatorOwner;
        address churnApprover;
        address ejector;
        string metdataURI;

        bool operatorWhitelistEnabled;
        address[] operatorWhitelist;
    }
    
    struct Deployment {
        address proxyAdmin;
        
        address coprocessor;
        address coprocessorServiceManager;
        
        address registryCoordinator;
        address operatorStateRetriever;
        address blsApkRegistry;
        address indexRegistry;
        address stakeRegistry;
        address socketRegistry;
        address slasher;

        address strategyToken;
        address strategy;

        address L2Coprocessor;
        address L2CoprocessorCaller;
        address L1Sender;
        address coprocessorToL2;
    }

    EigenlayerDeploymentLib.Deployment el_deployment;
    DeploymentConfig config;

    Deployment deployment;

    function deployAvs() internal {
        vm.startBroadcast(config.registryCoordinatorOwner);
        
        // 1. Deploy upgradeable proxy contracts that will point to the implementations
        deployment.proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();
        
        deployment.coprocessor = UpgradeableProxyLib.setUpEmptyProxy(deployment.proxyAdmin);
        deployment.coprocessorServiceManager = UpgradeableProxyLib.setUpEmptyProxy(deployment.proxyAdmin);
        deployment.stakeRegistry = UpgradeableProxyLib.setUpEmptyProxy(deployment.proxyAdmin);
        deployment.registryCoordinator = UpgradeableProxyLib.setUpEmptyProxy(deployment.proxyAdmin);
        deployment.blsApkRegistry = UpgradeableProxyLib.setUpEmptyProxy(deployment.proxyAdmin);
        deployment.indexRegistry = UpgradeableProxyLib.setUpEmptyProxy(deployment.proxyAdmin);
        deployment.socketRegistry = UpgradeableProxyLib.setUpEmptyProxy(deployment.proxyAdmin);
        deployment.slasher = UpgradeableProxyLib.setUpEmptyProxy(deployment.proxyAdmin);

        // 2. Deploy the implementation contracts, using the proxy contracts as input
        
        // Deploy StakeRegistry
        address stakeRegistryImpl = address(
            new StakeRegistry(
                ISlashingRegistryCoordinator(deployment.registryCoordinator),
                IDelegationManager(el_deployment.delegationManager),
                IAVSDirectory(el_deployment.avsDirectory),
                IAllocationManager(el_deployment.allocationManager)
            )
        );

        // Deploy BLSApkRegistry
        address blsApkRegistryImpl =
            address(new BLSApkRegistry(IRegistryCoordinator(deployment.registryCoordinator)));
        
        // Deploy IndexRegistry
        address indexRegistryImpl =
            address(new IndexRegistry(IRegistryCoordinator(deployment.registryCoordinator)));
        
        // Deploy SocketRegistry
        address socketRegistryImpl =
            address(new SocketRegistry(IRegistryCoordinator(deployment.registryCoordinator)));

        // Deploy InstantSlasher
        address slasherImpl = address(
            new InstantSlasher(
                IAllocationManager(el_deployment.allocationManager),
                ISlashingRegistryCoordinator(deployment.registryCoordinator),
                deployment.coprocessor // for avs demo it's deployment.incredibleSquaringTaskManager, so?..
            )
        );
       
        // Deploy SlashingRegistryCoordinator 
        address registryCoordinatorImpl = address( 
            new SlashingRegistryCoordinator(
                IStakeRegistry(deployment.stakeRegistry),
                IBLSApkRegistry(deployment.blsApkRegistry),
                IIndexRegistry(deployment.indexRegistry),
                ISocketRegistry(deployment.socketRegistry),
                IAllocationManager(el_deployment.allocationManager),
                IPauserRegistry(el_deployment.pauserRegistry),
                MIDDLEWARE_VERSION
            )
        );

        deployment.operatorStateRetriever = address(new OperatorStateRetriever());

        // 3. Upgrade the proxy contracts to use the correct implementation contracts and initialize them
        
        // Upgrade StakeRegistry
        UpgradeableProxyLib.upgrade(deployment.stakeRegistry, stakeRegistryImpl);
        
        // Upgrade BlsApkRegistry
        UpgradeableProxyLib.upgrade(deployment.blsApkRegistry, blsApkRegistryImpl);
        
        // Upgrade IndexRegistry
        UpgradeableProxyLib.upgrade(deployment.indexRegistry, indexRegistryImpl);

        // Upgrade SocketRegistry
        UpgradeableProxyLib.upgrade(deployment.socketRegistry, socketRegistryImpl);
        
        // Upgrade and initialize SlashingRegistryCoordinator
        bytes memory registryCoordinatorUpgradeCall = abi.encodeCall(
            SlashingRegistryCoordinator.initialize,
            (
                config.registryCoordinatorOwner,
                config.churnApprover,
                config.ejector,
                0,
                deployment.coprocessorServiceManager
            )
        );
        UpgradeableProxyLib.upgradeAndCall(
            deployment.registryCoordinator, registryCoordinatorImpl, registryCoordinatorUpgradeCall
        );

         // Deploy Coprocessor
        address coprocessorImpl = address(
            new Coprocessor(ISlashingRegistryCoordinator(deployment.registryCoordinator))
        );

        // Deploy CoprocessorServiceManager
        address coprocessorSerivceManagerImpl = address(
            new CoprocessorServiceManager(
                IAVSDirectory(el_deployment.avsDirectory),
                IRewardsCoordinator(el_deployment.rewardsCoordinator),
                IPermissionController(el_deployment.permissionController),
                IAllocationManager(el_deployment.allocationManager),
                IStakeRegistry(deployment.stakeRegistry),
                ISlashingRegistryCoordinator(deployment.registryCoordinator)
            )
        );

        // Upgrade and initialize Coprocessor
        bytes memory coprocessorUpgradeCall = abi.encodeCall(
            Coprocessor.initialize,
            (config.registryCoordinatorOwner)
        );
        UpgradeableProxyLib.upgradeAndCall(
            deployment.coprocessor, coprocessorImpl, coprocessorUpgradeCall
        );

        // Upgrade and initialize CoprocessorServiceManager
        bytes memory coprocessorServiceManagerUpgradeCall = abi.encodeCall(
            CoprocessorServiceManager.initialize,
            (
                ICoprocessor(coprocessorImpl), 
                config.operatorWhitelistEnabled, 
                config.operatorWhitelist, 
                config.registryCoordinatorOwner
            )
        );
        UpgradeableProxyLib.upgradeAndCall(
            deployment.coprocessorServiceManager, coprocessorSerivceManagerImpl, coprocessorServiceManagerUpgradeCall
        );

        // Upgrade Slasher
        UpgradeableProxyLib.upgrade(deployment.slasher, slasherImpl);

        vm.stopBroadcast();
    }

     function verifyAvsDeployment() internal view {        
        IBLSApkRegistry blsapkregistry =
            IRegistryCoordinator(deployment.registryCoordinator).blsApkRegistry();
        require(address(blsapkregistry) != address(0));
        IStakeRegistry stakeregistry =
            IRegistryCoordinator(deployment.registryCoordinator).stakeRegistry();
        require(address(stakeregistry) != address(0));
        IDelegationManager delegationmanager = IStakeRegistry(address(stakeregistry)).delegation();
        require(address(delegationmanager) != address(0));
    }

    function setupAvsUamPermissions() internal {
        vm.startBroadcast(config.registryCoordinatorOwner);
        
        IServiceManager serviceManager =
            IServiceManager(deployment.coprocessorServiceManager);
        
        // 1. set AVS registrar
        serviceManager.setAppointee(
            config.registryCoordinatorOwner,
            el_deployment.allocationManager,
            AllocationManager.setAVSRegistrar.selector
        );

        // 2. set AVS metadata
        serviceManager.setAppointee(
            config.registryCoordinatorOwner, 
            el_deployment.allocationManager,
            AllocationManager.updateAVSMetadataURI.selector
        );

        // 3. create operator sets
        serviceManager.setAppointee(
            deployment.registryCoordinator,
            el_deployment.allocationManager,
            AllocationManager.createOperatorSets.selector
        );

        // 4. deregister operator from operator sets
        serviceManager.setAppointee(
            deployment.registryCoordinator,
            el_deployment.allocationManager,
            AllocationManager.deregisterFromOperatorSets.selector
        );

        // 5. add strategies to operator sets
        serviceManager.setAppointee(
            deployment.registryCoordinator,
            deployment.stakeRegistry,
            AllocationManager.addStrategiesToOperatorSet.selector
        );

        // 6. remove strategies from operator sets
        serviceManager.setAppointee(
            deployment.registryCoordinator,
            deployment.stakeRegistry,
            AllocationManager.removeStrategiesFromOperatorSet.selector
        );

        serviceManager.setAppointee(
            deployment.slasher,
            el_deployment.allocationManager,
            AllocationManager.slashOperator.selector
        );

        // Set AVS Registrar to RegistryCstartBroadcastoordinator
        IAllocationManager allocationManager = IAllocationManager(el_deployment.allocationManager);
        allocationManager.setAVSRegistrar(
            deployment.coprocessorServiceManager,
            IAVSRegistrar(deployment.registryCoordinator)
        );

        // Set AVS metadata URI
        allocationManager.updateAVSMetadataURI(
            deployment.coprocessorServiceManager, config.metdataURI
        );

        vm.stopBroadcast();
    }

    // TODO: setupAvsQuorums must read parameters of operator sets and strategies from json config
    function setupAvsQuorums() internal {
        vm.startBroadcast(config.registryCoordinatorOwner);
        
        ISlashingRegistryCoordinatorTypes.OperatorSetParam memory _operatorSetParam =
        ISlashingRegistryCoordinatorTypes.OperatorSetParam({
            maxOperatorCount: 3,
            kickBIPsOfOperatorStake: 100,
            kickBIPsOfTotalStake: 1000
        });
        uint96 minimumStake = 0;
        IStakeRegistryTypes.StrategyParams[] memory _strategyParams =
            new IStakeRegistryTypes.StrategyParams[](1);
        IStrategy istrategy = IStrategy(deployment.strategy);
        _strategyParams[0] =
            IStakeRegistryTypes.StrategyParams({strategy: istrategy, multiplier: 1});
        SlashingRegistryCoordinator regCoord =
            SlashingRegistryCoordinator(deployment.registryCoordinator);
        regCoord.createTotalDelegatedStakeQuorum(_operatorSetParam, minimumStake, _strategyParams);

        vm.stopBroadcast();
    }

    function deployStrategy() internal {
        vm.startBroadcast(config.registryCoordinatorOwner);
        
        deployment.strategyToken = address(new ERC20Mock());     
        deployment.strategy = address(
            StrategyFactory(el_deployment.strategyFactory)
               .deployNewStrategy(ERC20Mock(deployment.strategyToken))
        );

        vm.stopBroadcast();
    }

    function deployL1L2Bridge() internal {
        vm.startBroadcast(config.registryCoordinatorOwner);
        
        deployment.L2Coprocessor = address(
            new Mock_L2Coprocessor(address(0))
        );
        deployment.L2CoprocessorCaller = address(
            new MockL2CoprocessorCaller(deployment.L2Coprocessor)
        );

        deployment.L1Sender = address(
            new Mock_L1_Sender(IMock_L2Coprocessor(deployment.L2Coprocessor))
            );
        Mock_L2Coprocessor(deployment.L2Coprocessor).setL1Sender(deployment.L1Sender);

        deployment.coprocessorToL2 = address(
            new CoprocessorToL2(ISlashingRegistryCoordinator(deployment.registryCoordinator))
        );

        vm.stopBroadcast();
    }

    function writeDeployment(string memory filePath) internal {
         string memory parentObject = "parent object";
        
        string memory addresses = "addresses";
        vm.serializeAddress(addresses, "proxyAdmin", address(deployment.proxyAdmin));
        vm.serializeAddress(addresses, "coprocessor", address(deployment.coprocessor));
        vm.serializeAddress(addresses, "coprocessorServiceManager", address(deployment.coprocessorServiceManager));
        vm.serializeAddress(addresses, "registryCoordinator", address(deployment.registryCoordinator));
        vm.serializeAddress(addresses, "operatorStateRetriever", address(deployment.operatorStateRetriever));
        vm.serializeAddress(addresses, "blsApkRegistry", address(deployment.blsApkRegistry));
        vm.serializeAddress(addresses, "indexRegistry", address(deployment.indexRegistry));
        vm.serializeAddress(addresses, "stakeRegistry", address(deployment.stakeRegistry));
        vm.serializeAddress(addresses, "socketRegistry", address(deployment.socketRegistry));
        vm.serializeAddress(addresses, "slasher", address(deployment.slasher));
        vm.serializeAddress(addresses, "strategyToken", address(deployment.strategyToken));
        vm.serializeAddress(addresses, "strategy", address(deployment.strategy));
        vm.serializeAddress(addresses, "l2Coprocessor", address(deployment.L2Coprocessor));
        vm.serializeAddress(addresses, "l2CoprocessorCaller", address(deployment.L2CoprocessorCaller));
        vm.serializeAddress(addresses, "l1Sender", address(deployment.L1Sender));
        string memory adressesJson =
            vm.serializeAddress(addresses, "coprocessorToL2", address(deployment.coprocessorToL2));
        
        string memory deploymentJson = vm.serializeString(parentObject, addresses, adressesJson);
        vm.writeJson(deploymentJson, filePath);
    }

    // TODO: this doesn't actually advance by n blocks... maybe because broadcasting batches txs somehow..?
    function advanceChainByNBlocks(uint256 n) public {
        for (uint256 i = 0; i < n; i++) {
            // we transfer eth to ourselves to advance the block
            vm.broadcast(msg.sender);
            payable(msg.sender).transfer(1 wei);
        }
    }
}