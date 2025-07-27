// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ICraftCoin is IERC20 {
    function approveFor(address owner, address spender, uint256 amount) external;
    function mintFor(address _user) external;
    function burnFor(address _user, uint256 amount) external;
    function nextMintTime(address user) external view returns (uint256);
    function canMint(address user) external view returns (bool);
}
