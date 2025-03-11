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
import {RewardsCoordinator} from "@eigenlayer/core/RewardsCoordinator.sol";
import {StrategyBase} from "@eigenlayer/strategies/StrategyBase.sol";
import {EigenPod} from "@eigenlayer/pods/EigenPod.sol";
import {IETHPOSDeposit} from "@eigenlayer/interfaces/IETHPOSDeposit.sol";
import {StrategyBaseTVLLimits} from "@eigenlayer/strategies/StrategyBaseTVLLimits.sol";
import {PauserRegistry} from "@eigenlayer/permissions/PauserRegistry.sol";
import {IStrategy} from "@eigenlayer/interfaces/IStrategy.sol";
import {ISignatureUtils} from "@eigenlayer/interfaces/ISignatureUtils.sol";
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
        address deployer,
        address proxyAdmin,
        DeploymentConfig memory config
    ) internal returns (Deployment memory) {
        Deployment memory result;

        result.delegationManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.avsDirectory = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.strategyManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.allocationManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.avsDirectory = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.rewardsCoordinator = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.eigenPodBeacon = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.pauserRegistry = address(
            new PauserRegistry(
                new address[](0), // Empty array for pausers
                proxyAdmin // ProxyAdmin as the unpauser
            )
        );
        result.strategyFactory = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.eigenPodManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.permissionController = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);

        // Deploy the implementation contracts, using the proxy contracts as inputs
        address delegationManagerImpl = address(
            new DelegationManager(
                IStrategyManager(result.strategyManager),
                IEigenPodManager(result.eigenPodManager),
                IAllocationManager(result.allocationManager),
                IPauserRegistry(result.pauserRegistry),
                IPermissionController(result.permissionController),
                // IAVSDirectory(result.avsDirectory),
                uint32(0) // TODO: check minWithdrawalDelay
            )
        );
        address permissionControllerImpl = address(new PermissionController());

        address avsDirectoryImpl = address(
            new AVSDirectory(
                IDelegationManager(result.delegationManager),
                IPauserRegistry(result.pauserRegistry) // _DEALLOCATION_DELAY: 17.5 days in seconds),
            )
        );

        address strategyManagerImpl = address(
            new StrategyManager(
                IDelegationManager(result.delegationManager), IPauserRegistry(result.pauserRegistry)
            )
        );

        address strategyFactoryImpl = address(
            new StrategyFactory(
                IStrategyManager(result.strategyManager), IPauserRegistry(result.pauserRegistry)
            )
        );

        address allocationManagerImpl = address(
            new AllocationManager(
                IDelegationManager(result.delegationManager),
                IPauserRegistry(result.pauserRegistry),
                IPermissionController(result.permissionController),
                // IAVSDirectory(result.avsDirectory),
                uint32(0), // _DEALLOCATION_DELAY
                uint32(0) // _ALLOCATION_CONFIGURATION_DELAY
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
                IPauserRegistry(result.pauserRegistry)
            )
        );

        /// TODO: Get actual values
        uint32 CALCULATION_INTERVAL_SECONDS = 1 days;
        uint32 MAX_REWARDS_DURATION = 1 days;
        uint32 MAX_RETROACTIVE_LENGTH = 200_000;
        uint32 MAX_FUTURE_LENGTH = 1 days;
        uint32 GENESIS_REWARDS_TIMESTAMP = 10 days;
        address rewardsCoordinatorImpl = address(
            new RewardsCoordinator(
                IDelegationManager(result.delegationManager),
                IStrategyManager(result.strategyManager),
                IAllocationManager(result.allocationManager),
                IPauserRegistry(result.pauserRegistry),
                IPermissionController(result.permissionController),
                CALCULATION_INTERVAL_SECONDS,
                MAX_REWARDS_DURATION,
                MAX_RETROACTIVE_LENGTH,
                MAX_FUTURE_LENGTH,
                GENESIS_REWARDS_TIMESTAMP
            )
        );

        uint64 GENESIS_TIME = 1_564_000;

        address eigenPodImpl = address(
            new EigenPod(
                IETHPOSDeposit(ethPOSDeposit),
                IEigenPodManager(result.eigenPodManager),
                GENESIS_TIME
            )
        );
        address eigenPodBeaconImpl = address(new UpgradeableBeacon(eigenPodImpl));
        address baseStrategyImpl = address(
            new StrategyBase(
                IStrategyManager(result.strategyManager), IPauserRegistry(result.pauserRegistry)
            )
        );
        /// TODO: PauserRegistry isn't upgradeable

        // Deploy and configure the strategy beacon
        result.strategyBeacon = address(new UpgradeableBeacon(baseStrategyImpl));

        // Upgrade contracts
        // / TODO: Get from config
        bytes memory upgradeCall = abi.encodeCall(
            DelegationManager.initialize,
            (
                proxyAdmin, // initialOwner
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
                proxyAdmin, // initialOwner
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
                proxyAdmin, // initialOwner
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
                proxyAdmin, // initialOwner
                // IPauserRegistry(result.pauserRegistry), // _pauserRegistry
                config.eigenPodManager.initPausedStatus // initialPausedStatus
            )
        );
        UpgradeableProxyLib.upgradeAndCall(result.eigenPodManager, eigenPodManagerImpl, upgradeCall);

        // Upgrade AVSDirectory contract
        upgradeCall = abi.encodeCall(
            AVSDirectory.initialize,
            (
                proxyAdmin, // initialOwner
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
        console2.log("888");
        console2.log(result.permissionController);

        return result;
    }

    // StrategyConfig[] strategies;

    function readDeploymentConfig(
        string memory pathToFile
    ) internal returns (DeploymentConfig memory) {
        require(vm.exists(pathToFile), "Deployment file does not exist");

        string memory json = vm.readFile(pathToFile);

        DeploymentConfig memory config;

        // StrategyManager start
        config.strategyManager.initPausedStatus = json.readUint(".strategyManager.init_paused_status");
        config.strategyManager.initWithdrawalDelayBlocks =
            uint32(json.readUint(".strategyManager.init_withdrawal_delay_blocks"));
        // StrategyManager config end

        // DelegationManager config start
        config.delegationManager.initPausedStatus = json.readUint(".delegation.init_paused_status");
        config.delegationManager.withdrawalDelayBlocks =
            json.readUint(".delegation.init_withdrawal_delay_blocks");
        // DelegationManager config end

        // EigenPodManager config start
        config.eigenPodManager.initPausedStatus = json.readUint(".eigenPodManager.init_paused_status");
        // EigenPodManager config end

        // RewardsCoordinator config start
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
        // RewardsCoordinator config end

        return config;
    }

    function readDeployment(
        string memory pathToFile
    ) internal returns (Deployment memory) {
        require(vm.exists(pathToFile), "Deployment file does not exist");

        string memory json = vm.readFile(pathToFile);

        Deployment memory deployment;
        deployment.strategyFactory = json.readAddress(".addresses.strategyFactory");
        deployment.strategyManager = json.readAddress(".addresses.strategyManager");
        deployment.eigenPodManager = json.readAddress(".addresses.eigenPodManager");
        deployment.delegationManager = json.readAddress(".addresses.delegation");
        deployment.avsDirectory = json.readAddress(".addresses.avsDirectory");
        deployment.rewardsCoordinator = json.readAddress(".addresses.rewardsCoordinator");
        deployment.allocationManager = json.readAddress(".addresses.allocationManager");
        deployment.permissionController = json.readAddress(".addresses.permissionController");

        return deployment;
    }

    function writeDeploymentJson(
        Deployment memory deployment,
        string memory filePath
    ) internal {
        address proxyAdmin = address(
                UpgradeableProxyLib.getProxyAdmin(deployment.strategyManager)
        );
        string memory deploymentJson = _generateDeploymentJson(deployment, proxyAdmin);
        vm.writeFile(filePath, deploymentJson);
    }

    function _generateDeploymentJson(
        Deployment memory data,
        address proxyAdmin
    ) private view returns (string memory) {
        return string.concat(
            '{"lastUpdate":{"timestamp":"',
            vm.toString(block.timestamp),
            '","block_number":"',
            vm.toString(block.number),
            '"},"addresses":',
            _generatDeploymentContractsJson(data, proxyAdmin),
            "}"
        );
    }

    function _generatDeploymentContractsJson(
        Deployment memory data,
        address proxyAdmin
    ) private view returns (string memory) {
        /// TODO: namespace contracts -> {avs, core}
        return string.concat(
            '{"proxyAdmin":"',
            proxyAdmin.toHexString(),
            '","delegation":"',
            data.delegationManager.toHexString(),
            '","delegationManagerImpl":"',
            data.delegationManager.getImplementation().toHexString(),
            '","avsDirectory":"',
            data.avsDirectory.toHexString(),
            '","avsDirectoryImpl":"',
            data.avsDirectory.getImplementation().toHexString(),
            '","strategyManager":"',
            data.strategyManager.toHexString(),
            '","strategyManagerImpl":"',
            data.strategyManager.getImplementation().toHexString(),
            '","eigenPodManager":"',
            data.eigenPodManager.toHexString(),
            '","eigenPodManagerImpl":"',
            data.eigenPodManager.getImplementation().toHexString(),
            '","strategyFactory":"',
            data.strategyFactory.toHexString(),
            '","rewardsCoordinator":"',
            data.rewardsCoordinator.toHexString(),
            '","pauserRegistry":"',
            data.pauserRegistry.toHexString(),
            '","strategyBeacon":"',
            data.strategyBeacon.toHexString(),
            '","allocationManager":"',
            data.allocationManager.toHexString(),
            '","permissionController":"',
            data.permissionController.toHexString(),
            '"}'
        );
    }
}