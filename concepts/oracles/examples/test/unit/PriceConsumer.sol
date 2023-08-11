// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "../../src/PriceConsumer.sol";

contract PriceConsumerTest is Test {
    /**
    * Network: Sepolia
    * Aggregator: ETH/USD
    */
    address constant CHAINLINK_AGGREGATOR_ADDRESS = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    PriceConsumer public priceConsumer;

    string SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
    uint256 sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);

    function setUp() public {
        vm.selectFork(sepoliaFork);
        assertEq(vm.activeFork(), sepoliaFork);

        priceConsumer = new PriceConsumer(CHAINLINK_AGGREGATOR_ADDRESS);
    }

    function test_getLatestPrice() external {
        uint256 price = priceConsumer.getLatestPrice();
        assertGt(price, 0);
    }
}
