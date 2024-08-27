const { ethers } = require('ethers');
require('dotenv').config();

/*//////////////////////////////////////////////////////////////
                        GET CONSTANTS
//////////////////////////////////////////////////////////////*/

const originTokenAbi = require('../../artifacts/contracts/OriginToken.sol/OriginToken.json');
const originBridgeAbi = require('../../artifacts/contracts/ccip/TokenBridge.sol/TokenBridge.json');
const destinationTokenAbi = require('../../artifacts/contracts/DestinationToken.sol/DestinationToken.json');

const WALLET_PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY;

const ORIGIN_TOKEN_CONTRACT_ADDRESS = process.env.ORIGIN_TOKEN_CONTRACT_ADDRESS;
const DESTINATION_TOKEN_CONTRACT_ADDRESS =
    process.env.DESTINATION_TOKEN_CONTRACT_ADDRESS;

const ORIGIN_TOKEN_BRIDGE = process.env.ORIGIN_TOKEN_BRIDGE;
const DESTINATION_TOKEN_BRIDGE = process.env.DESTINATION_TOKEN_BRIDGE;

const SEPOLIA_PROVIDER_URL = process.env.SEPOLIA_PROVIDER_URL;
const AMOY_PROVIDER_URL = process.env.AMOY_PROVIDER_URL;

const DESTINATION_CHAIN_SELECTOR = '16281711391670634445';

if (!SEPOLIA_PROVIDER_URL && !AMOY_PROVIDER_URL) {
    console.error(new Error('Invalid provider url'));
    process.exit(1);
}

if (!WALLET_PRIVATE_KEY) {
    console.error(new Error('Invalid wallet key'));
    process.exit(1);
}

if (!originTokenAbi.abi && !destinationTokenAbi.abi && !originBridgeAbi) {
    throw new Error('ABI is undefined or not loaded correctly.');
}

/*//////////////////////////////////////////////////////////////
                        SETTINGS
//////////////////////////////////////////////////////////////*/

const rpcSepoliaProvider = new ethers.JsonRpcProvider(SEPOLIA_PROVIDER_URL);
const rpcAmoyProvider = new ethers.JsonRpcProvider(AMOY_PROVIDER_URL);

const walletSepolia = new ethers.Wallet(WALLET_PRIVATE_KEY, rpcSepoliaProvider);
const walletAmoy = new ethers.Wallet(WALLET_PRIVATE_KEY, rpcAmoyProvider);

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

const originBridge = new ethers.Contract(
    ORIGIN_TOKEN_BRIDGE,
    originBridgeAbi.abi,
    walletSepolia,
);

/*//////////////////////////////////////////////////////////////
                        TRANSACTION
//////////////////////////////////////////////////////////////*/

async function sendOriginTokenToBridge() {
    try {
        const actualBridgeAddress = await destinationToken.getBridge();
        if (actualBridgeAddress != DESTINATION_TOKEN_BRIDGE) {
            const setBridgeTx = await destinationToken.setNewBridge(
                DESTINATION_TOKEN_BRIDGE,
            );
            await setBridgeTx.wait();
            console.log(
                '✅ Dest bridge address set: ',
                DESTINATION_TOKEN_BRIDGE,
            );
        }

        const approveTx = await originToken.approve(
            ORIGIN_TOKEN_BRIDGE,
            ethers.parseEther('1'),
        );
        const approveReceipt = await approveTx.wait();

        if (approveReceipt) {
            console.log('✅ Approve success');

            const [data, message, fee] = await originBridge.prepareMessage(
                DESTINATION_CHAIN_SELECTOR,
                DESTINATION_TOKEN_BRIDGE,
                walletAmoy.address,
                ethers.parseEther('1'),
                0,
            );

            console.log('💵 Router fee: ', ethers.formatEther(fee));

            if (fee > ethers.parseEther('0.1')) {
                console.log('Too big fee 😒');
                return;
            }

            const sendTokensTx = await originBridge.sendToken(
                DESTINATION_CHAIN_SELECTOR,
                DESTINATION_TOKEN_BRIDGE,
                walletAmoy.address,
                walletSepolia.address,
                ethers.parseEther('1'),
                0,
                { value: fee },
            );

            const sendTokensReceipt = await sendTokensTx.wait();
            console.log('Tx hash:', sendTokensTx.hash);
            console.log('Tx confirmed in Sepolia!');
            console.log(
                '🌈🌈🌈🌈🌈 The process of sending tokens is in progress ...',
            );
            console.log(
                '🔄🔄🔄🔄🔄 Go to https://ccip.chain.link/ and check tx hash. ',
            );

            if (sendTokensReceipt) {
                const originBalance = await originToken.balanceOf(
                    walletSepolia.address,
                );
                console.log(
                    `Sepolia sender balance: ${ethers.formatEther(
                        originBalance,
                    )} Tokens`,
                );
            }
        }
    } catch (error) {
        console.error('Tx error:', error);
    }
}

sendOriginTokenToBridge();
