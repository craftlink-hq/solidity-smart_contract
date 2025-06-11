// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IToken is IERC20 {
    function claim() external;
    function claimFor(address _user) external;
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function decimals() external pure returns (uint8);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
}
