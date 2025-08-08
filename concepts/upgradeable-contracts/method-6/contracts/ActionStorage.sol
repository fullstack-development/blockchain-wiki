// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {RouterStorage} from "./RouterStorage.sol";

struct SelectorsToFacet {
    address facet;
    bytes4[] selectors;
}

interface IActionStorage {
    function setSelectorToFacets(SelectorsToFacet[] calldata arr) external;
}

/**
 * @notice Смарт-контракт для хранения и управления селекторами функций и их соответствующими адресами фасетов
 * @dev Добавлять и удалять новые селекторы может только владелец контракта
 */
contract ActionStorage is RouterStorage {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event SelectorToFacetSet(bytes4 indexed selector, address indexed facet);

    modifier onlyOwner() {
        require(msg.sender == owner(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view returns (address) {
        return _getCoreStorage().owner;
    }

    function setSelectorToFacets(SelectorsToFacet[] calldata arr) external onlyOwner {
        CoreStorage storage $ = _getCoreStorage();

        for (uint256 i = 0; i < arr.length; i++) {
            SelectorsToFacet memory s = arr[i];

            for (uint256 j = 0; j < s.selectors.length; j++) {
                $.selectorToFacet[s.selectors[j]] = s.facet;
                emit SelectorToFacetSet(s.selectors[j], s.facet);
            }
        }
    }

    function selectorToFacet(bytes4 selector) external view returns (address) {
        CoreStorage storage $ = _getCoreStorage();
        return $.selectorToFacet[selector];
    }

    function transferOwnership(address newOwner) external onlyOwner {
        CoreStorage storage $ = _getCoreStorage();

        require(newOwner != address(0), "Ownable: zero address"); // TODO: custom error

        $.owner = newOwner;

        emit OwnershipTransferred($.owner, newOwner);
    }
}