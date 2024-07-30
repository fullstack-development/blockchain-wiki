# Instructions for executing scripts

The project is written using the [Foundry framework](https://github.com/gakonst/foundry).

## Requirements

Please install the following:

-   [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
    -   You'll know you've done it right if you can run `git --version`
-   [Foundry / Foundryup](https://github.com/gakonst/foundry)
    -   This will install `forge`, `cast`, `anvil` and `chisel`
    -   You can test you've installed them right by running `forge --version` and get an output like: `forge 0.2.0 (f016135 2022-07-04T00:15:02.930499Z)`
    -   To get the latest of each, just run `foundryup`

## Install libraries

```shell
$ forge install foundry-rs/forge-std --no-commit \
&& forge install aragon/osx@v1.3.0 --no-commit \
&& forge install OpenZeppelin/openzeppelin-contracts@v4.8.1 --no-commit \
&& forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v4.8.1 --no-commit \
&& forge install ensdomains/ens-contracts@v0.0.19 --no-commit 
```

## Build

```shell
$ forge build --via-ir
```

## Running scripts

### Create DAO

```shell
$ forge script script/CreateDao.s.sol --rpc-url sepolia -vvvv --broadcast
```

### Install WETHPlugin

```shell
$ forge script script/InstallWethPlugin.s.sol --rpc-url sepolia --via-ir -vvvv --broadcast
```

### Deposit to WETH

```shell
$ forge script script/DepositToWeth.s.sol --rpc-url sepolia -vvvv --broadcast
```

## Documentation

https://book.getfoundry.sh/
