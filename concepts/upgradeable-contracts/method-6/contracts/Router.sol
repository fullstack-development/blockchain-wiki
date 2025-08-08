// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";

import {RouterStorage} from "./RouterStorage.sol";
import {IActionStorage} from "./ActionStorage.sol";

/**
 * @notice Смарт-контракт Router, который делегирует вызовы к фасетам на основе селекторов
 * @dev Является прокси-контрактом, который использует делегирование вызовов для выполнения функций на разные смарт-контракты (фасеты)
 */
contract Router is Proxy, RouterStorage {
    error InvalidSelector();

    constructor(address actionStorage) {
        RouterStorage.CoreStorage storage $ = _getCoreStorage();
        $.owner = msg.sender;
        // Регистрируем селектор функции setSelectorToFacets в ActionStorage для последующего добавления новых селекторов функция и адресов смарт-контрактов, где эти функции реализованы
        $.selectorToFacet[IActionStorage.setSelectorToFacets.selector] = actionStorage;
    }

    function _implementation() internal view override returns (address facet) {
        RouterStorage.CoreStorage storage $ = _getCoreStorage();

        // Получаем адрес фасета для селектора функции из вызова
        facet = $.selectorToFacet[msg.sig];
        if (facet == address(0)) {
            revert InvalidSelector();
        }
    }
}