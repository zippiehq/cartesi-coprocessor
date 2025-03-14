// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {IDelegationManager} from "@eigenlayer/interfaces/IDelegationManager.sol";

import "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";

import "../../src/ERC20Mock.sol";

import "./EigenlayerDeploymentLib.sol";

contract DeployerBase is Script {
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

    function registerOperator(
        EigenlayerDeploymentLib.Deployment memory deployment,
        address operator
    ) internal {
        vm.startPrank(operator);
        IDelegationManager(deployment.delegationManager).registerAsOperator(
            0x0000000000000000000000000000000000000000,
            0,
            "https://raw.githubusercontent.com/tantatnhan/chainbase/refs/heads/main/metadata.json"
        ); 
        vm.stopPrank();
    }

    function advanceChainByNBlocks(uint256 n) public {
        for (uint256 i = 0; i < n; i++) {
            // we transfer eth to ourselves to advance the block
            vm.broadcast(msg.sender);
            payable(msg.sender).transfer(1 wei);
        }
    }

    function convertBoolToString(bool input) public pure returns (string memory) {
        if (input) {
            return "true";
        } else {
            return "false";
        }
    }

    function convertOperatorStatusToString(ISlashingRegistryCoordinator.OperatorStatus operatorStatus)
        public
        pure
        returns (string memory)
    {
        if (operatorStatus == ISlashingRegistryCoordinatorTypes.OperatorStatus.NEVER_REGISTERED) {
            return "NEVER_REGISTERED";
        } else if (operatorStatus == ISlashingRegistryCoordinatorTypes.OperatorStatus.REGISTERED) {
            return "REGISTERED";
        } else if (operatorStatus == ISlashingRegistryCoordinatorTypes.OperatorStatus.DEREGISTERED) {
            return "DEREGISTERED";
        } else {
            return "UNKNOWN";
        }
    }

    // Forge scripts best practice: https://book.getfoundry.sh/tutorials/best-practices#scripts
    function readInput(string memory inputFileName) internal view returns (string memory) {
        string memory inputDir = string.concat(vm.projectRoot(), "/script/input/");
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory file = string.concat(inputFileName, ".json");
        return vm.readFile(string.concat(inputDir, chainDir, file));
    }

    function readOutput(string memory outputFileName) internal view returns (string memory) {
        string memory inputDir = string.concat(vm.projectRoot(), "/script/output/");
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory file = string.concat(outputFileName, ".json");
        return vm.readFile(string.concat(inputDir, chainDir, file));
    }

    function writeOutput(string memory outputJson, string memory outputFileName) internal {
        string memory outputDir = string.concat(vm.projectRoot(), "/script/output/");
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory outputFilePath = string.concat(outputDir, chainDir, outputFileName, ".json");
        vm.writeJson(outputJson, outputFilePath);
    }
}