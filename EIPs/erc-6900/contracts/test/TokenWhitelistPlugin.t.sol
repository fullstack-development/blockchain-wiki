// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC20Mock, ERC20} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {EntryPoint} from "@eth-infinitism/account-abstraction/core/EntryPoint.sol";

import {IMultiOwnerPlugin} from "modular-account/plugins/owner/IMultiOwnerPlugin.sol";
import {MultiOwnerPlugin} from "modular-account/plugins/owner/MultiOwnerPlugin.sol";
import {UserOperation} from "modular-account/interfaces/erc4337/UserOperation.sol";
import {Call} from "modular-account/interfaces/IStandardExecutor.sol";
import {FunctionReference} from "modular-account/interfaces/IPluginManager.sol";
import {FunctionReferenceLib} from "modular-account/helpers/FunctionReferenceLib.sol";
import {IEntryPoint} from "modular-account/interfaces/erc4337/IEntryPoint.sol";
import {MultiOwnerModularAccountFactory} from "modular-account/factory/MultiOwnerModularAccountFactory.sol";
import {PluginMetadata} from "modular-account-libs/interfaces/IPlugin.sol";
import {UpgradeableModularAccount} from "modular-account/account/UpgradeableModularAccount.sol";

import {TokenWhitelistPlugin} from "../src/TokenWhitelistPlugin.sol";

contract TokenWhitelistPluginTest is Test {
    using ECDSA for bytes32;

    IEntryPoint entryPoint;
    UpgradeableModularAccount account1;
    TokenWhitelistPlugin tokenWhitelistPlugin;
    MultiOwnerPlugin multiOwnerPlugin;
    MultiOwnerModularAccountFactory factory;
    ERC20Mock token1;

    address owner1;
    uint256 owner1Key;
    address payable beneficiary;

    uint256 constant CALL_GAS_LIMIT = 1000000;
    uint256 constant VERIFICATION_GAS_LIMIT = 1000000;

    function setUp() public {
        // Create EntryPoint
        entryPoint = IEntryPoint(address(new EntryPoint()));

        // Deploy MultiOwnerPlugin
        multiOwnerPlugin = new MultiOwnerPlugin();
        bytes32 multiOwnerPluginManifestHash = keccak256(abi.encode(multiOwnerPlugin.pluginManifest()));

        address implementation = address(new UpgradeableModularAccount(entryPoint));

        // Deploy AccountFactory
        factory = new MultiOwnerModularAccountFactory(
            owner1, address(multiOwnerPlugin), implementation, multiOwnerPluginManifestHash, entryPoint
        );

        // Create beneficiary
        beneficiary = payable(makeAddr("beneficiary"));

        // Create owner of account
        (owner1, owner1Key) = makeAddrAndKey("owner1");
        address[] memory owners = new address[](1);
        owners[0] = owner1;

        // Create account
        account1 = UpgradeableModularAccount(payable(factory.createAccount(1, owners)));
        vm.deal(address(account1), 100 ether);

        // Create TokenWhitelistPlugin
        tokenWhitelistPlugin = new TokenWhitelistPlugin();
        bytes32 manifestHash = keccak256(abi.encode(tokenWhitelistPlugin.pluginManifest()));

        // Add dependency plugin to TokenWhitelistPlugin
        FunctionReference[] memory dependencies = new FunctionReference[](1);
        dependencies[0] = FunctionReferenceLib.pack(
            address(multiOwnerPlugin), uint8(IMultiOwnerPlugin.FunctionId.RUNTIME_VALIDATION_OWNER_OR_SELF)
        );

        address[] memory tokens = new address[](1);
        token1 = new ERC20Mock();
        tokens[0] = address(token1);
        bytes memory twPluginInstallData = abi.encode(tokens);

        // Install this plugin on the account as the owner
        vm.prank(owner1);
        account1.installPlugin({
            plugin: address(tokenWhitelistPlugin),
            manifestHash: manifestHash,
            pluginInstallData: twPluginInstallData,
            dependencies: dependencies
        });
    }

    // region - Plugin installation

    function test_plugins_successInstalled() external {
        assertTrue(tokenWhitelistPlugin.isAllowedToken(address(account1), address(token1)));
        address[] memory pluginAddresses = account1.getInstalledPlugins();

        assertEq(pluginAddresses[0], address(tokenWhitelistPlugin));
        assertEq(pluginAddresses[1], address(multiOwnerPlugin));
    }

    function testFail_pluginInstall_revertIfEmptyTokens() external {
        address[] memory owners = new address[](1);
        owners[0] = owner1;
        UpgradeableModularAccount account2 = UpgradeableModularAccount(payable(factory.createAccount(2, owners)));

        bytes32 manifestHash = keccak256(abi.encode(tokenWhitelistPlugin.pluginManifest()));

        FunctionReference[] memory dependencies = new FunctionReference[](1);
        dependencies[0] = FunctionReferenceLib.pack(
            address(multiOwnerPlugin), uint8(IMultiOwnerPlugin.FunctionId.RUNTIME_VALIDATION_OWNER_OR_SELF)
        );

        address[] memory tokens = new address[](0);
        bytes memory twPluginInstallData = abi.encode(tokens);

        vm.prank(owner1);
        account2.installPlugin({
            plugin: address(tokenWhitelistPlugin),
            manifestHash: manifestHash,
            pluginInstallData: twPluginInstallData,
            dependencies: dependencies
        });
    }

    function testFail_pluginInstall_revertIfAlreadyInstalled() external {
        bytes32 manifestHash = keccak256(abi.encode(tokenWhitelistPlugin.pluginManifest()));

        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);
        bytes memory twPluginInstallData = abi.encode(tokens);

        FunctionReference[] memory dependencies = new FunctionReference[](0);

        vm.prank(owner1);
        account1.installPlugin({
            plugin: address(tokenWhitelistPlugin),
            manifestHash: manifestHash,
            pluginInstallData: twPluginInstallData,
            dependencies: dependencies
        });
    }

    function test_pluginUninstall() external {
        assertTrue(tokenWhitelistPlugin.isAllowedToken(address(account1), address(token1)));

        bytes memory serializedManifest = abi.encode(tokenWhitelistPlugin.pluginManifest());

        bytes memory config = abi.encode(
            UpgradeableModularAccount.UninstallPluginConfig({
                serializedManifest: serializedManifest,
                forceUninstall: false,
                callbackGasLimit: 0
            })
        );

        vm.prank(owner1);
        account1.uninstallPlugin({plugin: address(tokenWhitelistPlugin), config: config, pluginUninstallData: ""});

        assertFalse(tokenWhitelistPlugin.isAllowedToken(address(account1), address(token1)));
    }

    // endregion

    // region - view functions

    function test_isAllowedToken() external {
        bytes memory isAllowedTokenCall =
            abi.encodeCall(TokenWhitelistPlugin.isAllowedToken, (address(account1), address(token1)));

        (, bytes memory data) = address(account1).call(isAllowedTokenCall);
        (bool isAllowed) = abi.decode(data, (bool));
        assertTrue(isAllowed);
    }

    function test_getTokens() external {
        bytes memory getTokensCall = abi.encodeCall(TokenWhitelistPlugin.getTokens, (address(account1)));

        (, bytes memory data) = address(account1).call(getTokensCall);
        (address[] memory tokens) = abi.decode(data, (address[]));
        assertEq(tokens[0], address(token1));
    }

    function test_pluginMetadata() external {
        PluginMetadata memory twPluginMetadata = tokenWhitelistPlugin.pluginMetadata();

        assertEq(twPluginMetadata.name, "Token Whitelist Plugin");
        assertEq(twPluginMetadata.version, "1.0.0");
        assertEq(twPluginMetadata.author, "Metalamp");
        assertEq(twPluginMetadata.permissionDescriptors[0].functionSelector, TokenWhitelistPlugin.updateTokens.selector);

        string memory modifyTokensListPermission = "Modify tokens list";
        assertEq(twPluginMetadata.permissionDescriptors[0].permissionDescription, modifyTokensListPermission);
    }

    // endregion

    // region - userOp transfers

    function _sendUserOpOwner1(address account, bytes memory callData) private {
        UserOperation memory userOp = UserOperation({
            sender: account,
            nonce: 0,
            initCode: "",
            callData: callData,
            callGasLimit: CALL_GAS_LIMIT,
            verificationGasLimit: VERIFICATION_GAS_LIMIT,
            preVerificationGas: 0,
            maxFeePerGas: 2,
            maxPriorityFeePerGas: 1,
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());
        userOp.signature = abi.encodePacked(r, s, v);

        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;
        entryPoint.handleOps(userOps, beneficiary);
    }

    function test_transferToken_userOpExecute_success() external {
        uint256 transferAmount = 100e18;

        token1.mint(address(account1), transferAmount);
        assertEq(token1.balanceOf(address(account1)), transferAmount);
        assertEq(token1.balanceOf(owner1), 0);

        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, 100e18));
        bytes memory callData = abi.encodeCall(UpgradeableModularAccount.execute, (address(token1), 0, transferCall));

        _sendUserOpOwner1(address(account1), callData);

        assertEq(token1.balanceOf(owner1), transferAmount);
    }

    function test_transferToken_userOpExecute_transferFailedInUserOp() external {
        uint256 transferAmount = 100e18;

        ERC20Mock token2 = new ERC20Mock();

        token2.mint(address(account1), transferAmount);
        assertEq(token2.balanceOf(address(account1)), transferAmount);
        assertEq(token2.balanceOf(owner1), 0);

        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, 100e18));
        bytes memory callData = abi.encodeCall(UpgradeableModularAccount.execute, (address(token2), 0, transferCall));

        _sendUserOpOwner1(address(account1), callData);

        assertEq(token2.balanceOf(address(account1)), transferAmount);
        assertEq(token2.balanceOf(owner1), 0);
    }

    function test_transferToken_userOpExecuteBatch_success() external {
        uint256 transferAmount = 100e18;
        token1.mint(address(account1), transferAmount);

        bytes memory callToToken1 = abi.encodeCall(ERC20.transfer, (owner1, transferAmount / 2));
        bytes memory callToToken2 = abi.encodeCall(ERC20.approve, (address(account1), transferAmount / 2));
        bytes memory callToToken3 = abi.encodeCall(ERC20.transferFrom, (address(account1), owner1, transferAmount / 2));

        Call[] memory callsData = new Call[](3);
        callsData[0] = Call(address(token1), 0, callToToken1);
        callsData[1] = Call(address(token1), 0, callToToken2);
        callsData[2] = Call(address(token1), 0, callToToken3);

        bytes memory callData = abi.encodeCall(UpgradeableModularAccount.executeBatch, (callsData));
        _sendUserOpOwner1(address(account1), callData);

        assertEq(token1.balanceOf(owner1), transferAmount);
    }

    function test_transferToken_userOpExecuteBatch_transferFailedInUserOp() external {
        uint256 transferAmount = 100e18;
        token1.mint(address(account1), transferAmount);

        ERC20Mock token2 = new ERC20Mock();
        token2.mint(address(account1), transferAmount);

        bytes memory callToToken1 = abi.encodeCall(ERC20.transfer, (owner1, transferAmount));
        bytes memory callToToken2 = abi.encodeCall(ERC20.approve, (address(account1), transferAmount));
        bytes memory callToToken3 = abi.encodeCall(ERC20.transferFrom, (address(account1), owner1, transferAmount));

        Call[] memory callsData = new Call[](3);
        callsData[0] = Call(address(token1), 0, callToToken1);
        callsData[1] = Call(address(token2), 0, callToToken2);
        callsData[2] = Call(address(token2), 0, callToToken3);

        bytes memory callData = abi.encodeCall(UpgradeableModularAccount.executeBatch, (callsData));
        _sendUserOpOwner1(address(account1), callData);

        assertEq(token2.balanceOf(address(account1)), transferAmount);
        assertEq(token2.balanceOf(owner1), 0);
    }

    // endregion

    // region - runtime transfers

    function test_transferToken_runtimeExecute_success() external {
        uint256 transferAmount = 100e18;

        token1.mint(address(account1), transferAmount);
        assertEq(token1.balanceOf(address(account1)), transferAmount);
        assertEq(token1.balanceOf(owner1), 0);

        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, 100e18));

        vm.prank(owner1);
        account1.execute(address(token1), 0, transferCall);

        assertEq(token1.balanceOf(owner1), transferAmount);
    }

    function testFail_transferToken_runtimeExecute_revertIfNotOwner() external {
        uint256 transferAmount = 100e18;

        token1.mint(address(account1), transferAmount);

        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, 100e18));
        account1.execute(address(token1), 0, transferCall);
    }

    function test_transferToken_runtimeExecuteBatch_success() external {
        uint256 transferAmount = 100e18;
        token1.mint(address(account1), transferAmount);

        bytes memory callToToken1 = abi.encodeCall(ERC20.transfer, (owner1, transferAmount / 2));
        bytes memory callToToken2 = abi.encodeCall(ERC20.approve, (address(account1), transferAmount / 2));
        bytes memory callToToken3 = abi.encodeCall(ERC20.transferFrom, (address(account1), owner1, transferAmount / 2));

        Call[] memory callsData = new Call[](3);
        callsData[0] = Call(address(token1), 0, callToToken1);
        callsData[1] = Call(address(token1), 0, callToToken2);
        callsData[2] = Call(address(token1), 0, callToToken3);

        vm.prank(owner1);
        account1.executeBatch(callsData);

        assertEq(token1.balanceOf(owner1), transferAmount);
    }

    // endregion

    // region - updateTokens

    function test_updateTokens_addTokens_success() external {
        ERC20Mock token2 = new ERC20Mock();
        assertFalse(tokenWhitelistPlugin.isAllowedToken(address(account1), address(token2)));

        address[] memory zeroArray = new address[](0);
        address[] memory tokens = new address[](1);
        tokens[0] = address(token2);

        bytes memory updateCall = abi.encodeCall(TokenWhitelistPlugin.updateTokens, (tokens, zeroArray));
        vm.prank(owner1);
        (bool success,) = address(account1).call(updateCall);
        assertTrue(success);

        assertTrue(tokenWhitelistPlugin.isAllowedToken(address(account1), address(token2)));
    }

    function test_updateTokens_removeTokens_success() external {
        assertTrue(tokenWhitelistPlugin.isAllowedToken(address(account1), address(token1)));

        address[] memory zeroArray = new address[](0);
        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);

        bytes memory updateCall = abi.encodeCall(TokenWhitelistPlugin.updateTokens, (zeroArray, tokens));

        vm.prank(owner1);
        (bool success,) = address(account1).call(updateCall);
        assertTrue(success);

        assertFalse(tokenWhitelistPlugin.isAllowedToken(address(account1), address(token1)));
    }

    function test_updateTokens_addTokens_revertIfInvalidToken() external {
        address[] memory zeroArray = new address[](0);
        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);

        bytes memory updateCall = abi.encodeCall(TokenWhitelistPlugin.updateTokens, (tokens, zeroArray));

        vm.expectRevert(abi.encodeWithSelector(TokenWhitelistPlugin.TokenAlreadyAdded.selector, address(token1)));
        vm.prank(owner1);
        (bool success,) = address(account1).call(updateCall);
        assertTrue(success);
    }

    function test_updateTokens_removeTokens_revertIfInvalidToken() external {
        address[] memory zeroArray = new address[](0);
        ERC20Mock token2 = new ERC20Mock();
        address[] memory tokens = new address[](1);
        tokens[0] = address(token2);

        bytes memory updateCall = abi.encodeCall(TokenWhitelistPlugin.updateTokens, (zeroArray, tokens));

        vm.expectRevert(abi.encodeWithSelector(TokenWhitelistPlugin.TokenNotExist.selector, address(token2)));
        vm.prank(owner1);
        (bool success,) = address(account1).call(updateCall);
        assertTrue(success);
    }

    function test_updateTokens_removeTokens_revertIfEmptyTokens() external {
        address[] memory zeroArray = new address[](0);

        bytes memory updateCall = abi.encodeCall(TokenWhitelistPlugin.updateTokens, (zeroArray, zeroArray));

        vm.expectRevert(TokenWhitelistPlugin.EmptyTokensNotAllowed.selector);
        vm.prank(owner1);
        (bool success,) = address(account1).call(updateCall);
        assertTrue(success);
    }

    // endregion
}
