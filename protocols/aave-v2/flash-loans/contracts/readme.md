# Aave flashLoan
Simple contract flashLoan for liquidate loan. Loan is created with [AaveLendingAdapter](https://github.com/PavelNaydanov/aave-adapter). AaveLendingAdapter is simple contract for interacting with Aave V2. The code was written in Solidity. Used the Foundry toolchain.

Tests use a fork of the mainnet.

## Get started
1. Install foundry https://book.getfoundry.sh/getting-started/installation
2. Create file ```.env```
3. Complete the file according to ```.env.example```. You need to type MAINNET_RPC_URL

## Commands
1. Если необходимо, то выполнить установку библиотек
> forge install foundry-rs/forge-std --no-commit && forge install OpenZeppelin/openzeppelin-contracts@v4.9.3 --no-commit
2. Run build
> forge build
3. Run tests
> forge test -vvv