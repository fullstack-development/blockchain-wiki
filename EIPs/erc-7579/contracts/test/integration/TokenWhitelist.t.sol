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
import {
    HookType, SigHookInit, HookMultiPlexer
} from "@rhinestone/core-modules/src/HookMultiPlexer/HookMultiPlexer.sol";
import {MockRegistry} from "@rhinestone/module-bases/src/mocks/MockRegistry.sol";
import {TrustedForwarder} from "@rhinestone/module-bases/src/utils/TrustedForwarder.sol";

import {TokenWhitelist} from "src/TokenWhitelist.sol";
import {ERC20, ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract TokenWhitelistTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    AccountInstance internal instance;
    TokenWhitelist internal tokenWhitelistModule;
    HookMultiPlexer internal hookMultiPlexer;
    MockRegistry internal mockRegistry;

    ERC20Mock token1;
    address owner1;

    function setUp() public {
        init();

        mockRegistry = new MockRegistry();

        instance = makeAccountInstance("DEFAULT");
        vm.deal(address(instance.account), 10 ether);

        hookMultiPlexer = new HookMultiPlexer(mockRegistry);
        vm.label(address(hookMultiPlexer), "HookMultiPlexer");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(hookMultiPlexer),
            data: _getTokenWhitelistInstallData()
        });

        owner1 = makeAddr("owner1");

        token1 = new ERC20Mock();
    }

    // region - installation

    function _getTokenWhitelistInstallData() private returns (bytes memory) {
        tokenWhitelistModule = new TokenWhitelist();
        vm.label(address(tokenWhitelistModule), "TokenWhitelist");

        address[] memory globalHooks = new address[](0);
        address[] memory valueHooks = new address[](0);
        address[] memory delegatecallHooks = new address[](0);
        SigHookInit[] memory sigHooks = new SigHookInit[](0);

        address[] memory _targetSigHooks = new address[](1);
        _targetSigHooks[0] = address(tokenWhitelistModule);

        SigHookInit[] memory targetSigHooks = new SigHookInit[](2);
        targetSigHooks[0] = SigHookInit({sig: ERC20.transfer.selector, subHooks: _targetSigHooks});
        targetSigHooks[1] = SigHookInit({sig: ERC20.approve.selector, subHooks: _targetSigHooks});

        return abi.encode(globalHooks, valueHooks, delegatecallHooks, sigHooks, targetSigHooks);
    }

    function _installTokenWhitelistPlugin() private {
        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);
        bytes memory twPluginInstallData = abi.encode(tokens);

        bytes memory onInstallTokenWhitelist = abi.encodeCall(TokenWhitelist.onInstall, (twPluginInstallData));

        instance.exec({target: address(tokenWhitelistModule), value: 0, callData: onInstallTokenWhitelist});
    }

    function _setTrustedForwarder(address module, address forwarder) private {
        instance.exec({
            target: module,
            value: 0,
            callData: abi.encodeCall(TrustedForwarder.setTrustedForwarder, (forwarder))
        });
    }

    function test_hookMultiPlexerModule_installed() public {
        assertEq(uint8(instance.accountType), uint8(AccountType.DEFAULT));
        assertTrue(instance.isModuleInstalled(MODULE_TYPE_HOOK, address(hookMultiPlexer)));

        assertTrue(hookMultiPlexer.isInitialized(instance.account));

        address[] memory hooks = hookMultiPlexer.getHooks(instance.account);
        assertEq(hooks[0], address(tokenWhitelistModule));
    }

    function test_tokenWhitelistModule_installed() public {
        _installTokenWhitelistPlugin();

        assertTrue(tokenWhitelistModule.isAllowedToken(instance.account, address(token1)));

        _setTrustedForwarder(address(tokenWhitelistModule), address(hookMultiPlexer));

        assertTrue(
            TrustedForwarder(tokenWhitelistModule).isTrustedForwarder(address(hookMultiPlexer), instance.account)
        );
    }

    // endregion

    // region - add hook

    function test_addHookToMultiplexer() public {
        TokenWhitelist tokenWhitelistModule2 = new TokenWhitelist();

        bytes memory addHookDataTransfer = abi.encodeCall(
            HookMultiPlexer.addSigHook, (address(tokenWhitelistModule2), ERC20.transfer.selector, HookType.TARGET_SIG)
        );
        bytes memory addHookDataApprove = abi.encodeCall(
            HookMultiPlexer.addSigHook, (address(tokenWhitelistModule2), ERC20.approve.selector, HookType.TARGET_SIG)
        );

        instance.exec({target: address(hookMultiPlexer), value: 0, callData: addHookDataTransfer});
        instance.exec({target: address(hookMultiPlexer), value: 0, callData: addHookDataApprove});

        address[] memory hooks = hookMultiPlexer.getHooks(instance.account);
        assertEq(hooks[0], address(tokenWhitelistModule2));
        assertEq(hooks[1], address(tokenWhitelistModule));
    }

    // endregion

    // region - transfer

    function test_transferThroughMultiplexer_success() public {
        _installTokenWhitelistPlugin();
        _setTrustedForwarder(address(tokenWhitelistModule), address(hookMultiPlexer));

        token1.mint(instance.account, 100e18);
        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, 1e18));

        instance.exec({target: address(token1), value: 0, callData: transferCall});

        assertEq(token1.balanceOf(owner1), 1e18);
    }

    function test_transferThroughMultiplexer_revertIfTokenDisallowed() public {
        _installTokenWhitelistPlugin();
        _setTrustedForwarder(address(tokenWhitelistModule), address(hookMultiPlexer));

        ERC20Mock token2 = new ERC20Mock();

        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, 1e18));

        instance.expect4337Revert();
        instance.exec({target: address(token2), value: 0, callData: transferCall});
    }

    function test_transferBatchThroughMultiplexer_success() public {
        _installTokenWhitelistPlugin();
        _setTrustedForwarder(address(tokenWhitelistModule), address(hookMultiPlexer));

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

    function test_transferBatchThroughMultiplexer_revertIfTokenDisallowed() public {
        _installTokenWhitelistPlugin();
        _setTrustedForwarder(address(tokenWhitelistModule), address(hookMultiPlexer));

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
}
