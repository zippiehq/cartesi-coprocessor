// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@eigenlayer/contracts/libraries/BytesLib.sol";
import "@eigenlayer-middleware/src/ServiceManagerBase.sol";

import "../src/ICoprocessor.sol";
import "../src/Errors.sol";

contract CoprocessorServiceManager is ServiceManagerBase {
    using BytesLib for bytes;

    event OperatorWhitelistEnabled();
    event OperatorWhitelistDisabled();
    event OperatorAddedToWhitelist(address operator);
    event OperatorRemovedFromWhitelist(address operator);

    ICoprocessor public coprocessor;

    address operatorWhitelister;
    bool operatorWhitelistEnabled;
    mapping(address => bool) operatorWhitelist;

    modifier onlyOperatorWhitelister() {
        if (_msgSender() != operatorWhitelister) {
            revert NotOperatorWhitelister();
        }
        _;
    }

    constructor(
        IAVSDirectory _avsDirectory,
        IRegistryCoordinator _registryCoordinator,
        IStakeRegistry _stakeRegistry
    )
        ServiceManagerBase(
            _avsDirectory,
            _registryCoordinator,
            _stakeRegistry
        )
    {
       _disableInitializers();
    }

    function initialize(
        ICoprocessor _coprocessor,
        bool _operatorWhitelistEnabled,
        address[] calldata _operatorWhitelist
    ) public initializer() {
        coprocessor = _coprocessor;

        operatorWhitelister = _msgSender();
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

    function enableOperatorWhitelist() external onlyOperatorWhitelister {
        if (operatorWhitelistEnabled) {
            revert OperatorWhitelistAlreadyEnabled();
        }
        
        operatorWhitelistEnabled = true;
        
        emit OperatorWhitelistEnabled();
    }

    function disableOperatorWhitelist() external onlyOperatorWhitelister {
        if (!operatorWhitelistEnabled) {
            revert OperatorWhitelistAlreadyDisabled();
        }

        operatorWhitelistEnabled = false;
        
        emit OperatorWhitelistDisabled();
    }

    function addOperatorsToWhitelist(address[] calldata operators) external onlyOperatorWhitelister {
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

    function removeOperatorsFromWhitelist(address[] calldata operators) external onlyOperatorWhitelister {
        for (uint256 i; i < operators.length; ++i) {
            address operator = operators[i];
            if (!operatorWhitelist[operator]) {
                revert OperatorNotInWhitelist();
            }

            delete operatorWhitelist[operator];

            emit OperatorRemovedFromWhitelist(operator);
        }
    }

    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) public override(ServiceManagerBase) onlyRegistryCoordinator {        
        if (operatorWhitelistEnabled && !operatorWhitelist[operator]) {
            revert OperatorNotInWhitelist();
        }
        //  don't check if this operator has registered or not as AVSDirectory has such checking already
        // Stake requirement for quorum is checked in StakeRegistry
        _avsDirectory.registerOperatorToAVS(operator, operatorSignature);
    }
}
