pragma solidity ^0.8.9;

interface ICoprocessor {
    function issueTask(bytes32 machineHash, bytes calldata input, address callbackAddress) external;
}
