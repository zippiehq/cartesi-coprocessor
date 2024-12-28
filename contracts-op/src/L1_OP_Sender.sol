// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@optimism/L1/interfaces/IL1CrossDomainMessenger.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@contracts-initial/ICoprocessorL2Sender.sol";
contract L1_OP_Sender is ICoprocessorL2Sender, Ownable {
    IL1CrossDomainMessenger public crossDomainMessenger;
    address public l2Coprocessor;
    address public l1Coprocessor;
    constructor(address _crossDomainMessenger, address _l2Coprocessor, address _owner) Ownable(_owner) {
        crossDomainMessenger = IL1CrossDomainMessenger(_crossDomainMessenger);
        l2Coprocessor = _l2Coprocessor;
    }
    function setL1Coprocessor(address _l1Coprocessor) external onlyOwner {
        l1Coprocessor = _l1Coprocessor;
    }
    function setL2Coprocessor(address _l2Coprocessor) external onlyOwner {
        l2Coprocessor = _l2Coprocessor;
    }
    function sendMessage(bytes32 respHash, bytes calldata senderData) external payable override {
        require(msg.sender == l1Coprocessor, "Unauthorized caller");
        uint256 rawGasLimit = abi.decode(senderData, (uint256));
        uint32 gasLimit = uint32(rawGasLimit);
        bytes memory message = abi.encodeWithSignature(
            "storeResponseHash(bytes32)",
            respHash
        );
        crossDomainMessenger.sendMessage(l2Coprocessor, message, gasLimit);
    }
}