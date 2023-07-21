// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {SigUtils} from "./utils/SigUtils.sol";

import {NativeMetaTransaction} from "../src/NativeMetaTransaction.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NativeMetaTransactionTest is Test {
    NativeMetaTransaction public token;
    SigUtils public sigUtils;

    uint256 userPrivateKey = 100;
    address user;

    function setUp() public {
        token = new NativeMetaTransaction();
        sigUtils = new SigUtils(token.DOMAIN_SEPARATOR());

        user = vm.addr(userPrivateKey);

        token.mint(user, 100e18);
    }

    function test_metaTransfer() external {
        address relayer = vm.addr(1);
        address recipient = vm.addr(2);
        uint256 initialBalance = token.balanceOf(user);
        uint256 transferAmount = 10e18;

        bytes memory functionSignature = abi.encodeWithSignature(
            "transfer(address,uint256)",
            recipient,
            transferAmount
        );

        SigUtils.MetaTransaction memory _tx =
            SigUtils.MetaTransaction({
                nonce: token.getNonce(user),
                signer: user,
                functionSignature: functionSignature
        });

        bytes32 digest = sigUtils.getTypedDataHash(token.META_TRANSACTION_TYPEHASH(), _tx);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        vm.prank(relayer);
        token.executeMetaTransaction(user, functionSignature, v, r, s);

        assertEq(token.balanceOf(recipient), transferAmount);
        assertEq(token.balanceOf(user), initialBalance - transferAmount);
    }
}
