// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ICoprocessorL2Sender.sol";
import "./Coprocessor.sol";

contract CoprocessorToL2 is Coprocessor {

    constructor(IRegistryCoordinator _registryCoordinator)
    Coprocessor(_registryCoordinator) {}

    function solverCallbackNoOutputs(
        Response calldata resp,
        bytes calldata quorumNumbers,
        uint32 quorumThresholdPercentage,
        uint8 thresholdDenominator,
        uint32 blockNumber,
        NonSignerStakesAndSignature memory nonSignerStakesAndSignature,
        ICoprocessorL2Sender l2Sender,
        bytes calldata senderData
    ) external payable {
        check(resp, quorumNumbers, quorumThresholdPercentage, thresholdDenominator, blockNumber, nonSignerStakesAndSignature);
        bytes memory encodedResp = abi.encode(resp);
        bytes32 respHash = keccak256(encodedResp);
        l2Sender.sendMessage{value: msg.value}(respHash, senderData);
    }
}