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

# How to Deploy The Contracts

1. Add you wallet with the `cast` tool.

2. Create an .env file in this structure at the root of the directory and fill it out with the necessary values:

```
SEPOLIA_RPC_URL=
ETH_RPC_URL=
ETHERSCAN_API_KEY=
```

3. Deploy the test token:
(Note that `deployer` is the name of the account you added with the cast tools earlier)
`forge create ./src/BasicToken.sol:BasicToken --account deployer`

4. Deploy the staking contract:
`forge create src/StakingContract.sol:StakingContract --constructor-args  0xDb11a3650F35eF1079AC7F15be6cD1ef88B5Ae3A 1000000000000000000 1711202960 259200 --account deployer`

5. Verify the contract:
`forge verify-contract --chain-id 11155111 --watch  0x936de2d1022Ce478d910363Da3C0E80B7F5552A3 ./src/StakingContract.sol:StakingContract --constructor-args $(cast abi-encode "constructor(token,uint256,uint256,uint256)" 0xDb11a3650F35eF1079AC7F15be6cD1ef88B5Ae3A 1000000000000000000 1711202960 259200)`
