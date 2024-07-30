// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {TokenVoting} from "@aragon/osx/plugins/governance/majority-voting/token/TokenVoting.sol";
import {IMajorityVoting} from "@aragon/osx/plugins/governance/majority-voting/IMajorityVoting.sol";
import {IDAO} from "@aragon/osx/core/dao/DAO.sol";

import {IWETHPlugin} from "src/interfaces/IWETHPlugin.sol";
import {IWETH} from "src/interfaces/IWETH.sol";

contract DepositToWeth is Script {
    /// Здесь необходимо изменить: DEPLOYER_ADDRESS, DAO_ADDRESS, WETH_PLUGIN
    address constant DEPLOYER_ADDRESS = 0x32bb35Fc246CB3979c4Df996F18366C6c753c29c;
    address constant DAO_ADDRESS = 0x201836b4AEE703f29913c4b5CEb7E1c16C5eAb7b;
    address constant WETH_PLUGIN = 0x6602440aB337addc708cfa10077eabAEda6Cc882;

    address constant WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address constant TOKEN_VOTING = 0xAABcB955DC1Ab7fDE229944DD329b4efc10c4ca7;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        /// Шаг 1 - Отправляем DAO немного эфира (0.000000000000001 ETH)
        IDAO(DAO_ADDRESS).deposit{value: 1000}(address(0), 1000, "");

        /// Шаг 2 - Создаем голосование
        TokenVoting tokenVoting = TokenVoting(TOKEN_VOTING);

        /// 2.2 Добавляем действие WETHPlugin::depositToWeth()
        IDAO.Action[] memory actions = new IDAO.Action[](1);

        /// Депозит 1000 wei (0.000000000000001 ETH)
        actions[0] =
            IDAO.Action({to: WETH_PLUGIN, value: 1000, data: abi.encodeCall(IWETHPlugin.depositToWeth, ())});

        /// 2.3 Создаем предложение для голосования
        bytes memory metadata = new bytes(0);
        uint256 proposalId =
            tokenVoting.createProposal(metadata, actions, 0, 0, 0, IMajorityVoting.VoteOption.None, false);

        /// Шаг 3 - Голосуем за предложение 
        tokenVoting.vote(proposalId, IMajorityVoting.VoteOption.Yes, false);

        /// Шаг 4 - Выполняем предложение (т.к. мы единственные держатели токенов голосования)
        tokenVoting.execute(proposalId);

        /// Шаг 5 - Проверяем выполнение депозита, средства должны поступить на адрес DAO
        uint256 wethPluginBalance = IWETH(WETH).balanceOf(DAO_ADDRESS);

        vm.stopBroadcast();

        console.log("------------------ Scrypt info --------------------");
        console.log("ProposalID        : ", proposalId);
        console.log("wethPluginBalance : ", wethPluginBalance);
        console.log("------------------ Chain info -----------------------");
        console.log("Chain id           : ", block.chainid);
    }
}
