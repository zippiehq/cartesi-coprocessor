// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {ERC20Mock} from "../../src/ERC20Mock.sol";

library FundOperatorLib {
    function fund_operator(address erc20, address operator, uint256 amount) internal {
        ERC20Mock erc20_contract = ERC20Mock(erc20);

        erc20_contract.mint(operator, amount);
    }
}
