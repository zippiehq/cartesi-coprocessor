// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

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

    function coprocessorCallbackOutputsOnly(bytes32 machineHash, bytes32 payloadHash, bytes[] calldata outputs)
        external
        override
    {
        console.log("Callback received in caller");
    }
}
