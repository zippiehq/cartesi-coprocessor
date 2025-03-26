// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "@eigenlayer/interfaces/IAVSRegistrar.sol";
import "@eigenlayer/libraries/BytesLib.sol";

import "@eigenlayer-middleware/ServiceManagerBase.sol";
import "@eigenlayer-middleware/interfaces/IRegistryCoordinator.sol";

import "../src/ICoprocessor.sol";
import "../src/Errors.sol";

// !!!
import "forge-std/Script.sol";

contract CoprocessorServiceManager is ServiceManagerBase, IAVSRegistrar {
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
        IRewardsCoordinator _rewardsCoordinator,
        IPermissionController _permissionController,
        IAllocationManager _allocationManager,
        IStakeRegistry _stakeRegistry,
        ISlashingRegistryCoordinator _registryCoordinator
    )
        ServiceManagerBase(
            _avsDirectory,
            _rewardsCoordinator,
            _registryCoordinator,
            _stakeRegistry,
            _permissionController,
            _allocationManager
        )
    {
       _disableInitializers();
    }

    function initialize(
        ICoprocessor _coprocessor,
        bool _operatorWhitelistEnabled,
        address[] calldata _operatorWhitelist,
	    address initialOwner
    ) public initializer() {
	__ServiceManagerBase_init(initialOwner, initialOwner);
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

    // IAVSRegistrar implementation
    function registerOperator(
        address operator,
        address avs,
        uint32[] calldata operatorSetIds,
        bytes calldata data
    ) external {
        if (operatorWhitelistEnabled && !operatorWhitelist[operator]) {
            revert OperatorNotInWhitelist();
        }
        _registryCoordinator.registerOperator(operator, avs, operatorSetIds, data);
    }

    function deregisterOperator(address operator, address avs, uint32[] calldata operatorSetIds) external {
        if (operatorWhitelistEnabled && !operatorWhitelist[operator]) {
            revert OperatorNotInWhitelist();
        }
        _registryCoordinator.deregisterOperator(operator, avs, operatorSetIds);
    }

    function supportsAVS(
        address avs
    ) external view returns (bool) {
        return _registryCoordinator.supportsAVS(avs);
    }
}
