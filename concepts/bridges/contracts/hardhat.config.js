require('@nomicfoundation/hardhat-toolbox');
require('dotenv').config();

const SEPOLIA_PROVIDER_URL = process.env.SEPOLIA_PROVIDER_URL;
const AMOY_PROVIDER_URL = process.env.AMOY_PROVIDER_URL;
const WALLET_PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY;

module.exports = {
    solidity: '0.8.24',
    networks: {
        sepolia: {
            url: `${SEPOLIA_PROVIDER_URL}`,
            chainId: 11155111,
            accounts: [WALLET_PRIVATE_KEY],
        },
        polygonAmoy: {
            url: `${AMOY_PROVIDER_URL}`,
            chainId: 80002,
            accounts: [WALLET_PRIVATE_KEY],
        },
    },
};
