// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

import {StableCoin} from "../src/StableCoin.sol";
import {Engine} from "../src/Engine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDsc is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (StableCoin, Engine, HelperConfig) {
        HelperConfig config = new HelperConfig();

        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address weth,
            address wbtc,
            uint256 deployerKey
        ) = config.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);

        StableCoin dsc = new StableCoin();
        Engine engine = new Engine(tokenAddresses, priceFeedAddresses, address(dsc));

        dsc.transferOwnership(address(engine));

        vm.stopBroadcast();

        return (dsc, engine, config);
    }
}
