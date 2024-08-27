const { buildModule } = require('@nomicfoundation/hardhat-ignition/modules');
require('dotenv').config();

const DESTINATION_TOKEN_CONTRACT_ADDRESS = process.env.DESTINATION_TOKEN_CONTRACT_ADDRESS;

module.exports = buildModule('DestinationTokenBridgeModule', (m) => {
    const amoyRouter = m.getParameter('amoyRouter');
    const originTokenChainSelector = m.getParameter('originTokenChainSelector');
    const amoyChainSelector = m.getParameter('amoyChainSelector');
    const linkAddress = m.getParameter('linkAddress');

    const tokenBridge = m.contract('TokenBridge', [
        amoyRouter,
        DESTINATION_TOKEN_CONTRACT_ADDRESS,
        linkAddress,
        originTokenChainSelector,
        amoyChainSelector,
    ]);

    return { tokenBridge };
});
