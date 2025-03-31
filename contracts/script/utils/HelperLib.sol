// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import "@eigenlayer-middleware/interfaces/ISlashingRegistryCoordinator.sol";
import "@eigenlayer/strategies/StrategyBase.sol";

library HelperLib {
    function convertBoolToString(bool input) public pure returns (string memory) {
        if (input) {
            return "true";
        } else {
            return "false";
        }
    }

    function convertOperatorStatusToString(ISlashingRegistryCoordinator.OperatorStatus operatorStatus)
        public
        pure
        returns (string memory)
    {
        if (operatorStatus == ISlashingRegistryCoordinatorTypes.OperatorStatus.NEVER_REGISTERED) {
            return "NEVER_REGISTERED";
        } else if (operatorStatus == ISlashingRegistryCoordinatorTypes.OperatorStatus.REGISTERED) {
            return "REGISTERED";
        } else if (operatorStatus == ISlashingRegistryCoordinatorTypes.OperatorStatus.DEREGISTERED) {
            return "DEREGISTERED";
        } else {
            return "UNKNOWN";
        }
    }
}