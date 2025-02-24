import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const amoy_testnetContract: OmniPointHardhat = {
    eid: EndpointId.AMOY_V2_TESTNET,
    contractName: 'MetaLampOFTv1',
}

const sepolia_testnetContract: OmniPointHardhat = {
    eid: EndpointId.SEPOLIA_V2_TESTNET,
    contractName: 'MetaLampOFTv1',
}

const config: OAppOmniGraphHardhat = {
    contracts: [{ contract: amoy_testnetContract }, { contract: sepolia_testnetContract }],
    connections: [
        {
            from: amoy_testnetContract,
            to: sepolia_testnetContract,
            config: {
                sendLibrary: '0x1d186C560281B8F1AF831957ED5047fD3AB902F9',
                receiveLibraryConfig: {
                    receiveLibrary: '0x53fd4C4fBBd53F6bC58CaE6704b92dB1f360A648',
                    gracePeriod: 0n,
                },
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10000,
                        executor: '0x4Cf1B3Fa61465c2c907f82fC488B43223BA0CF93',
                    },
                    ulnConfig: {
                        confirmations: 1n,
                        requiredDVNs: ['0x55c175DD5b039331dB251424538169D8495C18d1'],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0,
                    },
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: 2n,
                        requiredDVNs: ['0x55c175DD5b039331dB251424538169D8495C18d1'],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0,
                    },
                },
            },
        },
        {
            from: sepolia_testnetContract,
            to: amoy_testnetContract,
            config: {
                sendLibrary: '0xcc1ae8Cf5D3904Cef3360A9532B477529b177cCE',
                receiveLibraryConfig: {
                    receiveLibrary: '0xdAf00F5eE2158dD58E0d3857851c432E34A3A851',
                    gracePeriod: 0n,
                },
                sendConfig: {
                    executorConfig: {
                        maxMessageSize: 10000,
                        executor: '0x718B92b5CB0a5552039B593faF724D182A881eDA',
                    },
                    ulnConfig: {
                        confirmations: 2n,
                        requiredDVNs: ['0x8eebf8b423B73bFCa51a1Db4B7354AA0bFCA9193'],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0,
                    },
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: 1n,
                        requiredDVNs: ['0x8eebf8b423B73bFCa51a1Db4B7354AA0bFCA9193'],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0,
                    },
                },
            },
        },
    ],
}

export default config
