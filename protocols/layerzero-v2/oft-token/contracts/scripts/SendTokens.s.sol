// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {SendParam, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";

import {MetaLampOFTv1} from "contracts/MetaLampOFTv1.sol";

contract SendTokens is Script {
    using OptionsBuilder for bytes;

    function run(address sender, address token, address recipient, uint256 amountLD, uint32 dstEid)
        external
    {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: addressToBytes32(recipient),
            amountLD: amountLD,
            minAmountLD: amountLD,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(ownerPrivateKey);

        MetaLampOFTv1 metalampOftV1 = MetaLampOFTv1(token);
        MessagingFee memory fee = metalampOftV1.quoteSend(sendParam, false);

        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) =
            metalampOftV1.send{value: fee.nativeFee}(sendParam, fee, payable(sender));

        vm.stopBroadcast();

        console.log("GUID: ");
        console.logBytes32(msgReceipt.guid);
        console.log(
            "MessagingReceipt: nonce: %d, fee: %d", msgReceipt.nonce, msgReceipt.fee.nativeFee
        );

        console.log(
            "OFTReceipt: amountSentLD: %d, amountReceivedLD: %d",
            oftReceipt.amountSentLD,
            oftReceipt.amountReceivedLD
        );
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function encode(address _sendTo, uint256 _amountLD, bytes memory _composeMsg)
        external
        view
        returns (bytes memory _msg, bool hasCompose)
    {
        hasCompose = _composeMsg.length > 0;
        // @dev Remote chains will want to know the composed function caller ie. msg.sender on the src.
        _msg = hasCompose
            ? abi.encodePacked(
                addressToBytes32(_sendTo), _toSD(_amountLD), addressToBytes32(msg.sender), _composeMsg
            )
            : abi.encodePacked(addressToBytes32(_sendTo), _toSD(_amountLD));
    }

    function _toSD(uint256 _amountLD) internal view virtual returns (uint64 amountSD) {
        return uint64(_amountLD / 1e12);
    }
}
