### Blockchain wiki

Привет!👋 Мы - команда [MetaLamp](https://www.metalamp.ru/) - с 2014 года мы воплощаем идеи клиентов в готовую продукцию. С 2020 года мы сосредоточились на проектах в сфере web3 и развиваем свой опыт, которым хотим поделиться с сообществом.🚀

У нас уже есть в открытом доступе [обучающая программа](https://github.com/fullstack-development/developers-roadmap) для **фронтенд/бэкенд** разработчиков, [web3 карта развития для не разработчиков](https://github.com/fullstack-development/web3-roadmap) и [карта развития](https://github.com/fullstack-development/blockchain-developers-roadmap) для **solidity** разработчика, которая включает перечень основных тем и вопросов, разбитых на уровни. Не изменяя традициям MetaLamp, мы делимся нашей базой знаний в области написания смарт-контрактов для EVM-совместимых блокчейнов.💡

Эта база знаний родилась в ходе решения реальных задач на проектах. Мы перенесли наш опыт в полноценную **Wiki**. Она отражает опыт всей команды разработчиков смарт-контрактов на языке Solidity.📚

Будем рады обратной связи, вкладу в развитие карты и любым видам партнерств. 🌱✨

Почта: hi@metalamp.io

Телеграм: [MetaLamp|Web3 DevTeam](https://t.me/metalampru)

<details open>
  <summary>Оглавление</summary>

  - [Algorithms and data structures](./algorithms/README.md)
  - <details open>
      <summary>Blockchains</summary>

      - [Bittensor](./blockchains/bittensor/bittensor.md)
      - [Polygon zkEVM](./blockchains/zk-evm-polygon/zk-evm-polygon.md)
      - <details>
          <summary>Scroll</summary>

          - [Protocol overview](./blockchains/scroll/scroll.md)
          - [Development Environment](./blockchains/scroll/scroll-dev-environment.md)
        </details>
      - <details>
          <summary>zkSync</summary>

          - [Protocol overview](./blockchains/zksync/zksync.md)
          - [Protocol architect](./blockchains/zksync/zksync-architect.md)
          - [Era Virtual Machine (zkEVM)](./blockchains/zksync/zksync-era-vm.md)
          - [Native Account Abstraction vs EIP-4337](./blockchains/zksync/zksync-aa.md)
          - [Development Environment](./blockchains/zksync/zksync-dev-environment.md)
        </details>
    </details>
  - <details>
      <summary>Concepts</summary>

      - [Auctions](./concepts/auctions/README.md)
      - [Bridges](./concepts/bridges/README.md)
      - [Commitment scheme](./concepts/commitment-scheme/README.md)
      - [Gnosis conditional token framework](./concepts/conditional-token-framework/README.md)
      - <details>
          <summary>DAO</summary>

          - [Overview](./concepts/dao/README.md)
          - [OpenZeppelin governance](./concepts/dao/openzeppelin-governance/README.md)
        </details>
      - [Digital Signatures on ethereum](./concepts/digital-signature-on-ethereum/README.md)
      - [ERC721C](./concepts/erc-721-c/README.md)
      - [Hash time locked contract (HTLC)](./concepts/hash-time-locked-contracts/README.md)
      - [Intent based protocols](./concepts/intent-based-protocols/README.md)
      - [keccak256](./concepts/keccak256/readme.md)
      - [Meta transactions](./concepts/meta-transactions/README.md)
      - [NFT staking](./concepts/nft-staking/README.md)
      - <details>
          <summary>Oracles</summary>

          - [Overview](./concepts/oracles/README.md)
          - [Uniswap TWAP vs oracle](./concepts/oracles/twap.md)
        </details>
      - [Safe Singleton Factory](./concepts/safe-singleton-factory/README.md)
      - <details>
          <summary>Upgradeable contracts</summary>

          - [Overview](./concepts/upgradeable-contracts/README.md)
          - [Contract migration](./concepts/upgradeable-contracts/method-1/readme.md)
          - [Data separation](./concepts/upgradeable-contracts/method-2/readme.md)
          - [Proxy pattern](./concepts/upgradeable-contracts/method-3/readme.md)
          - [Strategy pattern](./concepts//upgradeable-contracts/method-4/readme.md)
          - [Diamond pattern](./concepts/upgradeable-contracts/method-5/readme.md)
          - [Pendle routing way](./concepts/upgradeable-contracts/method-6/README.md)
        </details>
    </details>
  - <details>
      <summary>Cryptography</summary>

      - [Circom-and-snarkjs](./cryptography/circom-and-snarkjs/README.md)
      - [Zero-knowledge-proof](./cryptography/zero-knowledge-proof/README.md)
    </details>
  - <details>
      <summary>DeFi</summary>

      - <details>
          <summary>DEX</summary>

          - [Overview](./DeFi/dex/README.md)
          - [AMM](./DeFi/dex/amm/README.md)
          - [Order book](./DeFi/dex/orderbook/README.md)
          - [Underwater rocks](./DeFi/dex/underwater-rocks/README.md)
          - [DEXes review](./DeFi/dex/dex-review/README.md)
        </details>
      - [DEX aggregators](./DeFi/dex-aggregators/README.md)
      - <details>
          <summary>Lending</summary>

          - [Overview](./DeFi/lending/README.md)
          - [Compound v2](./protocols/compound-v2/README.md)
          - [Aave v2](./protocols/aave-v2/README.md)
          - [Flash loans](./protocols/aave-v2/flash-loans/README.md)
        </details>
      - [Margin trading](./DeFi/margin-trading/README.md)
      - [Stablecoin](./DeFi/stablecoin/README.md)
      - [Vesting](./DeFi/vesting/README.md)
    </details>
  - <details>
      <summary>EIPs</summary>

      - [EIP-140: REVERT instruction](./EIPs/eip-140/README.md)
      - [EIP-712: Typed structured data hashing and signing](./EIPs/eip-712/README.md)
      - [EIP-1014: Skinny CREATE2](./EIPs/eip-1014/README.md)
      - [EIP-1153: Transient storage opcodes](./EIPs/eip-1153/README.md)
      - [EIP-7702: Set Code for EOAs](./EIPs/eip-7702/README.md)
      - [ERC-165: Standard Interface Detection](./EIPs/erc-165/README.md)
      - [ERC-1271: Standard Signature Validation Method for Contracts](./EIPs/erc-1271/README.md)
      - [ERC-1363: Payable Token(transferAndCall)](./EIPs/erc-1363/README.md)
      - [ERC-2981: NFT Royalty Standard](./EIPs/erc-2981/README.md)
      - [ERC-3643: T-REX - Token for Regulated EXchanges](./EIPs/erc-3643/README.md)
      - [ERC-4337: Account Abstraction Using Alt Mempool](./EIPs/erc-4337/README.md)
      - [ERC-4626: Tokenized Vaults](./EIPs/erc-4626/README.md)
      - [ERC-6372: Contract clock](./EIPs/erc-6372/README.md)
      - [ERC-6900: Modular Smart Contract Accounts and Plugins](./EIPs/erc-6900/README.md)
      - [ERC-6909: Minimal Multi-Token Interface](./EIPs/erc-6909/README.md)
      - [ERC-7579: Minimal Modular Smart Accounts](./EIPs/erc-7579/README.md)
    </details>
  - <details>
      <summary>Ethereum virtual machine</summary>

      - [Intro](./ethereum-virtual-machine/intro/README.md)
      - [EVM Opcodes](./ethereum-virtual-machine/evm-opcodes/README.md)
      - <details>
          <summary>Gas</summary>

          - [Gas price](./ethereum-virtual-machine/gas/gas-price/README.md). О том, из чего складывается комиссия за транзакцию
          - [Gas used part 1: Overview](./ethereum-virtual-machine/gas/gas-used/gas-used-part-1.md). О том, как рассчитывается и используется газ во время транзакции
          - [Gas used part 2: Storage gas calculation](./ethereum-virtual-machine/gas/gas-used/gas-used-part-2.md). О том, как рассчитывается газ при чтении и записи в storage
        </details>
    </details>
  - <details>
      <summary>Guides</summary>

      - [EIP-7702. Создание смарт-контракта `Wallet.sol`](./guides/eip-7702/README.md)
      - [Uniswap-v2](./guides/uniswap-v2/README.md)
      - [Uniswap-v3](./guides/uniswap-v3/README.md)
      - [Uniswap v3/v4: как считать human-readable цену по tick и sqrtPriceX96](./guides/uniswap-v3-and-v4-price-guide/README.md)
    </details>
  - <details>
      <summary>Protocols</summary>

      - [Aave v2](./protocols/aave-v2/README.md)
      - [Aerodrome](./protocols/aerodrome/README.md)
      - [Algebra](./protocols/algebra/README.md)
      - [Aqua](./protocols/aqua/README.md)
      - [Aragon DAO v1](./protocols/aragon-dao-v1/README.md)
      - [Aragon DAO v2](./protocols/aragon-dao-v2/README.md)
      - [Compound v2](./protocols/compound-v2/README.md)
      - [Compound v3](./protocols/compound-v3/README.md)
      - <details>
          <summary>CoW DAO</summary>

        - [Overview](./protocols/cow-dao/README.md)
        - [Arbitrate auctions](./protocols/cow-dao/arbitrate-auctions/README.md)
        - [Mev blocker](./protocols/cow-dao/mev-blocker/README.md)
        </details>
      - [Curve](./protocols/curve/README.md)
      - [Eliza-Os-v2](./protocols/eliza-os-v2/README.md)
      - [LayerZero v2](./protocols/layerzero-v2/README.md)
      - [ONCHAINID (ERC-734/ERC-735)](./protocols/onchain-id/README.md)
      - [Pendle](./protocols/pendle/README.md)
      - [Polymarket](./protocols/polymarket/README.md)
      - [Reserve](./protocols/reserve/README.md)
      - [Uma. Optimistic oracle](./protocols/uma/README.md)
      - [Uniswap v4](./protocols/uniswap-v4/README.md)
      - [Uniswap X](./protocols/UniswapX/README.md)
    </details>
  - <details>
      <summary>Solidity</summary>

      - [ABI](./solidity/ABI/readme.md).
      - [Bitwise operators](./solidity/bitwise-operators/README.md)
      - [Event arguments indexing](./solidity/event-argument-indexing/README.md). Для чего параметры ```indexed``` и ```non-indexed``` в solidity событие
      - [Yul](./solidity/yul/README.md). Ассемблероподобный язык для работы с памятью из кода solidity
    </details>
  - <details>
      <summary>Tools</summary>

      - [Automation contracts](./tools/contract-automation/README.md)
      - [Brownie](./tools/brownie/README.md)
      - [Tenderly](./tools/tenderly/README.md)
      - [The graph](./tools/thegraph/README.md)
      - [Thirdweb](./tools/thirdweb/README.md)
    </details>
</details>


