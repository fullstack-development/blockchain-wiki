// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {PluginSetupRef, PluginSettings} from "src/helpers/PluginRepoHelpers.sol";

struct DAOSettings {
    address trustedForwarder;
    string daoURI;
    string subdomain;
    bytes metadata;
}

interface IDAOFactory {
    function createDao(DAOSettings calldata _daoSettings, PluginSettings[] calldata _pluginSettings)
        external
        returns (IDAO createdDao);
}
