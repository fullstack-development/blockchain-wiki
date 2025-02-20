
lzCompose - нужно подключить [IOAppComposer](https://github.com/LayerZero-Labs/devtools/blob/05443835db976b7a528b883b19ddf02cb7f36d89/packages/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol)


## Особенности

### Native drop

Существует ценовой фид, который рассчитывает коэффициент конвертации между токеном источника газа и токеном назначения.

Если вы отправляете 1 ETH, вы понесете более высокие расходы в зависимости от ценового фида назначения. Он не предназначен для передачи больших объемов активов.

### Refund address

Для чего нужен `refundAddress`? Он необходим для возврата излишек оплаты. Но здесь важный момент, это возврат только в исходной сети, как правило там указывается инициатор транзакции. Что касается средств переданных в сеть назначения - здесь возврата не будет, поэтому нужно правильно рассчитать количество газа для передачи.

## Настройка Security stack

## Stargate

## Другие примеры

- Кейс Aragon с голосованием в арбитруме, а выполнением в эфире
- AAVE
- PancakeSwap
- Ethena и Balancer.

=================

### lzCompose

Поскольку каждый композитный вызов создается как отдельный пакет сообщений через lzCompose, этот паттерн может быть расширен на столько шагов, сколько нужно вашему приложению (B1 -> B2 -> B3 и т.д.).

### Options type

```solidity
    /**
     * @dev Adds an executor option to the existing options.
     * @param _options The existing options container.
     * @param _optionType The type of the executor option.
     * @param _option The encoded data for the executor option.
     * @return options The updated options container.
     */
    function addExecutorOption(
        bytes memory _options,
        uint8 _optionType,
        bytes memory _option
    ) internal pure onlyType3(_options) returns (bytes memory) {
        return
            abi.encodePacked(
                _options,
                ExecutorOptions.WORKER_ID,
                _option.length.toUint16() + 1, // +1 for optionType
                _optionType,
                _option
            );
    // opt.type | work.id | ex.opt.type.length | ex.opt.type | option
    // uint16   | uint8   | uint16             | uint8       | uint128
    // 0x0003   | 01      | 0011               | 01          | 0000000000000000000000000000c350
    // 3        | 1       | 17                 | 1           | 50000
    }
```

Опции сообщения - https://docs.layerzero.network/v2/developers/evm/protocol-gas-settings/options#options-builders

При установке enforcedOptions старайтесь не передавать дублирующий аргумент *options в extraOptions. Передача одинаковых *опций в enforcedOptions и extraOptions приведет к тому, что протокол будет дважды взимать плату с вызывающей стороны в цепочке источника, поскольку LayerZero интерпретирует дублирование \_опций как два отдельных запроса на газ.

---
