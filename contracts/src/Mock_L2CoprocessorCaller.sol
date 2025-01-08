// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {console} from "forge-std/console.sol";
import "./Mock_L2Coprocessor.sol";
import "./ICoprocessorCallback.sol";

contract MockL2CoprocessorCaller is ICoprocessorCallback {
    address public coprocessor;

    constructor(address _coprocessor) {
        coprocessor = _coprocessor;
    }

    function callIssueTask(bytes32 machineHash, bytes calldata input) external {
        Mock_L2Coprocessor(coprocessor).issueTask(machineHash, input, address(this));
    }

    function callStoreResponseHash(bytes32 responseHash, bytes calldata senderData) external {
        Mock_L2Coprocessor(coprocessor).storeResponseHash(responseHash, senderData);
    }

    function callSetL1Sender(address newSender) external {
        Mock_L2Coprocessor(coprocessor).setL1Sender(newSender);
    }

    function callCallbackWithOutputs(
        Response calldata resp,
        bytes[] calldata outputs
    ) external {
        Mock_L2Coprocessor(coprocessor).callbackWithOutputs(resp, outputs, address(this));
    }

    function coprocessorCallbackOutputsOnly(
        bytes32 machineHash,
        bytes32 payloadHash,
        bytes[] calldata outputs
    ) external override {
        console.log("Callback received in caller");
    }
}
