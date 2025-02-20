import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, ContractFactory } from 'ethers'
import { deployments, ethers } from 'hardhat'

import { Options } from '@layerzerolabs/lz-v2-utilities'

describe('MetaLampOFTv1 Test', function () {
    // Constant representing a mock Endpoint ID for testing purposes
    const eidA = 1
    const eidB = 2
    // Declaration of variables to be used in the test suite
    let MetaLampOFTv1: ContractFactory
    let EndpointV2Mock: ContractFactory
    let ownerA: SignerWithAddress
    let ownerB: SignerWithAddress
    let endpointOwner: SignerWithAddress
    let metaLampOFTv1A: Contract
    let metaLampOFTv1B: Contract
    let mockEndpointV2A: Contract
    let mockEndpointV2B: Contract

    // Before hook for setup that runs once before all tests in the block
    before(async function () {
        // Contract factory for our tested contract
        //
        // We are using a derived contract that exposes a mint() function for testing purposes
        MetaLampOFTv1 = await ethers.getContractFactory('MetaLampOFTv1Mock')

        // Fetching the first three signers (accounts) from Hardhat's local Ethereum network
        const signers = await ethers.getSigners()

        ;[ownerA, ownerB, endpointOwner] = signers

        // The EndpointV2Mock contract comes from @layerzerolabs/test-devtools-evm-hardhat package
        // and its artifacts are connected as external artifacts to this project
        //
        // Unfortunately, hardhat itself does not yet provide a way of connecting external artifacts,
        // so we rely on hardhat-deploy to create a ContractFactory for EndpointV2Mock
        //
        // See https://github.com/NomicFoundation/hardhat/issues/1040
        const EndpointV2MockArtifact = await deployments.getArtifact('EndpointV2Mock')
        EndpointV2Mock = new ContractFactory(EndpointV2MockArtifact.abi, EndpointV2MockArtifact.bytecode, endpointOwner)
    })

    // beforeEach hook for setup that runs before each test in the block
    beforeEach(async function () {
        // Deploying a mock LZEndpoint with the given Endpoint ID
        mockEndpointV2A = await EndpointV2Mock.deploy(eidA)
        mockEndpointV2B = await EndpointV2Mock.deploy(eidB)

        // Deploying two instances of MetaLampOFTv1 contract with different identifiers and linking them to the mock LZEndpoint
        metaLampOFTv1A = await MetaLampOFTv1.deploy('aOFT', 'aOFT', mockEndpointV2A.address, ownerA.address)
        metaLampOFTv1B = await MetaLampOFTv1.deploy('bOFT', 'bOFT', mockEndpointV2B.address, ownerB.address)

        // Setting destination endpoints in the LZEndpoint mock for each MetaLampOFTv1 instance
        await mockEndpointV2A.setDestLzEndpoint(metaLampOFTv1B.address, mockEndpointV2B.address)
        await mockEndpointV2B.setDestLzEndpoint(metaLampOFTv1A.address, mockEndpointV2A.address)

        // Setting each MetaLampOFTv1 instance as a peer of the other in the mock LZEndpoint
        await metaLampOFTv1A.connect(ownerA).setPeer(eidB, ethers.utils.zeroPad(metaLampOFTv1B.address, 32))
        await metaLampOFTv1B.connect(ownerB).setPeer(eidA, ethers.utils.zeroPad(metaLampOFTv1A.address, 32))
    })

    // A test case to verify token transfer functionality
    it('should send a token from A address to B address via each OFT', async function () {
        // Minting an initial amount of tokens to ownerA's address in the MetaLampOFTv1A contract
        const initialAmount = ethers.utils.parseEther('100')
        await metaLampOFTv1A.mint(ownerA.address, initialAmount)

        // Defining the amount of tokens to send and constructing the parameters for the send operation
        const tokensToSend = ethers.utils.parseEther('1')

        // Defining extra message execution options for the send operation
        const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()

        const sendParam = [
            eidB,
            ethers.utils.zeroPad(ownerB.address, 32),
            tokensToSend,
            tokensToSend,
            options,
            '0x',
            '0x',
        ]

        // Fetching the native fee for the token send operation
        const [nativeFee] = await metaLampOFTv1A.quoteSend(sendParam, false)

        // Executing the send operation from MetaLampOFTv1A contract
        await metaLampOFTv1A.send(sendParam, [nativeFee, 0], ownerA.address, { value: nativeFee })

        // Fetching the final token balances of ownerA and ownerB
        const finalBalanceA = await metaLampOFTv1A.balanceOf(ownerA.address)
        const finalBalanceB = await metaLampOFTv1B.balanceOf(ownerB.address)

        // Asserting that the final balances are as expected after the send operation
        expect(finalBalanceA).eql(initialAmount.sub(tokensToSend))
        expect(finalBalanceB).eql(tokensToSend)
    })
})
