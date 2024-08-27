const { ethers } = require('ethers');
require('dotenv').config();

/*//////////////////////////////////////////////////////////////
                        GET CONSTANTS
//////////////////////////////////////////////////////////////*/

const originTokenAbi = require('../../artifacts/contracts/OriginToken.sol/OriginToken.json');
const tokenBridgeAbi = require('../../artifacts/contracts/ccip/TokenBridge.sol/TokenBridge.json');
const destinationTokenAbi = require('../../artifacts/contracts/DestinationToken.sol/DestinationToken.json');

const WALLET_PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY;

const DESTINATION_TOKEN_CONTRACT_ADDRESS =
    process.env.DESTINATION_TOKEN_CONTRACT_ADDRESS;

const ORIGIN_TOKEN_BRIDGE = process.env.ORIGIN_TOKEN_BRIDGE;
const DESTINATION_TOKEN_BRIDGE = process.env.DESTINATION_TOKEN_BRIDGE;
const LINK_ADDRESS = '0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904';

const SEPOLIA_PROVIDER_URL = process.env.SEPOLIA_PROVIDER_URL;
const AMOY_PROVIDER_URL = process.env.AMOY_PROVIDER_URL;

const ORIGIN_CHAIN_SELECTOR = '16015286601757825753';

if (!SEPOLIA_PROVIDER_URL && !AMOY_PROVIDER_URL) {
    console.error(new Error('Invalid provider url'));
    process.exit(1);
}

if (!WALLET_PRIVATE_KEY) {
    console.error(new Error('Invalid wallet key'));
    process.exit(1);
}

if (!originTokenAbi.abi && !destinationTokenAbi.abi && !tokenBridgeAbi) {
    throw new Error('ABI is undefined or not loaded correctly.');
}

/*//////////////////////////////////////////////////////////////
                        SETTINGS
//////////////////////////////////////////////////////////////*/

const rpcSepoliaProvider = new ethers.JsonRpcProvider(SEPOLIA_PROVIDER_URL);
const rpcAmoyProvider = new ethers.JsonRpcProvider(AMOY_PROVIDER_URL);

const walletSepolia = new ethers.Wallet(WALLET_PRIVATE_KEY, rpcSepoliaProvider);
const walletAmoy = new ethers.Wallet(WALLET_PRIVATE_KEY, rpcAmoyProvider);

const destinationToken = new ethers.Contract(
    DESTINATION_TOKEN_CONTRACT_ADDRESS,
    destinationTokenAbi.abi,
    walletAmoy,
);

const destinationBridge = new ethers.Contract(
    DESTINATION_TOKEN_BRIDGE,
    tokenBridgeAbi.abi,
    walletAmoy,
);

const link = new ethers.Contract(
    LINK_ADDRESS,
    destinationTokenAbi.abi,
    walletAmoy,
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
            console.log('✅ Dest bridge address set');
        }

        const destTokenAllowance = await destinationToken.allowance(
            walletAmoy.address,
            DESTINATION_TOKEN_BRIDGE,
        );

        if (destTokenAllowance < ethers.parseEther('1')) {
            const approveDestTokenTx = await destinationToken.approve(
                DESTINATION_TOKEN_BRIDGE,
                ethers.MaxUint256,
            );
            await approveDestTokenTx.wait();
            console.log('✅ Destination token approve success');
        }

        const linkAllowance = await link.allowance(
            walletAmoy.address,
            DESTINATION_TOKEN_BRIDGE,
        );
        if (linkAllowance < ethers.parseEther('1')) {
            const approveLinkTx = await link.approve(
                DESTINATION_TOKEN_BRIDGE,
                ethers.MaxUint256,
            );
            await approveLinkTx.wait();

            console.log('✅ Link token approve success');
        }

        const [data, message, fee] = await destinationBridge.prepareMessage(
            ORIGIN_CHAIN_SELECTOR,
            ORIGIN_TOKEN_BRIDGE,
            walletSepolia.address,
            ethers.parseEther('1'),
            1,
        );

        console.log('💵 Router fee: ', ethers.formatEther(fee));

        if (fee > ethers.parseEther('2')) {
            console.log('Too big fee 😒');
            return;
        }

        const sendTokensTx = await destinationBridge.sendToken(
            ORIGIN_CHAIN_SELECTOR,
            ORIGIN_TOKEN_BRIDGE,
            walletSepolia.address,
            walletAmoy.address,
            ethers.parseEther('1'),
            1,
        );
        const sendTokensReceipt = await sendTokensTx.wait();
        console.log('Tx hash:', sendTokensTx.hash);
        console.log('Tx confirmed in Polygon Amoy!');
        console.log(
            '🌈🌈🌈🌈🌈 The process of sending tokens is in progress ...',
        );
        console.log(
            '🔄🔄🔄🔄🔄 Go to https://ccip.chain.link/ and check tx hash. ',
        );

        if (sendTokensReceipt) {
            const destinationBalance = await destinationToken.balanceOf(
                walletAmoy.address,
            );
            console.log(
                `Polygon Amoy sender balance: ${ethers.formatEther(
                    destinationBalance,
                )} Tokens`,
            );
        }
    } catch (error) {
        console.error('Tx error:', error);
    }
}

sendOriginTokenToBridge();
