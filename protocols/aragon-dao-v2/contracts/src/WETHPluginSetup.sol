// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PluginSetup, IPluginSetup} from "@aragon/osx/framework/plugin/setup/PluginSetup.sol";
import {PermissionLib} from "@aragon/osx/core/permission/PermissionLib.sol";
import {WETHPlugin, IDAO, IWETH} from "src/WETHPlugin.sol";

contract WETHPluginSetup is PluginSetup {
    /// @notice Адрес плагина
    address private immutable wethPlugin;

    /// @notice Ошибка в случае если адрес WETH не передан
    error WethAddressInvalid();

    /// @dev Контракт PluginSetup развертывается только один раз для плагина
    constructor() {
        wethPlugin = address(new WETHPlugin());
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallation(address _dao, bytes calldata _data)
        external
        returns (address plugin, PreparedSetupData memory preparedSetupData)
    {
        /// Получаем адрес WETH из данных, переданных во время установки
        IWETH weth = abi.decode(_data, (IWETH));

        /// Проверяем, что адрес валидный
        if (address(weth) == address(0)) {
            revert WethAddressInvalid();
        }

        /// Создаем прокси для плагина WETHPlugin
        plugin = createERC1967Proxy(wethPlugin, abi.encodeCall(WETHPlugin.initialize, (IDAO(_dao), weth)));

        /// Выдаем разрешение на вызов функции deposit() для DAO
        PermissionLib.MultiTargetPermission[] memory permissions = new PermissionLib.MultiTargetPermission[](1);

        permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Grant,
            where: plugin,
            who: _dao,
            condition: PermissionLib.NO_CONDITION,
            permissionId: WETHPlugin(this.implementation()).DEPOSIT_PERMISSION()
        });

        preparedSetupData.permissions = permissions;
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallation(address _dao, SetupPayload calldata _payload)
        external
        view
        returns (PermissionLib.MultiTargetPermission[] memory permissions)
    {
        /// Отзываем разрешение на вызов функции deposit() для DAO
        permissions = new PermissionLib.MultiTargetPermission[](1);

        permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Revoke,
            where: _payload.plugin,
            who: _dao,
            condition: PermissionLib.NO_CONDITION,
            permissionId: WETHPlugin(this.implementation()).DEPOSIT_PERMISSION()
        });
    }

    /// @inheritdoc IPluginSetup
    function implementation() external view returns (address) {
        return wethPlugin;
    }
}
