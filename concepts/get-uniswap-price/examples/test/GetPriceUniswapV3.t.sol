// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/GetPriceUniswapV3.sol";

contract GetPriceUniswapV3Test is Test {
    address constant FACTORY_ADDRESS = 0x1F98431c8aD98523631AE4a59f267346ea31F984;


    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint24 constant FEE = 3000;

    string mainnetRpcUrl = vm.envString("MAINNET_RPC_URL");
    uint256 mainnetFork;

    GetPriceUniswapV3 priceFeed;

    function setUp() public {
        mainnetFork = vm.createFork(mainnetRpcUrl);
        vm.selectFork(mainnetFork);

        priceFeed = new GetPriceUniswapV3(FACTORY_ADDRESS);
    }

    function test_forkSelected() public {
        assertEq(vm.activeFork(), mainnetFork);
    }

    function test_calculatePriceFromLiquidity() external {
        uint256 price = priceFeed.calculatePriceFromLiquidity(WETH, USDT, FEE); // TODO: Не работает если наоборот
        console.log("Price", price);
        console.log("-------------------------------------------------------");

        uint256 price1 = priceFeed.calculatePriceFromLiquidity(USDT, WETH, FEE); // TODO: Не работает если наоборот
        console.log("Price", price1);
    }

    function test_getPrice() external {
        uint256 price = priceFeed.getPrice(WETH, USDT, FEE); // TODO: от перемены токенов местами ничего не меняется, прайс выдается один и тотже

        console.log("Price", price);

        assertGt(price, 0);
    }
}
