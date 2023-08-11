// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {Engine} from "../../src/Engine.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract EngineTest is Test {
    DeployDsc deployer;
    StableCoin dsc;
    Engine engine;
    HelperConfig config;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address user = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant AMOUNT_MINT = 100 ether;
    uint256 public constant AMOUNT_BURN = 100 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() public {
        deployer = new DeployDsc();
        (dsc, engine, config) = deployer.run();

        (ethUsdPriceFeed, btcUsdPriceFeed ,weth, ,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(user, STARTING_ERC20_BALANCE);
    }

    // region - Constructor -

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function test_constructor_revertIfTokenLengthNotMatchPriceFeeds() external {
        tokenAddresses.push(weth);

        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(Engine.TokenAddressesAndPriceFeedAddressesShouldBeSameLength.selector);

        new Engine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    // endregion -

    // region - Price tests -

    function test_getUsdValue() external {
        uint256 ethAmount = 15e18;
        // 15e18(amount) * 2000(eth price) = 30000e18
        uint256 expectedUsd = 30_000e18;

        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);

        assertEq(expectedUsd, actualUsd);
    }

    function test_getTokenAmountFromUsd() external {
        uint256 usdAmount = 100 ether;

        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(expectedWeth, actualWeth);
    }

    // endregion

    // region - Mint stable coin -

    function test_mintDsc_revertIfZeroAmount() external {
        vm.expectRevert(Engine.ZeroAmount.selector);

        vm.prank(user);
        engine.mintDsc(0);
    }

    function test_mintDsc() external {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        engine.mintDsc(AMOUNT_MINT);

        vm.stopPrank();

        assertEq(dsc.balanceOf(user), AMOUNT_MINT);
    }

    // endregion

    // region - Burn stable coin -

    function test_burn_revertIfZeroAmount() external {
        vm.expectRevert(Engine.ZeroAmount.selector);

        vm.prank(user);
        engine.burnDsc(0);
    }

    function test_burn() external {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        engine.mintDsc(AMOUNT_MINT);

        dsc.approve(address(engine), AMOUNT_BURN);
        engine.burnDsc(AMOUNT_BURN);

        vm.stopPrank();

        assertEq(dsc.balanceOf(user), AMOUNT_MINT - AMOUNT_BURN);
    }

    // endregion

    // region - Deposit collateral -

    function test_depositCollateral_revertIfCollateralZero() external {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(Engine.ZeroAmount.selector);

        engine.depositCollateral(weth, 0);

        vm.stopPrank();
    }

    function test_depositCollateral_revertWithUnapprovedCollateral() external {
        ERC20Mock unapprovedToken = new ERC20Mock("UNAPPROVED", "Un", user, AMOUNT_COLLATERAL);

        vm.startPrank(user);

        vm.expectRevert(Engine.NotAllowedToken.selector);

        engine.depositCollateral(address(unapprovedToken), AMOUNT_COLLATERAL);

        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        vm.stopPrank();

        _;
    }

    modifier depositedCollateralAndMintDsc() {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_MINT);

        vm.stopPrank();

        _;
    }

    function test_depositCollateralAndGetAccountInfo() external depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(user);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function test_depositCollateralAndMintDsc() external {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_MINT);

        vm.stopPrank();

        assertEq(dsc.balanceOf(user), AMOUNT_MINT);
        assertEq(ERC20Mock(weth).balanceOf(address(engine)), AMOUNT_COLLATERAL);
    }

    // endregion

    // region - Redeem collateral -

    function test_redeemCollateral_revertIfCollateralZero() external depositedCollateral {
        vm.startPrank(user);

        vm.expectRevert(Engine.ZeroAmount.selector);

        engine.redeemCollateral(weth, 0);

        vm.stopPrank();
    }

    function test_redeemCollateral_revertWithUnapprovedCollateral() external depositedCollateral {
        ERC20Mock unapprovedToken = new ERC20Mock("UNAPPROVED", "Un", user, AMOUNT_COLLATERAL);

        vm.startPrank(user);

        vm.expectRevert(Engine.NotAllowedToken.selector);

        engine.redeemCollateral(address(unapprovedToken), AMOUNT_COLLATERAL);

        vm.stopPrank();
    }

    function test_redeemCollateral() external depositedCollateral {
        vm.prank(user);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);

        assertEq(ERC20Mock(weth).balanceOf(user), AMOUNT_COLLATERAL);
    }

    function test_redeemCollateralAndBurnDsc() external depositedCollateralAndMintDsc {
        uint256 startingBalance = dsc.balanceOf(user);

        vm.startPrank(user);

        dsc.approve(address(engine), AMOUNT_BURN);

        engine.redeemCollateralAndBurnDsc(weth, AMOUNT_COLLATERAL, AMOUNT_BURN);

        vm.stopPrank();

        assertEq(ERC20Mock(weth).balanceOf(user), AMOUNT_COLLATERAL);
        assertEq(dsc.balanceOf(user), startingBalance - AMOUNT_BURN);
    }

    // endregion

    // region - Liquidation -

    function test_liquidate_revertIfHealthFactorIsPositive() external {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_MINT);

        vm.stopPrank();

        collateralToCover = 1 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);

        ERC20Mock(weth).approve(address(engine), collateralToCover);
        uint256 debtToCover = 10 ether;

        engine.depositCollateralAndMintDsc(weth, collateralToCover, AMOUNT_MINT);
        dsc.approve(address(engine), debtToCover);

        vm.expectRevert(Engine.HealthFactorIsPositive.selector);

        engine.liquidate(weth, user, debtToCover);

        vm.stopPrank();
    }

    function test_liquidate_revertIfBreaksHealthFactorToLiquidator() external {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_MINT);

        vm.stopPrank();

        collateralToCover = 1 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);

        ERC20Mock(weth).approve(address(engine), collateralToCover);
        uint256 debtToCover = 10 ether;

        engine.depositCollateralAndMintDsc(weth, collateralToCover, AMOUNT_MINT);
        dsc.approve(address(engine), debtToCover);

        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

        vm.expectRevert(abi.encodeWithSelector(Engine.BreaksHealthFactor.selector, 9e16));

        engine.liquidate(weth, user, debtToCover);

        vm.stopPrank();
    }

    function test_liquidate() external {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_MINT);

        vm.stopPrank();

        collateralToCover = 20 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);

        ERC20Mock(weth).approve(address(engine), collateralToCover);
        uint256 debtToCover = 10 ether;

        engine.depositCollateralAndMintDsc(weth, collateralToCover, AMOUNT_MINT);
        dsc.approve(address(engine), debtToCover);

        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

        engine.liquidate(weth, user, debtToCover);

        vm.stopPrank();
    }

    // endregion
}
