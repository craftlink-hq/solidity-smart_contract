## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
Transactions saved to: /craftlink-general/smart_contract/broadcast/Deploy.s.sol/11155111/run-latest.json

## LATEST DEPLOYMENT

Registry deployed at: 0xdA5D4337364F27f2e5D17895054D63608A6995aC 
https://sepolia.etherscan.io/address/0xdA5D4337364F27f2e5D17895054D63608A6995aC

Token deployed at: 0xeF840E811b86A753291990B2A6DD219e407d231D
https://sepolia.etherscan.io/address/0xeF840E811b86A753291990B2A6DD219e407d231D

PaymentProcessor deployed at: 0x3e4757815c6F1F0c26e11B9DBC6BE2Ad5d100d3D
https://sepolia.etherscan.io/address/0x3e4757815c6F1F0c26e11B9DBC6BE2Ad5d100d3D

GigMarketplace deployed at: 0xD0464CBce1B720BA0cF88A2990d6e5359a266764
https://sepolia.etherscan.io/address/0xD0464CBce1B720BA0cF88A2990d6e5359a266764

ReviewSystem deployed at: 0xd664b18bAA28Cc477aee3213de380D55914524B3
https://sepolia.etherscan.io/address/0xd664b18bAA28Cc477aee3213de380D55914524B3

ChatSystem deployed at: 0x7EE5DC06c7c5078334EC7016ca538d9b986f6E43
https://sepolia.etherscan.io/address/0x7EE5DC06c7c5078334EC7016ca538d9b986f6E43