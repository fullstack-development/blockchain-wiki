const { buildModule } = require('@nomicfoundation/hardhat-ignition/modules');
const { ethers } = require('ethers');
require('dotenv').config();

const BRIDGE_WALLET_PRIVATE_KEY = process.env.BRIDGE_WALLET_PRIVATE_KEY;

const AMOY_PROVIDER_URL = process.env.AMOY_PROVIDER_URL;

const rpcAmoyProvider = new ethers.JsonRpcProvider(AMOY_PROVIDER_URL);

const bridgeWallet = new ethers.Wallet(
    BRIDGE_WALLET_PRIVATE_KEY,
    rpcAmoyProvider,
);

module.exports = buildModule('DestinationTokenModule', (m) => {
    const destToken = m.contract('DestinationToken', [bridgeWallet.address]);

    return { destToken };
});
