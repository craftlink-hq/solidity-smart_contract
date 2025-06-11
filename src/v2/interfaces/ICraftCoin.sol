// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICraftCoin is IERC20 {
    function mint() external;
    function mintFor(address _user) external;
    function burn(uint256 amount) external;
    function burnFor(address _user, uint256 amount) external;
    function nextMintTime(address user) external view returns (uint256);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
}
