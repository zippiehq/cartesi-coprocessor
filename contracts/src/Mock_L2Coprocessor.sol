// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {console} from "forge-std/console.sol";

import "./ICoprocessorCallback.sol";
import {LibMerkle32} from "./LibMerkle32.sol";

contract Mock_L2Coprocessor {
    using LibMerkle32 for bytes32[];

    address public l1Coordinator;
    address public l1Sender;

    mapping(bytes32 => bool) public responses;

    event TaskIssued(bytes32 machineHash, bytes input, address callback);
    event TaskCompleted(bytes32 responseHash);

    constructor(address _l1Sender) {
        l1Sender = _l1Sender;
    }

    function issueTask(bytes32 machineHash, bytes calldata input, address callback) public {
        emit TaskIssued(machineHash, input, callback);
    }

    function storeResponseHash(bytes32 responseHash, bytes calldata senderData) external {
        require(msg.sender == l1Sender, "Unauthorized caller");
        require(!responses[responseHash], "Response already whitelisted");
        responses[responseHash] = true;
        emit TaskCompleted(responseHash);
    }

    function setL1Sender(address _newL1Sender) external {
        require(msg.sender == l1Sender || l1Sender == address(0), "Unauthorized caller");
        require(_newL1Sender != address(0), "Cannot set l1Sender to zero address");
        l1Sender = _newL1Sender;
    }

    function callbackWithOutputs(Response calldata resp, bytes[] calldata outputs, address callbackAddress) public {
        console.log("1");
        bytes32 respHash = keccak256(abi.encode(resp));
        console.log("2");
        require(responses[respHash], "R");

        console.log("3");

        bytes32[] memory outputsHashes = new bytes32[](outputs.length);
        for (uint256 i = 0; i < outputs.length; i++) {
            outputsHashes[i] = keccak256(outputs[i]);
        }
        require(resp.outputMerkle == LibMerkle32.merkleRoot(outputsHashes, 63), "M");
        console.log("4");

        ICoprocessorCallback(callbackAddress).coprocessorCallbackOutputsOnly(
            resp.machineHash, resp.payloadHash, outputs
        );
        console.log("5");
    }
}
