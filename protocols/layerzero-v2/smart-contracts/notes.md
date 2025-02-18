Протокол LayerZero достаточно масштабный, поэтому верхнеуровневый обзор архитектуры вынесен в отдельную статью. Здесь углубимся в техническую составляющую львиную долю которой представляют смарт-контракты.

## Основные смарт-контракты


### Endpoint

### MessageLibBase

### DVN

### Executor

## Особенности

- Compose

### Native drop

Существует ценовой фид, который рассчитывает коэффициент конвертации между токеном источника газа и токеном назначения.

Если вы отправляете 1 ETH, вы понесете более высокие расходы в зависимости от ценового фида назначения. Он не предназначен для передачи больших объемов активов.

### Кодеки

Кодирование сообщений Для кодирования сообщений используйте безопасный для типов кодек bytes. Используйте пользовательские кодеки только в случае необходимости и если ваше приложение требует глубокой оптимизации. Например, смотрите OFTMsgCodec.sol:

### Refund address

Для чего нужен `refundAddress`? Он необходим для возврата излишек оплаты. Но здесь важный момент, это возврат только в исходной сети, как правило там указывается инициатор транзакции. Что касается средств переданных в сеть назначения - здесь возврата не будет, поэтому нужно правильно рассчитать количество газа для передачи.

## Практические примеры

**Пример отправки сообщения через Remix**

Лучший способ понять как работает протокол - попробовать его в деле. Я советую начать с примера в Remix, ссылки на необходимые смарт-контракты есть [в документации](https://docs.layerzero.network/v2/developers/evm/getting-started#example-omnichain-application). Это два очень простых смарт-контракта которые наследуются от _OAppSender_ и _OAppReceiver_. Задача - переслать простое сообщение (строку) из одной сети в другую. Весь процесс хорошо описан, поэтому выполнение отправки сообщения не должно составить труда. Для большего погружения советую использовать другие блокчейны из [этого списка](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts).

_Примечание:_ Если у вас есть немного ETH в Arbitrum и Pol в Polygon - можете использовать развернутые мной смарт-контракты, чтобы посмотреть как это работает в мейннете. Понадобится открыть ссылки выше в Remix, подключиться к смарт-контрактам адреса которых я дам чуть ниже и можно отправить простое текстовое сообщение. Работает только в одну сторону Arbiturm -> Polygon.

Пример транзакции - [layerzeroscan](https://layerzeroscan.com/tx/0x55615e9ee9be40614756fed61af5e5ad35b4e63cceefce4e3d49a6ccf0cf9f95).

Смарт-контракты:

- Arbitrum: 0x6b5ebc0bdb2572533f1cbe09026663a524421594
- Polygon: 0x0c02cb84eef5f3ea61be9dfec7f884dffc1fa6c0

**Пример, код** // TODO подправить заголовок

Мы же перейдем к написанию кода. Самый простой способ быстро развернуть проект для LayerZero - это [создать](https://docs.layerzero.network/v2/developers/evm/create-lz-oapp/start) его через npm. Нужно выполнить следующую команду:

```bash
$ npx create-lz-oapp@latest
```

На выходе мы получаем проект который настроен как для работы с foundry так и с hardhat, помимо этого он будет иметь все необходимые зависимости для работы со смарт-контрактами LayerZero и для их тестирования.

_Примечание:_ Этот способ имеет свои особенности, например на момент написания статьи необходимо использовать только NodeJS 18 версии и hardhat версии `2.22.3`. Информацию об этом вы найдете в документации или в дискорде когда будете получать различные ошибки, но к сожалению разворачивать проект с нуля будет сильно сложнее.

### Пример с простой передачей сообщения

Помимо зависимостей после развертывания проекта в папке contracts будет лежать смарт-контракт MyOApp.sol, который наследуется от [OApp](https://github.com/LayerZero-Labs/LayerZero-v2/blob/7aebbd7c79b2dc818f7bb054aed2405ca076b9d6/packages/layerzero-v2/evm/oapp/contracts/oapp/OApp.sol) и уже настроен на отправку и приемку пакетов, т.к. наследует [OAppSender](https://github.com/LayerZero-Labs/LayerZero-v2/blob/7aebbd7c79b2dc818f7bb054aed2405ca076b9d6/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppSender.sol) и [OAppReceiver](https://github.com/LayerZero-Labs/LayerZero-v2/blob/7aebbd7c79b2dc818f7bb054aed2405ca076b9d6/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppReceiver.sol).

## Настройка Security stack

## Stargate

## Другие примеры

- Кейс Aragon с голосованием в арбитруме, а выполнением в эфире
- AAVE
- PancakeSwap
- Ethena и Balancer.

=================

## Заметки

Для отправки понадобятся функция `send`, которая под капотом вызывает `_lzSend`:

```solidity
    function send(
        uint32 _dstEid, // идентификатор сети назначения
        string memory _message, // передаваемое сообщение
        bytes calldata _options // специфичные настройки для отправки данных
    ) external payable returns (MessagingReceipt memory receipt) {
        // приводим сообщение к формату bytes
        bytes memory _payload = abi.encode(_message);

        // передаем все в функцию _lzSend
        receipt = _lzSend(_dstEid, _payload, _options, MessagingFee(msg.value, 0), payable(msg.sender));
    }
```

Функция `_lzSend` принимает также информацию по оплате перевода и `refundAddress`:

```solidity
    function _lzSend(
        uint32 _dstEid, // идентификатор сети назначения
        bytes memory _message, // данные для отправки
        bytes memory _options, // специфичные настройки для отправки данных
        MessagingFee memory _fee, // плата за отправку и доставку сообщения
        address _refundAddress // адрес на случай если // TODO на случай чего?
    ) internal virtual returns (MessagingReceipt memory receipt) {
        // эти функции нужны для проверки достаточно ли передано средств на оплату
        // их можно переопределять, например когда выполняется batch send
        uint256 messageValue = _payNative(_fee.nativeFee);
        if (_fee.lzTokenFee > 0) _payLzToken(_fee.lzTokenFee);

        // вызывается endpoint для отправки сообщения
        return
            endpoint.send{ value: messageValue }(
                MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, _fee.lzTokenFee > 0),
                _refundAddress
            );
    }
```

======================

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
