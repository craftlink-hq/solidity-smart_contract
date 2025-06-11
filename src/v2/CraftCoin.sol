// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRegistry.sol";

contract CraftCoin is ERC20, ERC20Permit, Ownable {
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

    constructor(address _relayer, address _registry)
        ERC20("CraftCoin", "CFT")
        ERC20Permit("CraftCoin")
        Ownable(msg.sender)
    {
        relayer = _relayer;
        registry = IRegistry(_registry);
    }

    function mint() external {
        require(registry.isArtisan(msg.sender), "Not an artisan");
        require(block.timestamp >= nextMintTime(msg.sender), "Cannot mint yet");

        _mint(msg.sender, TOKENS_PER_MINT);
        lastMint[msg.sender] = block.timestamp;

        emit Minted(msg.sender, TOKENS_PER_MINT);
    }

    function mintFor(address _user) external onlyRelayer {
        require(registry.isArtisan(_user), "Not an artisan");
        require(block.timestamp >= nextMintTime(_user), "Cannot mint yet");

        _mint(_user, TOKENS_PER_MINT);
        lastMint[_user] = block.timestamp;

        emit Minted(_user, TOKENS_PER_MINT);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit Burned(msg.sender, amount);
    }

    function burnFor(address _user, uint256 amount) external {
        // OnlyRelayer was removed to allow users to permit others to burn for him
        _burn(_user, amount);
        emit Burned(_user, amount);
    }

    function nextMintTime(address user) public view returns (uint256) {
        if (lastMint[user] == 0) {
            return 0; // Can mint immediately if never minted before
        }
        return lastMint[user] + MINT_INTERVAL;
    }
}
