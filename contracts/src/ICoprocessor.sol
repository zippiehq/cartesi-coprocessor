pragma solidity 0.8.12;

interface ICoprocessor {
    function issueTask(bytes32 machineHash, bytes calldata input, address callbackAddress) external;
}
