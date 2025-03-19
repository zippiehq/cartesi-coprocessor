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

    struct DeploymentConfig {
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
        address pauserRegistry;
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

    function deployAvs(address deployer, address admin) internal {
        vm.startBroadcast(deployer);
        
        // 1. Deploy upgradeable proxy contracts that will point to the implementations
        deployment.proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();
        
        deployment.coprocessor = UpgradeableProxyLib.setUpEmptyProxy(deployment.proxyAdmin);
        deployment.coprocessorServiceManager = UpgradeableProxyLib.setUpEmptyProxy(deployment.proxyAdmin);
        
        deployment.stakeRegistry = UpgradeableProxyLib.setUpEmptyProxy(deployment.proxyAdmin);
        deployment.registryCoordinator = UpgradeableProxyLib.setUpEmptyProxy(deployment.proxyAdmin);
        deployment.operatorStateRetriever = address(new OperatorStateRetriever());
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
        address indexRegistryimpl =
            address(new IndexRegistry(IRegistryCoordinator(deployment.registryCoordinator)));
        
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
                IPauserRegistry(el_deployment.pauserRegistry)
            )
        );

        // Deploy PauserRegistry
        address[] memory pausers = new address[](2);
        pausers[0] = admin;
        pausers[1] = admin;
        deployment.pauserRegistry = address(new PauserRegistry(pausers, admin));

        // 3. Upgrade the proxy contracts to use the correct implementation contracts and initialize them
        
        // Upgrade StakeRegistry
        UpgradeableProxyLib.upgrade(deployment.stakeRegistry, stakeRegistryImpl);
        
        // Upgrade BlsApkRegistry
        UpgradeableProxyLib.upgrade(deployment.blsApkRegistry, blsApkRegistryImpl);
        
        // Upgrade IndexRegistry
        UpgradeableProxyLib.upgrade(deployment.indexRegistry, indexRegistryimpl);
        
        // Upgrade and initialize SlashingRegistryCoordinator
        bytes memory registryCoordinatorUpgradeCall = abi.encodeCall(
            SlashingRegistryCoordinator.initialize,
            (admin, admin, admin, 0, deployment.coprocessorServiceManager)
        );
        UpgradeableProxyLib.upgradeAndCall(
            deployment.registryCoordinator, registryCoordinatorImpl, registryCoordinatorUpgradeCall
        );

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

        // Upgrade and initialize Coprocessor
        bytes memory coprocessorUpgradeCall = abi.encodeCall(
            Coprocessor.initialize,
            (admin)
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
                admin
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

    function deployStrategy(address deployer) internal {
        vm.startBroadcast(deployer);
        
        deployment.strategyToken = address(new ERC20Mock());     
        deployment.strategy = address(
            StrategyFactory(el_deployment.strategyFactory)
               .deployNewStrategy(ERC20Mock(deployment.strategyToken))
        );

        vm.stopBroadcast();
    }

    function deployL1L2Bridge(address deployer) internal {
        vm.startBroadcast(deployer);
        
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
    
    function sendEther(address sender, address to, uint256 value) public payable {
        vm.startPrank(sender);
        payable(to).transfer(value);
        vm.stopPrank();
    }

    function mintToken(address minter, address erc20, address to, uint256 amount) internal {
        vm.startPrank(minter);
        ERC20Mock(erc20).mint(to, amount);
        vm.stopPrank();
    }

    function registerOperatorWithEigenLayer(address operator) internal {
        vm.startPrank(operator);
        IDelegationManager(el_deployment.delegationManager).registerAsOperator(
            0x0000000000000000000000000000000000000000,
            0,
            "https://raw.githubusercontent.com/tantatnhan/chainbase/refs/heads/main/metadata.json"
        ); 
        vm.stopPrank();
    }

    function depositIntoStrategy(
        address operator,
        address startegy,
        uint256 amount
    ) internal {
        vm.startPrank(operator);
        IERC20 erc20 = IStrategy(startegy).underlyingToken();
        erc20.approve(el_deployment.strategyManager, amount);
        IStrategyManager(el_deployment.strategyManager)
            .depositIntoStrategy(IStrategy(startegy), erc20, amount);
        vm.stopPrank();
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
        vm.serializeAddress(addresses, "pauserRegistry", address(deployment.pauserRegistry));
        vm.serializeAddress(addresses, "strategyToken", address(deployment.strategyToken));
        vm.serializeAddress(addresses, "strategy", address(deployment.strategy));
        vm.serializeAddress(addresses, "L2Coprocessor", address(deployment.L2Coprocessor));
        vm.serializeAddress(addresses, "L2CoprocessorCaller", address(deployment.L2CoprocessorCaller));
        vm.serializeAddress(addresses, "L1Sender", address(deployment.L1Sender));
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