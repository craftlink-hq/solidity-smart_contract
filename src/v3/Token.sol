// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    address public immutable relayer;
    string _name = "USD Tethers";
    string _symbol = "USDT";
    uint8 _decimals = 6;

    uint256 public constant CLAIM_AMOUNT = 1000 * 10 ** 6;
    mapping(address => bool) public hasClaimed;

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Caller is not the relayer");
        _;
    }

    constructor(address _relayer) ERC20(_name, _symbol) Ownable(msg.sender) {
        relayer = _relayer;
        // _mint(msg.sender, initialSupply * 10**18);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function approveFor(address owner, address spender, uint256 amount) external onlyRelayer {
        _approve(owner, spender, amount);
    }

    function claimFor(address _user) external onlyRelayer {
        require(!hasClaimed[_user], "Already claimed");

        hasClaimed[_user] = true;
        _mint(_user, CLAIM_AMOUNT);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
