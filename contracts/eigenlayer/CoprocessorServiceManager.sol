// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "@eigenlayer/libraries/BytesLib.sol";

import "@eigenlayer-middleware/ServiceManagerBase.sol";
import "@eigenlayer-middleware/interfaces/IRegistryCoordinator.sol";

import "../src/ICoprocessor.sol";
import "../src/Errors.sol";

contract CoprocessorServiceManager is ServiceManagerBase {
    using BytesLib for bytes;

    ICoprocessor public coprocessor;

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
	    address initialOwner
    ) public initializer() {
	    __ServiceManagerBase_init(initialOwner, initialOwner);
        coprocessor = _coprocessor;
    }
}
