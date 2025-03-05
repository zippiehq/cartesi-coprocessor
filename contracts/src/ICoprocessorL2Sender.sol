// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

interface ICoprocessorL2Sender {
    function sendMessage(bytes32 respHash, bytes calldata senderData) external payable;
}
