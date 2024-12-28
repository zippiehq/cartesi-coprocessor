// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@contracts-initial/ICoprocessorCallback.sol";
import "@openzeppelin-ownable/contracts/access/Ownable.sol";
import "@optimism/L2/interfaces/IL2CrossDomainMessenger.sol";
import {LibMerkle32} from "@contracts-initial/LibMerkle32.sol";

contract L2Coprocessor is Ownable {
    using LibMerkle32 for bytes32[];
    //instance of the optimism cross domain messagnger
    IL2CrossDomainMessenger public crossDomainMessenger;
    address public l1Coordinator; // address only authorized to call storeResponseHash

    // keep track of the responses
    mapping(bytes32 => bool) public responses;

    // new task issued
    event TaskIssued(bytes32 machineHash, bytes input, address callback);
    event TaskCompleted(bytes32 responseHash); // task completed

    // initialize l2 contract
    constructor(address _crossDomainMessenger, address _owner) Ownable(_owner)
    {
        crossDomainMessenger = IL2CrossDomainMessenger(_crossDomainMessenger);
    }

    // only authorised from l1
    modifier onlyL1Coordinator() {
        require(
            msg.sender == address(crossDomainMessenger) &&
            crossDomainMessenger.xDomainMessageSender() == l1Coordinator,
            "Not authorized"
        );
        _;
    }

    // set contract owner to set L1Coordinator address
    function setL1Coordinator(address _l1Coordinator) external onlyOwner {
        l1Coordinator = _l1Coordinator;
    }

    // issue new task
    function issueTask(bytes32 machineHash, bytes calldata input, address callback) public {
        emit TaskIssued(machineHash, input, callback);
    }

    // store response hash and this can only be called by the L1Coordinator
    function storeResponseHash(bytes32 responseHash) external onlyL1Coordinator {
        require(!responses[responseHash], "Response already whitelisted");
        responses[responseHash] = true;
        emit TaskCompleted(responseHash);
    }

    // can call callback with the provided outputs after the task is completed
    function callbackWithOutputs(
        Response calldata resp,
        bytes[] calldata outputs,
        address callbackAddress
    ) public {
        bytes32 respHash = keccak256(abi.encode(resp));
        require(responses[respHash]);

        bytes32[] memory outputsHashes = new bytes32[](outputs.length);
        for (uint256 i = 0; i < outputs.length; i++) {
            outputsHashes[i] = keccak256(outputs[i]);
        }
        require(resp.outputMerkle == LibMerkle32.merkleRoot(outputsHashes, 63), "M");

        ICoprocessorCallback(callbackAddress).coprocessorCallbackOutputsOnly(resp.machineHash, resp.payloadHash, outputs);
    }
}
