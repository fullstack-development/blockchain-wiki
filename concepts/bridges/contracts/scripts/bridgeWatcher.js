const { ethers } = require('ethers');
require('dotenv').config();

/*//////////////////////////////////////////////////////////////
                        GET CONSTANTS
//////////////////////////////////////////////////////////////*/

const originTokenAbi = require('../artifacts/contracts/OriginToken.sol/OriginToken.json');
const destinationTokenAbi = require('../artifacts/contracts/DestinationToken.sol/DestinationToken.json');

const BRIDGE_WALLET_PRIVATE_KEY = process.env.BRIDGE_WALLET_PRIVATE_KEY;

const ORIGIN_TOKEN_CONTRACT_ADDRESS = process.env.ORIGIN_TOKEN_CONTRACT_ADDRESS;
const DESTINATION_TOKEN_CONTRACT_ADDRESS =
    process.env.DESTINATION_TOKEN_CONTRACT_ADDRESS;

const SEPOLIA_PROVIDER_URL = process.env.SEPOLIA_PROVIDER_URL;
const AMOY_PROVIDER_URL = process.env.AMOY_PROVIDER_URL;

if (!SEPOLIA_PROVIDER_URL && !AMOY_PROVIDER_URL) {
    console.error(new Error('Invalid provider urls'));
    process.exit(1);
}

if (!BRIDGE_WALLET_PRIVATE_KEY) {
    console.error(new Error('Invalid bridge key'));
    process.exit(1);
}

if (!ORIGIN_TOKEN_CONTRACT_ADDRESS && !DESTINATION_TOKEN_CONTRACT_ADDRESS) {
    throw new Error('You need to set the addresses of the tokens!');
}

if (!originTokenAbi.abi && !destinationTokenAbi.abi) {
    throw new Error('ABI is undefined or not loaded correctly.');
}

/*//////////////////////////////////////////////////////////////
                        SETTINGS
//////////////////////////////////////////////////////////////*/

const rpcSepoliaProvider = new ethers.JsonRpcProvider(SEPOLIA_PROVIDER_URL);
const rpcAmoyProvider = new ethers.JsonRpcProvider(AMOY_PROVIDER_URL);

const bridgeSepolia = new ethers.Wallet(
    BRIDGE_WALLET_PRIVATE_KEY,
    rpcSepoliaProvider,
);

const bridgeAmoy = new ethers.Wallet(
    BRIDGE_WALLET_PRIVATE_KEY,
    rpcAmoyProvider,
);

/*//////////////////////////////////////////////////////////////
                        WATCHING
//////////////////////////////////////////////////////////////*/

console.log('Watching ...');

const originToken = new ethers.Contract(
    ORIGIN_TOKEN_CONTRACT_ADDRESS,
    originTokenAbi.abi,
    bridgeSepolia,
);

originToken.on('Transfer', (from, to, value, event) => {
    if (from == bridgeSepolia.address) {
        return;
    }
    if (to == bridgeSepolia.address && to != from) {
        console.log(
            '\n Tokens received on bridge from Sepolia chain! Time to bridge!',
        );

        try {
            mintTokens(from, value);
            console.log('✅✅✅✅✅ Tokens minted ...');
            console.log('🌈🌈🌈🌈🌈 Bridge to destination completed');
        } catch (err) {
            console.error('Error processing transaction', err);
        }
    } else {
        return;
    }
});

// ========================================================= //

const destinationToken = new ethers.Contract(
    DESTINATION_TOKEN_CONTRACT_ADDRESS,
    destinationTokenAbi.abi,
    bridgeAmoy,
);

destinationToken.on('Transfer', (from, to, value, event) => {
    if (from == bridgeAmoy.address) {
        return;
    }
    if (to == bridgeAmoy.address && to != from) {
        console.log(
            '\n Tokens received on bridge from Polygon Amoy chain! Time to bridge!',
        );

        try {
            burnTokens(from, to, value);
            console.log('🔥🔥🔥🔥🔥 Tokens burned ...');
            console.log('🌈🌈🌈🌈🌈 Bridge to origin completed');
        } catch (err) {
            console.error('Error processing transaction', err);
        }
    } else {
        return;
    }
});

/*//////////////////////////////////////////////////////////////
                        MAIN FUNCTIONS
//////////////////////////////////////////////////////////////*/

async function mintTokens(recipient, amount) {
    const mintTx = await destinationToken.mint(recipient, amount);
    const mintReceipt = await mintTx.wait();

    if (mintReceipt) {
        const originBalance = await originToken.balanceOf(recipient);
        console.log(
            `Sepolia sender balance: ${ethers.formatEther(
                originBalance,
            )} Tokens`,
        );

        const destinationBalance = await destinationToken.balanceOf(recipient);

        console.log(
            `Polygon Amoy recipient balance: ${ethers.formatEther(
                destinationBalance,
            )} Tokens`,
        );
    }
}

async function burnTokens(from, to, amount) {
    const approveTx = await destinationToken.approve(to, amount);
    const approveReceipt = await approveTx.wait();

    const burnTx = await destinationToken.burnFrom(to, amount);
    const burnReceipt = await burnTx.wait();

    if (approveReceipt && burnReceipt) {
        const destinationBalance = await destinationToken.balanceOf(from);

        console.log(
            `Polygon Amoy sender balance: ${ethers.formatEther(
                destinationBalance,
            )} Tokens`,
        );
    }

    const transferTx = await originToken.transfer(from, amount);
    const transferReceipt = await transferTx.wait();

    if (transferReceipt) {
        const originBalance = await originToken.balanceOf(from);

        console.log(
            `Sepolia recipient balance: ${ethers.formatEther(
                originBalance,
            )} Tokens`,
        );
    }
}
