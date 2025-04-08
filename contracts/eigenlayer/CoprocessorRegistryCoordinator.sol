// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/console.sol";

import "@eigenlayer-middleware/SlashingRegistryCoordinator.sol";

error NotOperatorWhitelister();
error OperatorWhitelistAlreadyEnabled();
error OperatorWhitelistAlreadyDisabled();
error InvalidOpeatroAddress();
error OperatorAlreadyInWhitelist();
error OperatorNotInWhitelist();

contract CoprocessorRegistryCoordinator is SlashingRegistryCoordinator {
    event OperatorWhitelistEnabled();
    event OperatorWhitelistDisabled();
    event OperatorAddedToWhitelist(address operator);
    event OperatorRemovedFromWhitelist(address operator);

    bool operatorWhitelistEnabled;
    mapping(address => bool) operatorWhitelist;

    constructor(
        IStakeRegistry _stakeRegistry,
        IBLSApkRegistry _blsApkRegistry,
        IIndexRegistry _indexRegistry,
        ISocketRegistry _socketRegistry,
        IAllocationManager _allocationManager,
        IPauserRegistry _pauserRegistry,
        string memory _version
    )
        SlashingRegistryCoordinator(
            _stakeRegistry,
            _blsApkRegistry,
            _indexRegistry,
            _socketRegistry,
            _allocationManager,
            _pauserRegistry,
            _version
        )
    {
    }

     function initialize(
        address initialOwner,
        address churnApprover,
        address ejector,
        uint256 initialPausedStatus,
        address avs,
        bool _operatorWhitelistEnabled,
        address[] calldata _operatorWhitelist
    ) external initializer {
        // XXX Can not call SlashingRegistryCoordinator.initalize, so call all 
        // necessary methods directly? What about SlashingRegistryCoordinator update?
        __EIP712_init("AVSRegistryCoordinator", "v0.0.1");
        _transferOwnership(initialOwner);
        _setChurnApprover(churnApprover);
        _setPausedStatus(initialPausedStatus);
        _setEjector(ejector);
        SlashingRegistryCoordinator._setAVS(avs);

        operatorWhitelistEnabled = _operatorWhitelistEnabled;
        for (uint256 i; i < _operatorWhitelist.length; ++i) {
            address operator = _operatorWhitelist[i];
            if (operator == address(0)) {
                revert InvalidOpeatroAddress();
            }
            operatorWhitelist[operator] = true;
            emit OperatorAddedToWhitelist(operator);
        }
    }

    function enableOperatorWhitelist() external onlyOwner {
        if (operatorWhitelistEnabled) {
            revert OperatorWhitelistAlreadyEnabled();
        }
        operatorWhitelistEnabled = true;
        emit OperatorWhitelistEnabled();
    }

    function disableOperatorWhitelist() external onlyOwner {
        if (!operatorWhitelistEnabled) {
            revert OperatorWhitelistAlreadyDisabled();
        }
        operatorWhitelistEnabled = false;
        emit OperatorWhitelistDisabled();
    }

    function addOperatorsToWhitelist(address[] calldata operators) external onlyOwner {
        for (uint256 i; i < operators.length; ++i) {
            address operator = operators[i];
            if (operator == address(0)) {
                revert InvalidOpeatroAddress();
            }
            if (operatorWhitelist[operator]) {
                revert OperatorAlreadyInWhitelist();
            }
            operatorWhitelist[operator] = true;
            emit OperatorAddedToWhitelist(operator);
        }
    }

    function removeOperatorsFromWhitelist(address[] calldata operators) external onlyOwner {
        for (uint256 i; i < operators.length; ++i) {
            address operator = operators[i];
            if (!operatorWhitelist[operator]) {
                revert OperatorNotInWhitelist();
            }
            delete operatorWhitelist[operator];
            emit OperatorRemovedFromWhitelist(operator);
        }
    }

    function _beforeRegisterOperator(
        address operator,
        bytes32 operatorId,
        bytes memory quorumNumbers,
        uint192 currentBitmap
    ) internal override {
        if (operatorWhitelistEnabled && !operatorWhitelist[operator]) {
            revert OperatorNotInWhitelist();
        }
    }

    function _beforeDeregisterOperator(
        address operator,
        bytes32 operatorId,
        bytes memory quorumNumbers,
        uint192 currentBitmap
    ) internal override {
        if (operatorWhitelistEnabled && !operatorWhitelist[operator]) {
            revert OperatorNotInWhitelist();
        }
    }
}