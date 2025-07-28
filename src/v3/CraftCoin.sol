// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRegistry.sol";

contract CraftCoin is ERC20, Ownable {
    IRegistry public immutable registry;
    uint256 public constant MINT_INTERVAL = 30 days;
    uint256 public constant TOKENS_PER_MINT = 50 * 10 ** 18;
    mapping(address => uint256) public lastMint;
    address public immutable relayer;

    event Minted(address indexed user, uint256 amount);
    event Burned(address indexed user, uint256 amount);

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Caller is not the relayer");
        _;
    }

    constructor(address _relayer, address _registry) ERC20("CraftCoin", "CFT") Ownable(msg.sender) {
        relayer = _relayer;
        registry = IRegistry(_registry);
    }

    function approveFor(address owner, address spender, uint256 amount) external onlyRelayer {
        _approve(owner, spender, amount);
    }

    function mintFor(address _user) external onlyRelayer {
        require(registry.isArtisan(_user), "Not an artisan");
        require(block.timestamp >= nextMintTime(_user), "Cannot mint yet");

        _mint(_user, TOKENS_PER_MINT);
        lastMint[_user] = block.timestamp;

        emit Minted(_user, TOKENS_PER_MINT);
    }

    function burnFor(address _user, uint256 amount) external {
        _burn(_user, amount);
        emit Burned(_user, amount);
    }

    function canMint(address user) public view returns (bool) {
        return block.timestamp >= nextMintTime(user);
    }

    function nextMintTime(address user) public view returns (uint256) {
        if (lastMint[user] == 0) {
            return 0; // Can mint immediately if never minted before
        }
        return lastMint[user] + MINT_INTERVAL;
    }
}
