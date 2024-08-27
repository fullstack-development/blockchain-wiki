const { ethers } = require('ethers');
require('dotenv').config();

/*//////////////////////////////////////////////////////////////
                        GET CONSTANTS
//////////////////////////////////////////////////////////////*/

const originTokenAbi = require('../artifacts/contracts/OriginToken.sol/OriginToken.json');

const ORIGIN_TOKEN_CONTRACT_ADDRESS = process.env.ORIGIN_TOKEN_CONTRACT_ADDRESS;

const SEPOLIA_PROVIDER_URL = process.env.SEPOLIA_PROVIDER_URL;
const WALLET_PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY;

if (!SEPOLIA_PROVIDER_URL) {
    console.error(new Error('Invalid provider url'));
    process.exit(1);
}

if (!WALLET_PRIVATE_KEY) {
    console.error(new Error('Invalid wallet key'));
    process.exit(1);
}

if (!originTokenAbi.abi) {
    throw new Error('ABI is undefined or not loaded correctly.');
}

/*//////////////////////////////////////////////////////////////
                        SETTINGS
//////////////////////////////////////////////////////////////*/

const rpcSepoliaProvider = new ethers.JsonRpcProvider(SEPOLIA_PROVIDER_URL);

const walletSepolia = new ethers.Wallet(WALLET_PRIVATE_KEY, rpcSepoliaProvider);

const originToken = new ethers.Contract(
    ORIGIN_TOKEN_CONTRACT_ADDRESS,
    originTokenAbi.abi,
    walletSepolia,
);

/*//////////////////////////////////////////////////////////////
                        TRANSACTION
//////////////////////////////////////////////////////////////*/

async function mintOriginTokens() {
    try {
        const txResponse = await originToken.mint(walletSepolia.address);
        console.log('Tx sent:', txResponse.hash);

        const receipt = await txResponse.wait();

        if (receipt) {
            const originBalance = await originToken.balanceOf(
                walletSepolia.address,
            );
            console.log(
                `Sepolia sender balance: ${ethers.formatEther(
                    originBalance,
                )} Tokens`,
            );
        }
    } catch (error) {
        console.error('Tx error:', error);
    }
}

mintOriginTokens();
