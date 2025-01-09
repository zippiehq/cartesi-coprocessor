// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract Mock_L1_Sender {
    IMock_L2Coprocessor public l2Coprocessor;

    constructor(IMock_L2Coprocessor _l2Coprocessor) {
        require(address(_l2Coprocessor) != address(0), "Invalid L2 Coprocessor address");
        l2Coprocessor = _l2Coprocessor;
    }

    function sendMessage(bytes32 respHash, bytes calldata senderData) external payable {
        l2Coprocessor.storeResponseHash(respHash, senderData);
        emit MessageSent(msg.sender, respHash);
    }

    function setL2Coprocessor(IMock_L2Coprocessor _newL2Coprocessor) external {
        require(address(_newL2Coprocessor) != address(0), "Invalid new L2 Coprocessor address");
        l2Coprocessor = _newL2Coprocessor;
        emit L2CoprocessorUpdated(address(_newL2Coprocessor));
    }

    event MessageSent(address indexed sender, bytes32 indexed respHash);
    event L2CoprocessorUpdated(address indexed newL2Coprocessor);
}

interface IMock_L2Coprocessor {
    function storeResponseHash(bytes32 respHash, bytes calldata senderData) external;
}
