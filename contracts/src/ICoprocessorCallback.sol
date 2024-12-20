// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

    struct Response {
        address ruleSet;
        bytes32 machineHash;
        bytes32 payloadHash;
        bytes32 outputMerkle;
    }

interface ICoprocessorCallback {
    function coprocessorCallbackOutputsOnly(bytes32 machineHash, bytes32 payloadHash, bytes[] calldata outputs)
    external;
}