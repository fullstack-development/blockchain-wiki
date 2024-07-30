// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {TokenVoting} from "@aragon/osx/plugins/governance/majority-voting/token/TokenVoting.sol";
import {PluginSetupRef, hashHelpers} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessorHelpers.sol";
import {PluginRepoFactory, PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepoFactory.sol";
import {IMajorityVoting} from "@aragon/osx/plugins/governance/majority-voting/IMajorityVoting.sol";
import {PluginSetupProcessor} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessor.sol";
import {IPluginSetup} from "@aragon/osx/framework/plugin/setup/IPluginSetup.sol";
import {PermissionManager} from "@aragon/osx/core/permission/PermissionManager.sol";
import {DAO, IDAO} from "@aragon/osx/core/dao/DAO.sol";

import {WETHPluginSetup} from "src/WETHPluginSetup.sol";

contract InstallWethPlugin is Script {
    /// Здесь необходимо изменить: DEPLOYER_ADDRESS, DAO_ADDRESS
    address constant DEPLOYER_ADDRESS = 0x32bb35Fc246CB3979c4Df996F18366C6c753c29c;
    address constant DAO_ADDRESS = 0x201836b4AEE703f29913c4b5CEb7E1c16C5eAb7b;

    address constant PLUGIN_REPO_FACTORY = 0x07f49c49Ce2A99CF7C28F66673d406386BDD8Ff4;
    address constant PLUGIN_SETUP_PROCESSOR = 0xC24188a73dc09aA7C721f96Ad8857B469C01dC9f;
    address constant WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address constant TOKEN_VOTING = 0xAABcB955DC1Ab7fDE229944DD329b4efc10c4ca7;

    /// Используем pluginRepoFactory и pluginSetupProcessor в сети Sepolia
    PluginRepoFactory pluginRepoFactory = PluginRepoFactory(PLUGIN_REPO_FACTORY);
    PluginSetupProcessor pluginSetupProcessor = PluginSetupProcessor(PLUGIN_SETUP_PROCESSOR);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        /// Шаг 1 - Деплоим смарт-контракт с настройками для установки плагина
        WETHPluginSetup pluginSetupAddress = new WETHPluginSetup();

        /// Шаг 2 - Создаем и регистрируем PluginRepo
        /// 2.1 Поддомен для регистрации плагина в ENS
        string memory subdomain = "weth-plugin";
        /// 2.2 Метаданные (нельзя передавать bytes(0))
        bytes memory releaseMetadata = new bytes(1);
        bytes memory buildMetadata = new bytes(1);
        /// 2.3 Деплой и регистрация PluginRepo
        PluginRepo pluginRepo = pluginRepoFactory.createPluginRepoWithFirstVersion(
            subdomain, address(pluginSetupAddress), DEPLOYER_ADDRESS, releaseMetadata, buildMetadata
        );

        /// Шаг 3 - Делаем запрос на установку плагина в наше DAO
        /// Для этого нужно подготовить параметры
        /// 3.1 Версия плагина и адрес PluginRepo
        PluginSetupRef memory pluginSetupRef =
            PluginSetupRef(PluginRepo.Tag({release: uint8(1), build: uint16(1)}), pluginRepo);

        /// 3.2 Данные, необходимые для установки плагина
        bytes memory payload = abi.encode(WETH);

        /// 3.3 Формируем окончательные параметры
        PluginSetupProcessor.PrepareInstallationParams memory prepareInstallationParams =
            PluginSetupProcessor.PrepareInstallationParams(pluginSetupRef, payload);

        /// 3.4 Делаем предустановку (это только первый этап установки)
        (address plugin, IPluginSetup.PreparedSetupData memory preparedSetupData) =
            pluginSetupProcessor.prepareInstallation(DAO_ADDRESS, prepareInstallationParams);

        /// Шаг 4 - Подготовка к окончательной установке плагина
        /// 4.1 Хелперы не понадобятся, поэтому создаем пустой массив
        address[] memory helpers = new address[](0);

        /// 4.2 Выставляем параметры установки
        /// Адрес плагина получили на предустановке, т.к. он был развернут через prepareInstallation
        /// pluginSetupRef уже сформированы ранее
        /// permissions используются из WETHPluginSetup
        PluginSetupProcessor.ApplyInstallationParams memory applyInstallationParams = PluginSetupProcessor
            .ApplyInstallationParams({
            pluginSetupRef: pluginSetupRef,
            plugin: plugin,
            permissions: preparedSetupData.permissions,
            helpersHash: hashHelpers(helpers)
        });

        /// Шаг 5 - Т.к. установку может выполнить только DAO, а функцию DAO::execute() можно вызывать
        /// только через приложение TokenVoting, необходимо создать голосование на эти действия

        /// 5.1 Получаем инстанс приложения TokenVoting
        TokenVoting tokenVoting = TokenVoting(TOKEN_VOTING);

        /// 5.2 Формируем массив Action, который будет передан на исполнение DAO
        /// Помимо непосредственной установки плагина WETHPlugin
        /// Понадобится выдать разрешение ROOT_PERMISSION_ID контракту PluginSetupProcessor
        /// Чтобы он мог выдать разрешения из WETHPluginSetup
        /// После чего это разрешение нужно отозвать 
        IDAO.Action[] memory actions = new IDAO.Action[](3);
        
        /// Действие на выдачу разрешения ROOT_PERMISSION_ID для PluginSetupProcessor
        actions[0] = IDAO.Action({
            to: address(DAO_ADDRESS),
            value: 0,
            data: abi.encodeCall(
                PermissionManager.grant,
                (DAO_ADDRESS, address(pluginSetupProcessor), DAO(payable(DAO_ADDRESS)).ROOT_PERMISSION_ID())
            )
        });
        /// Действие на установку плагина
        actions[1] = IDAO.Action({
            to: address(pluginSetupProcessor),
            value: 0,
            data: abi.encodeCall(PluginSetupProcessor.applyInstallation, (DAO_ADDRESS, applyInstallationParams))
        });
        /// Действие на отзыв разрешения ROOT_PERMISSION_ID для PluginSetupProcessor
        actions[2] = IDAO.Action({
            to: address(DAO_ADDRESS),
            value: 0,
            data: abi.encodeCall(
                PermissionManager.revoke,
                (DAO_ADDRESS, address(pluginSetupProcessor), DAO(payable(DAO_ADDRESS)).ROOT_PERMISSION_ID())
            )
        });
        
        /// 5.3 Создаем предложение для голосования
        bytes memory metadata = new bytes(0);
        uint256 proposalId =
            tokenVoting.createProposal(metadata, actions, 0, 0, 0, IMajorityVoting.VoteOption.None, false);

        /// Шаг 6 - Голосуем за предложение (т.к. мы единственные держатели токенов голосования)
        tokenVoting.vote(proposalId, IMajorityVoting.VoteOption.Yes, false);

        /// Шаг 7 - Выполняем предложение (только на этом шаге плагин будет установлен)
        tokenVoting.execute(proposalId);

        vm.stopBroadcast();

        console.log("------------------ Deployed contracts --------------------");
        console.log("WethPlugin        : ", plugin);
        console.log("WETHPluginSetup   : ", address(pluginSetupAddress));
        console.log("WethPluginRepo    : ", address(pluginRepo));
        console.log("------------------ Deployment info -----------------------");
        console.log("Chain id           : ", block.chainid);
        console.log("Deployer          : ", vm.addr(deployerPrivateKey));
    }
}
