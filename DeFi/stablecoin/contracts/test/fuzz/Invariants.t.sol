// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {Engine} from "../../src/Engine.sol";
import {Handler} from "./Handler.t.sol";

/**
 * Инварианты:
 * 1. TotalSupply стейблкоина должен быть меньше collateral
 * 2. Getter function никогда не должны revert
 */
contract Invariants is StdInvariant, Test {
    DeployDsc deployer;
    StableCoin dsc;
    Engine engine;
    HelperConfig config;
    Handler handler;

    address weth;
    address wbtc;

    function setUp() external {
        deployer = new DeployDsc();
        (dsc, engine, config) = deployer.run();

        (, ,weth, wbtc ,) = config.activeNetworkConfig();

        handler = new Handler(engine, dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() external view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);

        console.log("wethValue", wethValue);
        console.log("wbtcValue", wbtcValue);
        console.log("totalSupply", totalSupply);
        console.log("Times mint called: ", handler.timesMintIsCalled());

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersShouldNotRevert() public view {
        engine.LIQUIDATION_BONUS();
        engine.PRECISION();
    }
}