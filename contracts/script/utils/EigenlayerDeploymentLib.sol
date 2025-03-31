// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

import {IPermissionController} from "@eigenlayer/interfaces/IPermissionController.sol";
import {PermissionController} from "@eigenlayer/permissions/PermissionController.sol";
import {DelegationManager} from "@eigenlayer/core/DelegationManager.sol";
import {AllocationManager} from "@eigenlayer/core/AllocationManager.sol";
import {StrategyManager} from "@eigenlayer/core/StrategyManager.sol";
import {AVSDirectory} from "@eigenlayer/core/AVSDirectory.sol";
import {EigenPodManager} from "@eigenlayer/pods/EigenPodManager.sol";
import {IRewardsCoordinatorTypes} from "@eigenlayer/interfaces/IRewardsCoordinator.sol";
import {RewardsCoordinator} from "@eigenlayer/core/RewardsCoordinator.sol";
import {StrategyBase} from "@eigenlayer/strategies/StrategyBase.sol";
import {EigenPod} from "@eigenlayer/pods/EigenPod.sol";
import {IETHPOSDeposit} from "@eigenlayer/interfaces/IETHPOSDeposit.sol";
import {StrategyBaseTVLLimits} from "@eigenlayer/strategies/StrategyBaseTVLLimits.sol";
import {PauserRegistry} from "@eigenlayer/permissions/PauserRegistry.sol";
import {IStrategy} from "@eigenlayer/interfaces/IStrategy.sol";
import {IDelegationManager} from "@eigenlayer/interfaces/IDelegationManager.sol";
import {IStrategyManager} from "@eigenlayer/interfaces/IStrategyManager.sol";
import {IEigenPodManager} from "@eigenlayer/interfaces/IEigenPodManager.sol";
import {IAVSDirectory} from "@eigenlayer/interfaces/IAVSDirectory.sol";
import {IPauserRegistry} from "@eigenlayer/interfaces/IPauserRegistry.sol";
import {StrategyFactory} from "@eigenlayer/strategies/StrategyFactory.sol";
import {IAllocationManager} from "@eigenlayer/interfaces/IAllocationManager.sol";

import {UpgradeableProxyLib} from "./UpgradeableProxyLib.sol";

library EigenlayerDeploymentLib {
    using stdJson for *;
    using Strings for *;
    using UpgradeableProxyLib for address;

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    string internal constant EIGENLAYER_VERSION = "v1.4.0-testnet-holesky";

    struct StrategyManagerConfig {
        uint256 initPausedStatus;
        uint256 initWithdrawalDelayBlocks;
    }

    struct DelegationManagerConfig {
        uint256 initPausedStatus;
        uint256 withdrawalDelayBlocks;
    }

    struct EigenPodManagerConfig {
        uint256 initPausedStatus;
    }

    struct RewardsCoordinatorConfig {
        uint256 initPausedStatus;
        uint256 maxRewardsDuration;
        uint256 maxRetroactiveLength;
        uint256 maxFutureLength;
        uint256 genesisRewardsTimestamp;
        address updater;
        uint256 activationDelay;
        uint256 calculationIntervalSeconds;
        uint256 globalOperatorCommissionBips;
    }

    struct StrategyFactoryConfig {
        uint256 initPausedStatus;
    }

    struct DeploymentConfig {
        StrategyManagerConfig strategyManager;
        DelegationManagerConfig delegationManager;
        EigenPodManagerConfig eigenPodManager;
        RewardsCoordinatorConfig rewardsCoordinator;
        StrategyFactoryConfig strategyFactory;
    }

    struct Deployment {
        address proxyAdmin;
        address delegationManager;
        address avsDirectory;
        address strategyManager;
        address eigenPodManager;
        address allocationManager;
        address rewardsCoordinator;
        address eigenPodBeacon;
        address pauserRegistry;
        address strategyFactory;
        address strategyBeacon;
        address permissionController;
    }

    function deployContracts(
        DeploymentConfig memory config,
        address deployer
    ) internal returns (Deployment memory) {
        Deployment memory result;

        result.proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();
        result.delegationManager = UpgradeableProxyLib.setUpEmptyProxy(result.proxyAdmin);
        result.avsDirectory = UpgradeableProxyLib.setUpEmptyProxy(result.proxyAdmin);
        result.strategyManager = UpgradeableProxyLib.setUpEmptyProxy(result.proxyAdmin);
        result.allocationManager = UpgradeableProxyLib.setUpEmptyProxy(result.proxyAdmin);
        result.avsDirectory = UpgradeableProxyLib.setUpEmptyProxy(result.proxyAdmin);
        result.rewardsCoordinator = UpgradeableProxyLib.setUpEmptyProxy(result.proxyAdmin);
        result.eigenPodBeacon = UpgradeableProxyLib.setUpEmptyProxy(result.proxyAdmin);
        result.pauserRegistry = address(
            new PauserRegistry(
                new address[](0), // Empty array for pausers
                result.proxyAdmin // result.proxyAdmin as the unpauser
            )
        );
        result.strategyFactory = UpgradeableProxyLib.setUpEmptyProxy(result.proxyAdmin);
        result.eigenPodManager = UpgradeableProxyLib.setUpEmptyProxy(result.proxyAdmin);
        result.permissionController = UpgradeableProxyLib.setUpEmptyProxy(result.proxyAdmin);

        // Deploy the implementation contracts, using the proxy contracts as inputs
        address delegationManagerImpl = address(
            new DelegationManager(
                IStrategyManager(result.strategyManager),
                IEigenPodManager(result.eigenPodManager),
                IAllocationManager(result.allocationManager),
                IPauserRegistry(result.pauserRegistry),
                IPermissionController(result.permissionController),
                // IAVSDirectory(result.avsDirectory),
                uint32(0), // TODO: check minWithdrawalDelay
                EIGENLAYER_VERSION
            )
        );
        address permissionControllerImpl = address(new PermissionController(EIGENLAYER_VERSION));

        address avsDirectoryImpl = address(
            new AVSDirectory(
                IDelegationManager(result.delegationManager),
                IPauserRegistry(result.pauserRegistry), // _DEALLOCATION_DELAY: 17.5 days in seconds),
                EIGENLAYER_VERSION
            )
        );

        address strategyManagerImpl = address(
            new StrategyManager(
                IDelegationManager(result.delegationManager),
                IPauserRegistry(result.pauserRegistry),
                EIGENLAYER_VERSION
            )
        );

        address strategyFactoryImpl = address(
            new StrategyFactory(
                IStrategyManager(result.strategyManager),
                IPauserRegistry(result.pauserRegistry),
                EIGENLAYER_VERSION
            )
        );

        address allocationManagerImpl = address(
            new AllocationManager(
                IDelegationManager(result.delegationManager),
                IPauserRegistry(result.pauserRegistry),
                IPermissionController(result.permissionController),
                // IAVSDirectory(result.avsDirectory),
                uint32(0), // _DEALLOCATION_DELAY
                uint32(0), // _ALLOCATION_CONFIGURATION_DELAY
                EIGENLAYER_VERSION
            )
        );

        address ethPOSDeposit;
        if (block.chainid == 1) {
            ethPOSDeposit = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
        } else {
            // For non-mainnet chains, you might want to deploy a mock or read from a config
            // This assumes you have a similar config setup as in M2_Deploy_From_Scratch.s.sol
            /// TODO: Handle Eth pos
        }

        address eigenPodManagerImpl = address(
            new EigenPodManager(
                IETHPOSDeposit(ethPOSDeposit),
                IBeacon(result.eigenPodBeacon),
                IDelegationManager(result.delegationManager),
                IPauserRegistry(result.pauserRegistry),
                EIGENLAYER_VERSION
            )
        );

        /// TODO: Get actual values
        uint32 CALCULATION_INTERVAL_SECONDS = 1 days;
        uint32 MAX_REWARDS_DURATION = uint32(config.rewardsCoordinator.maxRewardsDuration);
        uint32 MAX_RETROACTIVE_LENGTH = uint32(config.rewardsCoordinator.maxRetroactiveLength);
        uint32 MAX_FUTURE_LENGTH = 1 days;
        uint32 GENESIS_REWARDS_TIMESTAMP = 10 days;
        address rewardsCoordinatorImpl = address(
            new RewardsCoordinator(
                IRewardsCoordinatorTypes.RewardsCoordinatorConstructorParams({
                    delegationManager: IDelegationManager(result.delegationManager),
                    strategyManager: IStrategyManager(result.strategyManager),
                    allocationManager: IAllocationManager(result.allocationManager),
                    pauserRegistry: IPauserRegistry(result.pauserRegistry),
                    permissionController: IPermissionController(result.permissionController),
                    CALCULATION_INTERVAL_SECONDS: CALCULATION_INTERVAL_SECONDS,
                    MAX_REWARDS_DURATION: MAX_REWARDS_DURATION,
                    MAX_RETROACTIVE_LENGTH: MAX_RETROACTIVE_LENGTH,
                    MAX_FUTURE_LENGTH: MAX_FUTURE_LENGTH,
                    GENESIS_REWARDS_TIMESTAMP: GENESIS_REWARDS_TIMESTAMP,
                    version: EIGENLAYER_VERSION
                })
            )
        );

        uint64 GENESIS_TIME = 1_564_000;

        address eigenPodImpl = address(
            new EigenPod(
                IETHPOSDeposit(ethPOSDeposit),
                IEigenPodManager(result.eigenPodManager),
                GENESIS_TIME,
                EIGENLAYER_VERSION
            )
        );
        address baseStrategyImpl = address(
            new StrategyBase(
                IStrategyManager(result.strategyManager),
                IPauserRegistry(result.pauserRegistry),
                EIGENLAYER_VERSION
            )
        );
        /// TODO: PauserRegistry isn't upgradeable

        // Deploy and configure the strategy beacon
        result.strategyBeacon = address(new UpgradeableBeacon(baseStrategyImpl));

        // Upgrade contracts
        bytes memory upgradeCall = abi.encodeCall(
            DelegationManager.initialize,
            (
                result.proxyAdmin, // initialOwner
                // IPauserRegistry(result.pauserRegistry), // _pauserRegistry
                config.delegationManager.initPausedStatus // initialPausedStatus
            )
        );
        UpgradeableProxyLib.upgradeAndCall(
            result.delegationManager, delegationManagerImpl, upgradeCall
        );

        // Upgrade StrategyManager contract
        upgradeCall = abi.encodeCall(
            StrategyManager.initialize,
            (
                result.proxyAdmin, // initialOwner
                result.strategyFactory, // initialStrategyWhitelister
                // IPauserRegistry(result.pauserRegistry), // _pauserRegistry
                config.strategyManager.initPausedStatus // initialPausedStatus
            )
        );

        UpgradeableProxyLib.upgradeAndCall(result.strategyManager, strategyManagerImpl, upgradeCall);
        UpgradeableProxyLib.upgrade(result.permissionController, permissionControllerImpl);

        // Upgrade StrategyFactory contract
        upgradeCall = abi.encodeCall(
            StrategyFactory.initialize,
            (
                result.proxyAdmin, // initialOwner
                // IPauserRegistry(result.pauserRegistry), // _pauserRegistry
                config.strategyFactory.initPausedStatus, // initialPausedStatus
                IBeacon(result.strategyBeacon)
            )
        );
        UpgradeableProxyLib.upgradeAndCall(result.strategyFactory, strategyFactoryImpl, upgradeCall);

        // Upgrade EigenPodManager contract
        upgradeCall = abi.encodeCall(
            EigenPodManager.initialize,
            (
                result.proxyAdmin, // initialOwner
                // IPauserRegistry(result.pauserRegistry), // _pauserRegistry
                config.eigenPodManager.initPausedStatus // initialPausedStatus
            )
        );
        UpgradeableProxyLib.upgradeAndCall(result.eigenPodManager, eigenPodManagerImpl, upgradeCall);

        // Upgrade AVSDirectory contract
        upgradeCall = abi.encodeCall(
            AVSDirectory.initialize,
            (
                result.proxyAdmin, // initialOwner
                // IPauserRegistry(result.pauserRegistry), // _pauserRegistry
                0 // TODO: AVS Missing configinitialPausedStatus
            )
        );
        UpgradeableProxyLib.upgradeAndCall(result.avsDirectory, avsDirectoryImpl, upgradeCall);

        // Upgrade RewardsCoordinator contract
        upgradeCall = abi.encodeCall(
            RewardsCoordinator.initialize,
            (
                deployer, // initialOwner
                // IPauserRegistry(result.pauserRegistry), // _pauserRegistry
                config.rewardsCoordinator.initPausedStatus, // initialPausedStatus
                /// TODO: is there a setter and is this expected?
                deployer, // rewards updater
                uint32(config.rewardsCoordinator.activationDelay), // _activationDelay
                uint16(config.rewardsCoordinator.globalOperatorCommissionBips) // _globalCommissionBips
            )
        );
        UpgradeableProxyLib.upgradeAndCall(
            result.rewardsCoordinator, rewardsCoordinatorImpl, upgradeCall
        );

        // Upgrade EigenPod contract
        upgradeCall = abi.encodeCall(
            EigenPod.initialize,
            // TODO: Double check this
            (address(result.eigenPodManager)) // _podOwner
        );
        UpgradeableProxyLib.upgradeAndCall(result.eigenPodBeacon, eigenPodImpl, upgradeCall);

        // Upgrade AllocationManager contract
        upgradeCall = abi.encodeCall(
            AllocationManager.initialize,
            // TODO: Double check this
            (
                deployer, // initialOwner
                // IPauserRegistry(result.pauserRegistry), // _pauserRegistry
                config.delegationManager.initPausedStatus // initialPausedStatus
            )
        );
        UpgradeableProxyLib.upgradeAndCall(
            result.allocationManager, allocationManagerImpl, upgradeCall
        );

        return result;
    }

    // StrategyConfig[] strategies;

    function readDeploymentConfig(
        string memory pathToFile
    ) internal returns (DeploymentConfig memory) {
        require(vm.exists(pathToFile), "Deployment file does not exist");

        string memory json = vm.readFile(pathToFile);

        DeploymentConfig memory config;

        // StrategyManager
        config.strategyManager.initPausedStatus = json.readUint(".strategyManager.init_paused_status");
        config.strategyManager.initWithdrawalDelayBlocks =
            uint32(json.readUint(".strategyManager.init_withdrawal_delay_blocks"));
        
        // DelegationManager
        config.delegationManager.initPausedStatus = json.readUint(".delegation.init_paused_status");
        config.delegationManager.withdrawalDelayBlocks =
            json.readUint(".delegation.init_withdrawal_delay_blocks");
        
        // EigenPodManager
        config.eigenPodManager.initPausedStatus = json.readUint(".eigenPodManager.init_paused_status");

        // RewardsCoordinator
        config.rewardsCoordinator.initPausedStatus =
            json.readUint(".rewardsCoordinator.init_paused_status");
        config.rewardsCoordinator.maxRewardsDuration =
            json.readUint(".rewardsCoordinator.MAX_REWARDS_DURATION");
        config.rewardsCoordinator.maxRetroactiveLength =
            json.readUint(".rewardsCoordinator.MAX_RETROACTIVE_LENGTH");
        config.rewardsCoordinator.maxFutureLength =
            json.readUint(".rewardsCoordinator.MAX_FUTURE_LENGTH");
        config.rewardsCoordinator.genesisRewardsTimestamp =
            json.readUint(".rewardsCoordinator.GENESIS_REWARDS_TIMESTAMP");
        config.rewardsCoordinator.updater =
            json.readAddress(".rewardsCoordinator.rewards_updater_address");
        config.rewardsCoordinator.activationDelay =
            json.readUint(".rewardsCoordinator.activation_delay");
        config.rewardsCoordinator.calculationIntervalSeconds =
            json.readUint(".rewardsCoordinator.calculation_interval_seconds");
        config.rewardsCoordinator.globalOperatorCommissionBips =
            json.readUint(".rewardsCoordinator.global_operator_commission_bips");

        // StrategyFactory
        config.strategyManager.initPausedStatus = 
            json.readUint(".strategyFactory.init_paused_status");

        return config;
    }

    function readDeployment(
        string memory pathToFile
    ) internal returns (Deployment memory) {
        require(vm.exists(pathToFile), "Deployment file does not exist");

        string memory json = vm.readFile(pathToFile);

        Deployment memory deployment;
        deployment.proxyAdmin = json.readAddress(".addresses.proxyAdmin");
        deployment.delegationManager = json.readAddress(".addresses.delegationManager");
        deployment.avsDirectory = json.readAddress(".addresses.avsDirectory");
        deployment.strategyManager = json.readAddress(".addresses.strategyManager");
        deployment.eigenPodManager = json.readAddress(".addresses.eigenPodManager");
        deployment.allocationManager = json.readAddress(".addresses.allocationManager");
        deployment.rewardsCoordinator = json.readAddress(".addresses.rewardsCoordinator");
        deployment.eigenPodBeacon = json.readAddress(".addresses.eigenPodBeacon");
        deployment.pauserRegistry = json.readAddress(".addresses.pauserRegistry");
        deployment.strategyFactory = json.readAddress(".addresses.strategyFactory");
        deployment.strategyBeacon = json.readAddress(".addresses.strategyBeacon");
        deployment.permissionController = json.readAddress(".addresses.permissionController");

        return deployment;
    }

    function writeDeployment(
        Deployment memory deployment,
        string memory filePath
    ) internal {
        string memory parentObject = "parent object";
        
        string memory addresses = "addresses";
        vm.serializeAddress(addresses, "proxyAdmin", address(deployment.proxyAdmin));
        vm.serializeAddress(addresses, "delegationManager", address(deployment.delegationManager));
        vm.serializeAddress(addresses, "avsDirectory", address(deployment.avsDirectory));
        vm.serializeAddress(addresses, "strategyManager", address(deployment.strategyManager));
        vm.serializeAddress(addresses, "eigenPodManager", address(deployment.eigenPodManager));
        vm.serializeAddress(addresses, "allocationManager", address(deployment.allocationManager));
        vm.serializeAddress(addresses, "rewardsCoordinator", address(deployment.rewardsCoordinator));
        vm.serializeAddress(addresses, "eigenPodBeacon", address(deployment.eigenPodBeacon));
        vm.serializeAddress(addresses, "pauserRegistry", address(deployment.pauserRegistry));
        vm.serializeAddress(addresses, "strategyFactory", address(deployment.strategyFactory));
        vm.serializeAddress(addresses, "strategyBeacon", address(deployment.strategyBeacon));
        vm.serializeAddress(addresses, "permissionController", address(deployment.permissionController));
        string memory adressesJson =
            vm.serializeAddress(addresses, "permissionController", address(deployment.permissionController));
        
        string memory deploymentJson = vm.serializeString(parentObject, addresses, adressesJson);
        vm.writeJson(deploymentJson, filePath);
    }
}