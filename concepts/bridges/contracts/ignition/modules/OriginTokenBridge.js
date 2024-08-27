const { buildModule } = require('@nomicfoundation/hardhat-ignition/modules');

require('dotenv').config();

const ORIGIN_TOKEN_CONTRACT_ADDRESS = process.env.ORIGIN_TOKEN_CONTRACT_ADDRESS;

module.exports = buildModule('OriginTokenBridgeModule', (m) => {
    const sepoliaRouter = m.getParameter('sepoliaRouter');
    const originTokenChainSelector = m.getParameter('originTokenChainSelector');
    const linkAddress = m.getParameter('linkAddress');

    const tokenBridge = m.contract('TokenBridge', [
        sepoliaRouter,
        ORIGIN_TOKEN_CONTRACT_ADDRESS,
        linkAddress,
        originTokenChainSelector,
        originTokenChainSelector,
    ]);

    return { tokenBridge };
});
