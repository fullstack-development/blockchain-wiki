const { ethers } = require('ethers');
require('dotenv').config();

/*//////////////////////////////////////////////////////////////
                        GET CONSTANTS
//////////////////////////////////////////////////////////////*/

const destinationTokenAbi = require('../artifacts/contracts/DestinationToken.sol/DestinationToken.json');

const WALLET_PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY;
const BRIDGE_WALLET_PRIVATE_KEY = process.env.BRIDGE_WALLET_PRIVATE_KEY;

const DESTINATION_TOKEN_CONTRACT_ADDRESS =
    process.env.DESTINATION_TOKEN_CONTRACT_ADDRESS;

const AMOY_PROVIDER_URL = process.env.AMOY_PROVIDER_URL;

if (!AMOY_PROVIDER_URL) {
    console.error(new Error('Invalid provider url'));
    process.exit(1);
}

if (!WALLET_PRIVATE_KEY) {
    console.error(new Error('Invalid wallet key'));
    process.exit(1);
}

if (!destinationTokenAbi.abi) {
    throw new Error('ABI is undefined or not loaded correctly.');
}

/*//////////////////////////////////////////////////////////////
                        SETTINGS
//////////////////////////////////////////////////////////////*/

const rpcAmoyProvider = new ethers.JsonRpcProvider(AMOY_PROVIDER_URL);

const walletAmoy = new ethers.Wallet(WALLET_PRIVATE_KEY, rpcAmoyProvider);
const bridgeWallet = new ethers.Wallet(
    BRIDGE_WALLET_PRIVATE_KEY,
    rpcAmoyProvider,
);

const destinationToken = new ethers.Contract(
    DESTINATION_TOKEN_CONTRACT_ADDRESS,
    destinationTokenAbi.abi,
    walletAmoy,
);

/*//////////////////////////////////////////////////////////////
                        TRANSACTION
//////////////////////////////////////////////////////////////*/

async function sendDestinationTokenToBridge() {
    try {
        const txResponse = await destinationToken.transfer(
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

sendDestinationTokenToBridge();
