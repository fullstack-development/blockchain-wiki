// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PluginSetupRef, PluginRepo} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessorHelpers.sol";

struct PluginSettings {
    PluginSetupRef pluginSetupRef;
    bytes data;
}
