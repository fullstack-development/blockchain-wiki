// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {Engine} from "../../src/Engine.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    Engine engine;
    StableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;
    MockV3Aggregator public ethUsdPriceFeed;

    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;

    constructor(Engine _engine, StableCoin _dsc) {
        engine = _engine;
        dsc = _dsc;

        address [] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(engine.getCollateralTokenPriceFeed(address(weth)));
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }

        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(sender);
        int256 maxDscMinted = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if (maxDscMinted < 0) {
            return;
        }

        amount = bound(amount, 0, uint256(maxDscMinted));
        if (amount == 0) {
            return;
        }

        vm.startPrank(sender);

        engine.mintDsc(amount);

        vm.stopPrank();

        timesMintIsCalled++;
    }

    function depositCollateral(uint256 collateralSeed, uint256 collateralAmount) public {
        ERC20Mock collateralToken = _getCollateralFromSeed(collateralSeed);

        collateralAmount = bound(collateralAmount, 1, type(uint96).max);

        vm.startPrank(msg.sender);

        collateralToken.mint(msg.sender, collateralAmount);
        collateralToken.approve(address(engine), collateralAmount);

        engine.depositCollateral(address(collateralToken), collateralAmount);
        vm.stopPrank();

        usersWithCollateralDeposited.push(msg.sender);
    }

    // TODO: не заработало
    // function redeemCollateral(uint256 collateralSeed, uint256 collateralAmount) public {
    //     ERC20Mock collateralToken = _getCollateralFromSeed(collateralSeed);
    //     uint256 maxCollateralToRedeem = engine.getCollateralBalanceOfUser(msg.sender, address(collateralToken));

    //     collateralAmount = bound(collateralAmount, 0, maxCollateralToRedeem);
    //     if (collateralAmount == 0) {
    //         return;
    //     }

    //     engine.redeemCollateral(address(collateralToken), collateralAmount);
    // }

    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }

        return wbtc;
    }
}