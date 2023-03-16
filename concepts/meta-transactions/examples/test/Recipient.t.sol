// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Recipient.sol";

contract RecipientTest is Test {
    Recipient public recipient;

    address trustedForwarder = vm.addr(1);

    function setUp() public {
        recipient = new Recipient(trustedForwarder);
    }
}
