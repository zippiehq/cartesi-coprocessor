// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "@eigenlayer/permissions/Pausable.sol";
import "@eigenlayer-middleware/interfaces/IServiceManager.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/BLSApkRegistry.sol";
import {RegistryCoordinator} from "@eigenlayer-middleware/RegistryCoordinator.sol";
import {BLSSignatureChecker} from "@eigenlayer-middleware/BLSSignatureChecker.sol";
import {IRegistryCoordinator} from "@eigenlayer-middleware/interfaces/IRegistryCoordinator.sol";
import {OperatorStateRetriever} from "@eigenlayer-middleware/OperatorStateRetriever.sol";
import "@eigenlayer-middleware/libraries/BN254.sol";

import {LibMerkle32} from "./LibMerkle32.sol";
import "./ICoprocessorCallback.sol";


contract Coprocessor is BLSSignatureChecker, OperatorStateRetriever, Initializable, OwnableUpgradeable {
    using BN254 for BN254.G1Point;
    using LibMerkle32 for bytes32[];

    constructor(IRegistryCoordinator _registryCoordinator) BLSSignatureChecker(_registryCoordinator) {
	staleStakesForbidden = false;
    }

    function initialize(address initialOwner) public initializer {
        _transferOwnership(initialOwner);
    }

    event TaskIssued(bytes32 machineHash, bytes input, address callback);

    function issueTask(bytes32 machineHash, bytes calldata input, address callback) public {
        emit TaskIssued(machineHash, input, callback);
    }

    function check(
        Response calldata resp,
        bytes calldata quorumNumbers,
        uint32 quorumThresholdPercentage,
        uint8 thresholdDenominator,
        uint32 blockNumber,
        NonSignerStakesAndSignature memory nonSignerStakesAndSignature
    ) internal view {
        require(resp.ruleSet == address(this));
        bytes32 responseHash = keccak256(abi.encode(resp));
        // Check the BLS signature.
        (QuorumStakeTotals memory quorumStakeTotals, bytes32 hashOfNonSigners) =
            checkSignatures(responseHash, quorumNumbers, blockNumber, nonSignerStakesAndSignature);

        // Check that signatories own at least a threshold percentage of each quourm.
        for (uint256 i = 0; i < quorumNumbers.length; i++) {
            // we don't check that the quorumThresholdPercentages are not >100 because a greater value would trivially fail the check, implying
            // signed stake > total stake
            require(
                quorumStakeTotals.signedStakeForQuorum[i] * thresholdDenominator
                    >= quorumStakeTotals.totalStakeForQuorum[i] * uint8(quorumThresholdPercentage),
                "Signatories do not own at least threshold percentage of a quorum"
            );
        }
    }

    function solverCallbackOutputsOnly(
        Response calldata resp,
        bytes calldata quorumNumbers,
        uint32 quorumThresholdPercentage,
        uint8 thresholdDenominator,
        uint32 blockNumber,
        NonSignerStakesAndSignature memory nonSignerStakesAndSignature,
        address callback_address,
        bytes[] calldata outputs
    ) public {
        bytes32[] memory outputsHashes = new bytes32[](outputs.length);
        for (uint256 i = 0; i < outputs.length; i++) {
            outputsHashes[i] = keccak256(outputs[i]);
        }
        require(resp.outputMerkle == LibMerkle32.merkleRoot(outputsHashes, 63), "M");

        check(
            resp,
            quorumNumbers,
            quorumThresholdPercentage,
            thresholdDenominator,
            blockNumber,
            nonSignerStakesAndSignature
        );

        ICoprocessorCallback callbackContract = ICoprocessorCallback(callback_address);
        callbackContract.coprocessorCallbackOutputsOnly(resp.machineHash, resp.payloadHash, outputs);
    }
}
