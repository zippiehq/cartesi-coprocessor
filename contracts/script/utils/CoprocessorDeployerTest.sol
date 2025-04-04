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
import {OperatorStateRetriever} from "@eigenlayer-middleware/OperatorStateRetriever.sol";

import {CoprocessorDeployerBase} from "./CoprocessorDeployerBase.sol";

import {ERC20Mock} from "../../src/ERC20Mock.sol";

interface IWETH {
    function deposit() external payable;
    function balanceOf(address src) external view returns (uint256);
}

contract CoprocessorDeployerTest is CoprocessorDeployerBase {
    // uses script ---private-key
    function sendEther(address to, uint256 value) public payable {
        vm.startBroadcast();
        payable(to).transfer(value);
        vm.stopBroadcast();
    }

    // uses script --private-key
    function mintToken(address erc20, address to, uint256 amount) internal {
        vm.startBroadcast();
        ERC20Mock(erc20).mint(to, amount);
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
