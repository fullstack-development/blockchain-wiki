// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

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

import {TokenWhitelistPlugin} from "src/TokenWhitelistPlugin.sol";
import {TransferLimitPlugin} from "src/TransferLimitPlugin.sol";

contract TransferLimitPluginTest is Test {
    using ECDSA for bytes32;

    IEntryPoint entryPoint;
    UpgradeableModularAccount account1;
    TokenWhitelistPlugin tokenWhitelistPlugin;
    TransferLimitPlugin transferLimitPlugin;
    MultiOwnerPlugin multiOwnerPlugin;
    MultiOwnerModularAccountFactory factory;
    ERC20Mock token1;

    address owner1;
    uint256 owner1Key;
    address payable beneficiary;

    uint256 constant CALL_GAS_LIMIT = 1000000;
    uint256 constant VERIFICATION_GAS_LIMIT = 1000000;
    uint256 constant TRANSFER_LIMIT = 50e18;

    function setUp() public {
        // Create EntryPoint
        entryPoint = IEntryPoint(address(new EntryPoint()));

        // Create beneficiary
        beneficiary = payable(makeAddr("beneficiary"));

        // Deploy MultiOwnerPlugin
        multiOwnerPlugin = new MultiOwnerPlugin();
        bytes32 multiOwnerPluginManifestHash = keccak256(abi.encode(multiOwnerPlugin.pluginManifest()));
        vm.label(address(multiOwnerPlugin), "MultiOwnerPlugin");

        // Deploy AccountFactory
        address implementation = address(new UpgradeableModularAccount(entryPoint));
        vm.label(implementation, "ModularAccountImplementation");
        factory = new MultiOwnerModularAccountFactory(
            owner1, address(multiOwnerPlugin), implementation, multiOwnerPluginManifestHash, entryPoint
        );

        // Create owner of account
        (owner1, owner1Key) = makeAddrAndKey("owner1");
        address[] memory owners = new address[](1);
        owners[0] = owner1;

        // Create account
        account1 = UpgradeableModularAccount(payable(factory.createAccount(1, owners)));
        vm.deal(address(account1), 100 ether);
        vm.label(address(account1), "Account1");

        // Add dependency plugin for TokenWhitelistPlugin and TransferLimitPlugin
        FunctionReference[] memory dependencies = new FunctionReference[](1);
        dependencies[0] = FunctionReferenceLib.pack(
            address(multiOwnerPlugin), uint8(IMultiOwnerPlugin.FunctionId.RUNTIME_VALIDATION_OWNER_OR_SELF)
        );

        _installTokenWhitelistPlugin(dependencies);
        _installTransferLimitPlugin(dependencies);
    }

    // region - Plugin installation

    function _installTokenWhitelistPlugin(FunctionReference[] memory dependencies) private {
        // Deploy TokenWhitelistPlugin
        tokenWhitelistPlugin = new TokenWhitelistPlugin();
        bytes32 tokenWhitelistManifestHash = keccak256(abi.encode(tokenWhitelistPlugin.pluginManifest()));

        // Configure settings
        address[] memory tokens = new address[](1);
        token1 = new ERC20Mock();
        tokens[0] = address(token1);
        bytes memory twPluginInstallData = abi.encode(tokens);

        // Install this plugin on the account1 as the owner
        vm.prank(owner1);
        account1.installPlugin({
            plugin: address(tokenWhitelistPlugin),
            manifestHash: tokenWhitelistManifestHash,
            pluginInstallData: twPluginInstallData,
            dependencies: dependencies
        });
    }

    function _installTransferLimitPlugin(FunctionReference[] memory dependencies) private {
        // Deploy plugin
        transferLimitPlugin = new TransferLimitPlugin();
        vm.label(address(transferLimitPlugin), "TransferLimitPlugin");

        bytes32 transferLimitManifestHash = keccak256(abi.encode(transferLimitPlugin.pluginManifest()));

        // Configure settings
        TransferLimitPlugin.ERC20SpendLimit[] memory spendLimits = new TransferLimitPlugin.ERC20SpendLimit[](1);
        spendLimits[0] = TransferLimitPlugin.ERC20SpendLimit({token: address(token1), limit: TRANSFER_LIMIT});
        bytes memory transferLimitPluginInstallData = abi.encode(spendLimits);

        // Install plugin on the account1
        vm.prank(owner1);
        account1.installPlugin(
            address(transferLimitPlugin), transferLimitManifestHash, transferLimitPluginInstallData, dependencies
        );
    }

    // region - Plugin installation

    function test_plugins_successInstalled() external {
        address[] memory pluginAddresses = account1.getInstalledPlugins();

        assertEq(pluginAddresses[0], address(transferLimitPlugin), "first");
        assertEq(pluginAddresses[1], address(tokenWhitelistPlugin), "second");
        assertEq(pluginAddresses[2], address(multiOwnerPlugin), "third");
    }

    function test_installPlugin_tokenAndLimitSuccessfullyAdded() external {
        address[] memory tokens = transferLimitPlugin.getTokensForAccount(address(account1));
        assertEq(tokens[0], address(token1));

        uint256 currentLimit = transferLimitPlugin.getCurrentLimit(address(account1), address(token1));
        assertEq(currentLimit, TRANSFER_LIMIT);
    }

    function test_uninstallPlugin() external {
        assertEq(transferLimitPlugin.getCurrentLimit(address(account1), address(token1)), TRANSFER_LIMIT);

        bytes memory serializedManifest = abi.encode(transferLimitPlugin.pluginManifest());

        bytes memory config = abi.encode(
            UpgradeableModularAccount.UninstallPluginConfig({
                serializedManifest: serializedManifest,
                forceUninstall: false,
                callbackGasLimit: 0
            })
        );

        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);
        bytes memory uninstallData = abi.encode(tokens);

        vm.prank(owner1);
        account1.uninstallPlugin({
            plugin: address(transferLimitPlugin),
            config: config,
            pluginUninstallData: uninstallData
        });

        address[] memory tokensAfterUninstall = transferLimitPlugin.getTokensForAccount(address(account1));
        assertEq(tokensAfterUninstall.length, 0);
        assertEq(transferLimitPlugin.getCurrentLimit(address(account1), address(token1)), 0);
    }

    // endregion

    // region - Update limits

    function test_updateLimit() external {
        ERC20Mock token2 = new ERC20Mock();

        // 1. Add limit for token2
        bytes memory addLimitCall = abi.encodeCall(TransferLimitPlugin.updateLimit, (address(token2), TRANSFER_LIMIT));

        vm.prank(owner1);
        (bool success,) = address(account1).call(addLimitCall);
        assertTrue(success);

        assertEq(transferLimitPlugin.getCurrentLimit(address(account1), address(token2)), TRANSFER_LIMIT);

        // 2. remove limit for token1
        bytes memory removeLimitCall = abi.encodeCall(TransferLimitPlugin.updateLimit, (address(token1), 0));

        vm.prank(owner1);
        (success,) = address(account1).call(removeLimitCall);
        assertTrue(success);

        assertEq(transferLimitPlugin.getCurrentLimit(address(account1), address(token1)), 0);

        // 3. update limit for token2
        bytes memory updateLimitCall =
            abi.encodeCall(TransferLimitPlugin.updateLimit, (address(token2), TRANSFER_LIMIT / 2));

        vm.prank(owner1);
        (success,) = address(account1).call(updateLimitCall);
        assertTrue(success);

        assertEq(transferLimitPlugin.getCurrentLimit(address(account1), address(token2)), TRANSFER_LIMIT / 2);
    }

    // endregion

    // region - View functions

    function test_getCurrentLimit() external {
        bytes memory getCurrentLimitCall =
            abi.encodeCall(TransferLimitPlugin.getCurrentLimit, (address(account1), address(token1)));

        (, bytes memory data) = address(account1).call(getCurrentLimitCall);
        (uint256 currentLimit) = abi.decode(data, (uint256));
        assertEq(currentLimit, TRANSFER_LIMIT);
    }

    function test_getTokensForAccount() external {
        ERC20Mock token2 = new ERC20Mock();

        bytes memory addLimitCall = abi.encodeCall(TransferLimitPlugin.updateLimit, (address(token2), TRANSFER_LIMIT));
        vm.prank(owner1);
        (bool success,) = address(account1).call(addLimitCall);
        assertTrue(success);

        bytes memory getTokensForAccountCall =
            abi.encodeCall(TransferLimitPlugin.getTokensForAccount, (address(account1)));

        (, bytes memory data) = address(account1).call(getTokensForAccountCall);
        (address[] memory tokens) = abi.decode(data, (address[]));
        assertEq(tokens.length, 2);
        assertEq(tokens[0], address(token2));
        assertEq(tokens[1], address(token1));
    }

    function test_pluginMetadata() external {
        PluginMetadata memory transferLimitPluginMetadata = transferLimitPlugin.pluginMetadata();

        assertEq(transferLimitPluginMetadata.name, "ERC20 Transfer Limit Plugin");
        assertEq(transferLimitPluginMetadata.version, "1.0.0");
        assertEq(transferLimitPluginMetadata.author, "Metalamp");
        assertEq(
            transferLimitPluginMetadata.permissionDescriptors[0].functionSelector,
            TransferLimitPlugin.updateLimit.selector
        );

        string memory modifyTokenLimitsPermission = "Modify ERC20 token limits";
        assertEq(
            transferLimitPluginMetadata.permissionDescriptors[0].permissionDescription, modifyTokenLimitsPermission
        );
    }

    // endregion

    // region - runtime transfers

    function test_transferTokenWithLimit_runtimeExecute_success() external {
        uint256 transferAmount = 100e18;
        uint256 sendAmount = transferAmount / 2;

        token1.mint(address(account1), transferAmount);

        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, sendAmount));

        vm.prank(owner1);
        account1.execute(address(token1), 0, transferCall);

        assertEq(token1.balanceOf(address(account1)), TRANSFER_LIMIT);
        assertEq(token1.balanceOf(owner1), sendAmount);
    }

    function test_transferTokenWithLimit_runtimeExecuteBatch_success() external {
        uint256 transferAmount = 100e18;
        uint256 sendAmount = transferAmount / 2;

        token1.mint(address(account1), transferAmount);

        bytes memory callToToken1 = abi.encodeCall(ERC20.transfer, (owner1, sendAmount / 2));
        bytes memory callToToken2 = abi.encodeCall(ERC20.approve, (address(account1), sendAmount / 2));
        bytes memory callToToken3 = abi.encodeCall(ERC20.transferFrom, (address(account1), owner1, sendAmount / 2));

        Call[] memory callsData = new Call[](3);
        callsData[0] = Call(address(token1), 0, callToToken1);
        callsData[1] = Call(address(token1), 0, callToToken2);
        callsData[2] = Call(address(token1), 0, callToToken3);

        vm.prank(owner1);
        account1.executeBatch(callsData);

        assertEq(token1.balanceOf(address(account1)), TRANSFER_LIMIT);
        assertEq(token1.balanceOf(owner1), sendAmount);
    }

    function test_transferTokenWithLimit_revertIfInsufficientBalance() external {
        uint256 transferAmount = 100e18;

        token1.mint(address(account1), transferAmount);

        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, transferAmount + 1));

        vm.expectRevert(
            abi.encodeWithSignature(
                "PreExecHookReverted(address,uint8,bytes)",
                address(transferLimitPlugin),
                0,
                abi.encodeWithSignature("InsufficientBalance(address,uint256)", address(token1), transferAmount)
            )
        );
        vm.prank(owner1);
        account1.execute(address(token1), 0, transferCall);
    }

    function test_transferTokenWithLimit_revertIfEndBalanceLessThanLimit() external {
        uint256 transferAmount = 100e18;

        token1.mint(address(account1), transferAmount);

        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, transferAmount));

        vm.expectRevert(
            abi.encodeWithSignature(
                "PreExecHookReverted(address,uint8,bytes)",
                address(transferLimitPlugin),
                0,
                abi.encodeWithSignature("EndBalanceLessThanLimit(address,uint256)", address(token1), TRANSFER_LIMIT)
            )
        );
        vm.prank(owner1);
        account1.execute(address(token1), 0, transferCall);
    }

    function test_transferTokenWithLimit_revertIfNotAuthorized() external {
        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, 0));

        vm.expectRevert(
            abi.encodeWithSignature(
                "RuntimeValidationFunctionReverted(address,uint8,bytes)",
                address(multiOwnerPlugin),
                0,
                abi.encodeWithSignature("NotAuthorized()")
            )
        );
        account1.execute(address(token1), 0, transferCall);
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
        uint256 sendAmount = 50e18;

        token1.mint(address(account1), transferAmount);
        assertEq(token1.balanceOf(address(account1)), transferAmount);
        assertEq(token1.balanceOf(owner1), 0);

        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, sendAmount));
        bytes memory callData = abi.encodeCall(UpgradeableModularAccount.execute, (address(token1), 0, transferCall));

        _sendUserOpOwner1(address(account1), callData);

        assertEq(token1.balanceOf(owner1), sendAmount);
    }

    function test_transferToken_userOpExecute_transferFailedInUserOp() external {
        uint256 transferAmount = 100e18;

        ERC20Mock token2 = new ERC20Mock();
        token2.mint(address(account1), transferAmount);

        // Add token2 to TransferLimit
        bytes memory addToken2LimitCall =
            abi.encodeCall(TransferLimitPlugin.updateLimit, (address(token2), TRANSFER_LIMIT));

        vm.prank(owner1);
        (bool success,) = address(account1).call(addToken2LimitCall);
        assertTrue(success);

        // Send userOp
        bytes memory transferCall = abi.encodeCall(ERC20.transfer, (owner1, transferAmount));
        bytes memory callData = abi.encodeCall(UpgradeableModularAccount.execute, (address(token2), 0, transferCall));

        _sendUserOpOwner1(address(account1), callData);

        assertEq(token2.balanceOf(address(account1)), transferAmount);
        assertEq(token2.balanceOf(owner1), 0);
    }

    function test_transferToken_userOpExecuteBatch_success() external {
        uint256 transferAmount = 100e18;
        uint256 sendAmount = transferAmount / 2;

        token1.mint(address(account1), transferAmount);

        bytes memory callToToken1 = abi.encodeCall(ERC20.transfer, (owner1, sendAmount / 2));
        bytes memory callToToken2 = abi.encodeCall(ERC20.approve, (address(account1), sendAmount / 2));
        bytes memory callToToken3 = abi.encodeCall(ERC20.transferFrom, (address(account1), owner1, sendAmount / 2));

        Call[] memory callsData = new Call[](3);
        callsData[0] = Call(address(token1), 0, callToToken1);
        callsData[1] = Call(address(token1), 0, callToToken2);
        callsData[2] = Call(address(token1), 0, callToToken3);

        bytes memory callData = abi.encodeCall(UpgradeableModularAccount.executeBatch, (callsData));
        _sendUserOpOwner1(address(account1), callData);

        assertEq(token1.balanceOf(owner1), sendAmount);
    }

    // endregion
}
