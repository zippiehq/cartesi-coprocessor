// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

struct Response {
    uint16 finish_reason;
    address ruleSet;
    bytes32 machineHash;
    bytes32 payloadHash;
    bytes32 outputMerkle;
}

interface ICoprocessorCallbackCompat {
    function coprocessorCallbackOutputsOnly(bytes32 machineHash, bytes32 payloadHash, bytes[] calldata outputs)
        external;
    function coprocessorCallbackV2(uint16 reason, bytes32 machineHash, bytes32 payloadHash, bytes[] calldata outputs)
        external;
    function coprocessorCallbackV2SupportsReason(uint16 reason) external returns (bool);
}

interface ICoprocessorCallback {
    function coprocessorCallbackV2(uint16 reason, bytes32 machineHash, bytes32 payloadHash, bytes[] calldata outputs)
        external;
    function coprocessorCallbackV2SupportsReason(uint16 reason) external returns (bool);
}
