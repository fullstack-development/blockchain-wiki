// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DestinationToken is ERC20, ERC20Burnable, Ownable {
    address private _bridge;

    error OnlyBridge();

    event NewBridgeSet(address newBridge);

    constructor(address bridge) ERC20("DestinationToken", "DT") Ownable(msg.sender) {
        _bridge = bridge;
    }

    modifier onlyBridge() {
        if (msg.sender != _bridge) {
            revert OnlyBridge();
        }

        _;
    }

    function mint(address recipient, uint256 amount) external onlyBridge {
        _mint(recipient, amount);
    }

    function burnFrom(address account, uint256 amount) public override(ERC20Burnable) onlyBridge {
        super.burnFrom(account, amount);
    }

    function setNewBridge(address bridge) external onlyOwner {
        _bridge = bridge;
        emit NewBridgeSet(bridge);
    }

    function getBridge() external view returns (address) {
        return _bridge;
    }
}
