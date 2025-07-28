// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IToken is IERC20 {
    function approveFor(address owner, address spender, uint256 amount) external;
    function claimFor(address _user) external;
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function decimals() external pure returns (uint8);
}
