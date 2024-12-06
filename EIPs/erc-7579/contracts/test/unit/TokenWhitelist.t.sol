// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

import {ExecutionLib, Execution} from "erc7579/lib/ExecutionLib.sol";
import {MODULE_TYPE_HOOK} from "modulekit/external/ERC7579.sol";
import {
    AccountType,
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import {HookMultiPlexer} from "@rhinestone/core-modules/src/HookMultiPlexer/HookMultiPlexer.sol";

import {TokenWhitelist} from "src/TokenWhitelist.sol";
import {ERC20, ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract TokenWhitelistTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    AccountInstance internal instance;
    TokenWhitelist internal tokenWhitelistModule;
    HookMultiPlexer internal hookMultiPlexer;

    ERC20Mock token1;
    address owner1;

    function setUp() public {
        init();

        instance = makeAccountInstance("DEFAULT");
        vm.deal(address(instance.account), 10 ether);

        token1 = new ERC20Mock();

        tokenWhitelistModule = new TokenWhitelist();
        vm.label(address(tokenWhitelistModule), "TokenWhitelist");

        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);
        bytes memory twPluginInstallData = abi.encode(tokens);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(tokenWhitelistModule),
            data: twPluginInstallData
        });

        owner1 = makeAddr("owner1");
    }

    // region - installation

    function test_tokenWhitelistModule_installed() public {
        assertEq(uint8(instance.accountType), uint8(AccountType.DEFAULT));
        assertTrue(instance.isModuleInstalled(MODULE_TYPE_HOOK, address(tokenWhitelistModule)));

        assertTrue(tokenWhitelistModule.isInitialized(instance.account));
        assertTrue(tokenWhitelistModule.isAllowedToken(instance.account, address(token1)));
    }

    function test_tokenWhitelistModule_revertIfSecondInstallation() public {
        TokenWhitelist tokenWhitelistModule2 = new TokenWhitelist();
        vm.label(address(tokenWhitelistModule), "TokenWhitelist2");

        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);
        bytes memory twPluginInstallData = abi.encode(tokens);

        instance.expect4337Revert();
        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(tokenWhitelistModule2),
            data: twPluginInstallData
        });
    }

    // endregion

    // region - transfer tokens

    function test_transfer_success() public {
        token1.mint(instance.account, 100e18);
        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, 1e18));

        instance.exec({target: address(token1), value: 0, callData: transferCall});

        assertEq(token1.balanceOf(owner1), 1e18);
    }

    function test_transfer_revertIfTokenDisallowed() public {
        ERC20Mock token2 = new ERC20Mock();

        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, 1e18));

        instance.expect4337Revert();
        instance.exec({target: address(token2), value: 0, callData: transferCall});
    }

    // endregion

    // region - transfer batch

    function test_transferBatch_success() public {
        uint256 transferAmount = 100e18;
        token1.mint(instance.account, transferAmount);

        bytes memory callToToken1 = abi.encodeCall(ERC20.transfer, (owner1, transferAmount / 2));
        bytes memory callToToken2 = abi.encodeCall(ERC20.approve, (instance.account, transferAmount / 2));
        bytes memory callToToken3 = abi.encodeCall(ERC20.transferFrom, (instance.account, owner1, transferAmount / 2));

        Execution[] memory executions = new Execution[](3);
        executions[0] = Execution(address(token1), 0, callToToken1);
        executions[1] = Execution(address(token1), 0, callToToken2);
        executions[2] = Execution(address(token1), 0, callToToken3);

        UserOpData memory userOpData = instance.getExecOps(executions, address(instance.defaultValidator));

        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        userOpData.entrypoint = instance.aux.entrypoint;
        // send userOp to entrypoint
        userOpData.execUserOps();

        assertEq(token1.balanceOf(owner1), transferAmount);
        assertEq(token1.balanceOf(instance.account), 0);
    }

    function test_transferBatch_revertIfTokenDisallowed() public {
        ERC20Mock token2 = new ERC20Mock();

        bytes memory callToToken1 = abi.encodeCall(ERC20.approve, (owner1, 0));

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution(address(token1), 0, callToToken1);
        executions[0] = Execution(address(token2), 0, callToToken1);

        UserOpData memory userOpData = instance.getExecOps(executions, address(instance.defaultValidator));

        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        userOpData.entrypoint = instance.aux.entrypoint;
        // send userOp to entrypoint
        instance.expect4337Revert();
        userOpData.execUserOps();
    }

    // endregion

    // region - updateTokens

    function test_updateTokens_removeToken() public {
        address[] memory tokensToAdd = new address[](0);
        address[] memory tokensToRemove = new address[](1);
        tokensToRemove[0] = address(token1);

        bytes memory updateData = abi.encodeCall(TokenWhitelist.updateTokens, (tokensToAdd, tokensToRemove));

        instance.exec({target: address(tokenWhitelistModule), value: 0, callData: updateData});

        assertFalse(tokenWhitelistModule.isAllowedToken(instance.account, address(token1)));
    }

    // endregion

    // region - Safe

    function _setUp_safe() private usingAccountEnv(AccountType.SAFE) {
        instance = makeAccountInstance("SAFE");
        vm.deal(address(instance.account), 10 ether);

        assertEq(uint8(instance.accountType), uint8(AccountType.SAFE));

        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);
        bytes memory twPluginInstallData = abi.encode(tokens);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(tokenWhitelistModule),
            data: twPluginInstallData
        });
    }

    function test_safe_tokenWhitelistModule_revertIfSecondInstallation() external {
        _setUp_safe();
        test_tokenWhitelistModule_revertIfSecondInstallation();
    }

    function test_safe_transfer_success() external {
        _setUp_safe();
        test_transfer_success();
    }

    function test_safe_transfer_revertIfTokenDisallowed() external {
        _setUp_safe();
        test_transfer_revertIfTokenDisallowed();
    }

    function test_safe_transferBatch_success() external {
        _setUp_safe();
        test_transferBatch_success();
    }

    function test_safe_transferBatch_revertIfTokenDisallowed() external {
        _setUp_safe();
        test_transferBatch_revertIfTokenDisallowed();
    }

    function test_safe_updateTokens_removeToken() external {
        _setUp_safe();
        test_updateTokens_removeToken();
    }

    // endregion

    // region - Kernel

    function _setUp_kernel() private usingAccountEnv(AccountType.KERNEL) {
        instance = makeAccountInstance("KERNEL");
        vm.deal(address(instance.account), 10 ether);

        assertEq(uint8(instance.accountType), uint8(AccountType.KERNEL));

        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);
        bytes memory twPluginInstallData = abi.encode(tokens);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(tokenWhitelistModule),
            data: twPluginInstallData
        });
    }

    function test_kernel_tokenWhitelistModule_secondInstallation() public {
        _setUp_kernel();

        TokenWhitelist tokenWhitelistModule2 = new TokenWhitelist();
        vm.label(address(tokenWhitelistModule), "TokenWhitelist2");

        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);
        bytes memory twPluginInstallData = abi.encode(tokens);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(tokenWhitelistModule2),
            data: twPluginInstallData
        });
    }

    function test_kernel_twoModules_success() external {
        test_kernel_tokenWhitelistModule_secondInstallation();
        test_transfer_success();
    }

    function test_kernel_transfer_success() external {
        _setUp_kernel();
        test_transfer_success();
    }

    function test_kernel_transfer_revertIfTokenDisallowed() external {
        _setUp_kernel();
        test_transfer_revertIfTokenDisallowed();
    }

    function test_kernel_transferBatch_success() external {
        _setUp_kernel();
        test_transferBatch_success();
    }

    function test_kernel_transferBatch_revertIfTokenDisallowed() external {
        _setUp_kernel();
        test_transferBatch_revertIfTokenDisallowed();
    }

    function test_kernel_updateTokens_removeToken() external {
        _setUp_kernel();
        test_updateTokens_removeToken();
    }

    // endregion

    // region - NEXUS

    function _setUp_nexus() private usingAccountEnv(AccountType.NEXUS) {
        instance = makeAccountInstance("NEXUS");
        vm.deal(address(instance.account), 10 ether);

        assertEq(uint8(instance.accountType), uint8(AccountType.NEXUS));

        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);
        bytes memory twPluginInstallData = abi.encode(tokens);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(tokenWhitelistModule),
            data: twPluginInstallData
        });
    }

    function test_nexus_tokenWhitelistModule_revertIfSecondInstallation() public {
        _setUp_nexus();
        test_tokenWhitelistModule_revertIfSecondInstallation();
    }

    function test_nexus_transfer_success() external {
        _setUp_nexus();
        test_transfer_success();
    }

    function test_nexus_transfer_revertIfTokenDisallowed() external {
        _setUp_nexus();
        test_transfer_revertIfTokenDisallowed();
    }

    function test_nexus_transferBatch_success() external {
        _setUp_nexus();
        test_transferBatch_success();
    }

    function test_nexus_transferBatch_revertIfTokenDisallowed() external {
        _setUp_nexus();
        test_transferBatch_revertIfTokenDisallowed();
    }

    function test_nexus_updateTokens_removeToken() external {
        _setUp_nexus();
        test_updateTokens_removeToken();
    }

    // endregion
}
