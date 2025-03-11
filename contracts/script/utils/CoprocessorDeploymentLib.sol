// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
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

library CoprocessorDeploymentLib {
    using stdJson for *;
    using Strings for *;
    using UpgradeableProxyLib for address;

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct DeploymentConfig {
        bool operatorWhitelistEnabled;
        address[] operatorWhitelist;
    }
    
    struct Deployment {
        address coprocessor;
        address coprocessorServiceManager;
        address registryCoordinator;
        address operatorStateRetriever;
        address blsapkRegistry;
        address indexRegistry;
        address stakeRegistry;
        address socketRegistry;
        address strategy;
        address pauserRegistry;
        address token;
        //address slasher;
    }

    function deployContracts(
        EigenlayerDeploymentLib.Deployment memory el_deployment,
        address proxyAdmin,
        address strategy,
        DeploymentConfig memory config,
        address admin
    ) internal returns (Deployment memory) {
        Deployment memory result;
        
        // 1. Deploy upgradeable proxy contracts that will point to the implementations
        result.coprocessor = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.coprocessorServiceManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.stakeRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.registryCoordinator = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.blsapkRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.indexRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.socketRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        //result.slasher = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.strategy = strategy;
        // OperatorStateRetriever operatorStateRetriever = new OperatorStateRetriever();
        result.operatorStateRetriever = address(new OperatorStateRetriever());

        // 2. Deploy the implementation contracts, using the proxy contracts as input
        
        // Deploy StakeRegistry
        address stakeRegistryImpl = address(
            new StakeRegistry(
                ISlashingRegistryCoordinator(result.registryCoordinator),
                IDelegationManager(el_deployment.delegationManager),
                IAVSDirectory(el_deployment.avsDirectory),
                IAllocationManager(el_deployment.allocationManager)
            )
        );

        // Deploy BLSApkRegistry
        address blsApkRegistryImpl =
            address(new BLSApkRegistry(IRegistryCoordinator(result.registryCoordinator)));
        
        // Deploy IndexRegistry
        address indexRegistryimpl =
            address(new IndexRegistry(IRegistryCoordinator(result.registryCoordinator)));
        
        // Deploy InstantSlasher
        /*
        address instantSlasherImpl = address(
            new InstantSlasher(
                IAllocationManager(el_deployment.allocationManager),
                ISlashingRegistryCoordinator(result.registryCoordinator),
                result.incredibleSquaringTaskManager
            )
        );
        */

        // Deploy SlashingRegistryCoordinator 
        address registryCoordinatorImpl = address( 
            new SlashingRegistryCoordinator(
                IStakeRegistry(result.stakeRegistry),
                IBLSApkRegistry(result.blsapkRegistry),
                IIndexRegistry(result.indexRegistry),
                ISocketRegistry(result.socketRegistry),
                IAllocationManager(el_deployment.allocationManager),
                IPauserRegistry(el_deployment.pauserRegistry)
            )
        );

        // Deploy PauserRegistry
        address[] memory pausers = new address[](2);
        pausers[0] = admin;
        pausers[1] = admin;
        PauserRegistry pausercontract = new PauserRegistry(pausers, admin);

        // Deploy Coprocessor
        address coprocessorImpl = address(
            new Coprocessor(ISlashingRegistryCoordinator(registryCoordinatorImpl))
        );

        // Deploy CoprocessorServiceManager
        address coprocessorSerivceManagerImpl = address(
            new CoprocessorServiceManager(
                IAVSDirectory(el_deployment.avsDirectory),
                IRewardsCoordinator(el_deployment.rewardsCoordinator),
                IPermissionController(el_deployment.permissionController),
                IAllocationManager(el_deployment.allocationManager),
                IStakeRegistry(stakeRegistryImpl),
                ISlashingRegistryCoordinator(registryCoordinatorImpl)
            )
        );

        // 3. Upgrade the proxy contracts to use the correct implementation contracts and initialize them
        
        // Upgrade StakeRegistry
        UpgradeableProxyLib.upgrade(result.stakeRegistry, stakeRegistryImpl);
        
        // Upgrade BlsApkRegistry
        UpgradeableProxyLib.upgrade(result.blsapkRegistry, blsApkRegistryImpl);
        
        // Upgrade IndexRegistry
        UpgradeableProxyLib.upgrade(result.indexRegistry, indexRegistryimpl);
        
        // Upgrade and initialize SlashingRegistryCoordinator
        bytes memory registryCoordinatorUpgradeCall = abi.encodeCall(
            SlashingRegistryCoordinator.initialize,
            (admin, admin, admin, 0, result.coprocessorServiceManager)
        );
        UpgradeableProxyLib.upgradeAndCall(
            result.registryCoordinator, registryCoordinatorImpl, registryCoordinatorUpgradeCall
        );

        // Upgrade and initialize Coprocessor
        bytes memory coprocessorUpgradeCall = abi.encodeCall(
            Coprocessor.initialize,
            (admin)
        );
        UpgradeableProxyLib.upgradeAndCall(
            result.coprocessor, coprocessorImpl, coprocessorUpgradeCall
        );

        // Upgrade and initialize CoprocessorServiceManager
        bytes memory coprocessorServiceManagerUpgradeCall = abi.encodeCall(
            CoprocessorServiceManager.initialize,
            (
                ICoprocessor(coprocessorImpl), 
                config.operatorWhitelistEnabled, 
                config.operatorWhitelist, 
                admin
            )
        );
        UpgradeableProxyLib.upgradeAndCall(
            result.coprocessorServiceManager, coprocessorSerivceManagerImpl, coprocessorServiceManagerUpgradeCall
        );

        /*
        // Initialize and upgrade InstantSlasher
        bytes memory slasherupgradecall = abi.encodeCall(
            InstantSlasher.initialize, (address(result.incredibleSquaringTaskManager))
        );
        UpgradeableProxyLib.upgradeAndCall(result.slasher, instantSlasherImpl, slasherupgradecall);
        */

        verify_deployment(result);

        return result;
    }

    function verify_deployment(
        Deployment memory deployment
    ) internal view {
        IBLSApkRegistry blsapkregistry =
            IRegistryCoordinator(deployment.registryCoordinator).blsApkRegistry();
        require(address(blsapkregistry) != address(0));
        IStakeRegistry stakeregistry =
            IRegistryCoordinator(deployment.registryCoordinator).stakeRegistry();
        require(address(stakeregistry) != address(0));
        IDelegationManager delegationmanager = IStakeRegistry(address(stakeregistry)).delegation();
        require(address(delegationmanager) != address(0));
    }

    function readDeployment(
        string memory filePath
    ) internal returns (Deployment memory) {
        require(vm.exists(filePath), "Deployment file does not exist");

        string memory json = vm.readFile(filePath);

        Deployment memory deployment;
        deployment.coprocessor =
            json.readAddress(".addresses.coprocessor");
        deployment.coprocessorServiceManager =
            json.readAddress(".addresses.coprocessorServiceManager");
        deployment.registryCoordinator = json.readAddress(".addresses.registryCoordinator");
        deployment.operatorStateRetriever = json.readAddress(".addresses.operatorStateRetriever");
        deployment.stakeRegistry = json.readAddress(".addresses.stakeRegistry");
        deployment.strategy = json.readAddress(".addresses.strategy");
        deployment.token = json.readAddress(".addresses.token");
        //deployment.slasher = json.readAddress(".addresses.instantSlasher");

        return deployment;
    }

    function writeDeploymentJson(
        Deployment memory deployment,
        string memory filePath
    ) internal {
        address proxyAdmin =
            address(UpgradeableProxyLib.getProxyAdmin(deployment.coprocessorServiceManager));

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
            _generateContractsJson(data, proxyAdmin),
            "}"
        );
    }

    function _generateContractsJson(
        Deployment memory data,
        address proxyAdmin
    ) private view returns (string memory) {
        return string.concat(
            '{"proxyAdmin":"',
            proxyAdmin.toHexString(),
            '","coprocessor":"',
            data.coprocessor.toHexString(),
            '","coprocessorServiceManager":"',
            data.coprocessorServiceManager.toHexString(),
            '","registryCoordinator":"',
            data.registryCoordinator.toHexString(),
            '","blsapkRegistry":"',
            data.blsapkRegistry.toHexString(),
            '","indexRegistry":"',
            data.indexRegistry.toHexString(),
            '","stakeRegistry":"',
            data.stakeRegistry.toHexString(),
            '","operatorStateRetriever":"',
            data.operatorStateRetriever.toHexString(),
            '","strategy":"',
            data.strategy.toHexString(),
            '","pauserRegistry":"',
            data.pauserRegistry.toHexString(),
            '","token":"',
            /*
            data.token.toHexString(),
            '","instantSlasher":"',
            data.slasher.toHexString(),
            */
            '"}'
        );
    }
}
