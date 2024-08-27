const { ethers } = require('ethers');
require('dotenv').config();

/*//////////////////////////////////////////////////////////////
                        GET CONSTANTS
//////////////////////////////////////////////////////////////*/

const originTokenAbi = require('../artifacts/contracts/OriginToken.sol/OriginToken.json');
const destinationTokenAbi = require('../artifacts/contracts/DestinationToken.sol/DestinationToken.json');

const WALLET_PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY;
const BRIDGE_WALLET_PRIVATE_KEY = process.env.BRIDGE_WALLET_PRIVATE_KEY;

const ORIGIN_TOKEN_CONTRACT_ADDRESS = process.env.ORIGIN_TOKEN_CONTRACT_ADDRESS;
const DESTINATION_TOKEN_CONTRACT_ADDRESS =
    process.env.DESTINATION_TOKEN_CONTRACT_ADDRESS;

const SEPOLIA_PROVIDER_URL = process.env.SEPOLIA_PROVIDER_URL;
const AMOY_PROVIDER_URL = process.env.AMOY_PROVIDER_URL;

if (!SEPOLIA_PROVIDER_URL && !AMOY_PROVIDER_URL) {
    console.error(new Error('Invalid provider url'));
    process.exit(1);
}

if (!WALLET_PRIVATE_KEY) {
    console.error(new Error('Invalid wallet key'));
    process.exit(1);
}

if (!originTokenAbi.abi && !destinationTokenAbi.abi) {
    throw new Error('ABI is undefined or not loaded correctly.');
}

/*//////////////////////////////////////////////////////////////
                        SETTINGS
//////////////////////////////////////////////////////////////*/

const rpcSepoliaProvider = new ethers.JsonRpcProvider(SEPOLIA_PROVIDER_URL);
const rpcAmoyProvider = new ethers.JsonRpcProvider(AMOY_PROVIDER_URL);

const walletSepolia = new ethers.Wallet(WALLET_PRIVATE_KEY, rpcSepoliaProvider);
const walletAmoy = new ethers.Wallet(WALLET_PRIVATE_KEY, rpcAmoyProvider);

const bridgeWallet = new ethers.Wallet(
    BRIDGE_WALLET_PRIVATE_KEY,
    rpcSepoliaProvider,
);

const originToken = new ethers.Contract(
    ORIGIN_TOKEN_CONTRACT_ADDRESS,
    originTokenAbi.abi,
    walletSepolia,
);

const destinationToken = new ethers.Contract(
    DESTINATION_TOKEN_CONTRACT_ADDRESS,
    destinationTokenAbi.abi,
    walletAmoy,
);

/*//////////////////////////////////////////////////////////////
                        TRANSACTION
//////////////////////////////////////////////////////////////*/

async function sendOriginTokenToBridge() {
    try {
        const actualBridgeAddress = await destinationToken.getBridge();
        if (actualBridgeAddress != bridgeWallet.address) {
            const setBridgeTx = await destinationToken.setNewBridge(
                bridgeWallet.address,
            );
            await setBridgeTx.wait();
            console.log('✅ Dest bridge address set: ', bridgeWallet.address);
        }

        const txResponse = await originToken.transfer(
            bridgeWallet.address,
            ethers.parseEther('1'),
        );
        console.log('Tx sent:', txResponse.hash);

        const receipt = await txResponse.wait();
        console.log('Tx confirmed:', receipt.blockNumber);
    } catch (error) {
        console.error('Tx error:', error);
    }
}

sendOriginTokenToBridge();
