# Смарт-контракты и взаимодействие с протоколом

**Автор:** [Роман Ярлыков](https://github.com/rlkvrv) 🧐

## Логика смарт-контрактов



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
        address _refundAddress // адрес на случай если 
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

Для чего нужен `refundAddress`? Он необходим для возврата излишек оплаты. Но здесь важный момент, это возврат только в исходной сети, как правило там указывается инициатор транзакции. Что касается средств переданных в сеть назначения - здесь возврата не будет, поэтому нужно правильно рассчитать количество газа для передачи.

За расчет газа необходимого для сети назначения и для оплаты комиссий отвечает функция `quote`

## Практические примеры

Лучший способ понять как работает протокол - попробовать его в деле. Я советую начать с примера в Remix, ссылки на необходимые смарт-контракты есть [в документации](https://docs.layerzero.network/v2/developers/evm/getting-started#example-omnichain-application). Это два очень простых смарт-контракта которые наследуются от *OAppSender* и *OAppReceiver*. Задача - переслать простое сообщение (строку) из одной сети в другую. Весь процесс хорошо описан, поэтому выполнение отправки сообщения не должно составить труда. Для большего погружения советую использовать другие блокчейны из [этого списка](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts).

Мы же перейдем к написанию кода. Самый простой способ быстро развернуть проект для LayerZero - это [создать](https://docs.layerzero.network/v2/developers/evm/create-lz-oapp/start) его через npm. Нужно выполнить следующую команду:

```bash
$ npx create-lz-oapp@latest
```

На выходе мы получаем проект который настроен как для работы с foundry так и с hardhat, помимо этого он будет иметь все необходимые зависимости для работы со смарт-контрактами LayerZero и для их тестирования.

*Примечание:* Этот способ имеет свои особенности, например на момент написания статьи необходимо использовать только NodeJS 18 версии и hardhat версии `2.22.3`. Информацию об этом вы найдете в документации или в дискорде когда будете получать различные ошибки, но к сожалению разворачивать проект с нуля будет сильно сложнее.

### Пример с простой передачей сообщения

Помимо зависимостей после развертывания проекта в папке contracts будет лежать смарт-контракт MyOApp.sol, который наследуется от [OApp](https://github.com/LayerZero-Labs/LayerZero-v2/blob/7aebbd7c79b2dc818f7bb054aed2405ca076b9d6/packages/layerzero-v2/evm/oapp/contracts/oapp/OApp.sol) и уже настроен на отправку и приемку пакетов, т.к. наследует [OAppSender](https://github.com/LayerZero-Labs/LayerZero-v2/blob/7aebbd7c79b2dc818f7bb054aed2405ca076b9d6/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppSender.sol) и [OAppReceiver](https://github.com/LayerZero-Labs/LayerZero-v2/blob/7aebbd7c79b2dc818f7bb054aed2405ca076b9d6/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppReceiver.sol).





======================


Кодирование сообщений Для кодирования сообщений используйте безопасный для типов кодек bytes. Используйте пользовательские кодеки только в случае необходимости и если ваше приложение требует глубокой оптимизации. Например, смотрите OFTMsgCodec.sol:

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
    // uint16 | uint8 | uint16 | uint8 | uint128
    // 0x0003 | 01 | 0011 | 01 | 0000000000000000000000000000c350
    //      3 |  1 |   17 |  1 |                            50000
    }
```
   Опции сообщения - https://docs.layerzero.network/v2/developers/evm/protocol-gas-settings/options#options-builders


   При установке enforcedOptions старайтесь не передавать дублирующий аргумент _options в extraOptions. Передача одинаковых _опций в enforcedOptions и extraOptions приведет к тому, что протокол будет дважды взимать плату с вызывающей стороны в цепочке источника, поскольку LayerZero интерпретирует дублирование _опций как два отдельных запроса на газ.

// TODO

### Собственный простой пример


1. Отправка сообщения
   1. деплой контрактов
   2. установка пиров
   3. Настройка опций сообщения (как понять сколько нужно газа)? Влияет ли это на стоимость? --> да, влияет, как считается? Короче мы сами считаем сколько газа потребуется и указываем в опциях, на основе этого значения layerzero считает сколько нативной валюты либо lzToken нужно отправить.
   Остатки газа не возвращаются?
   refundAddress?




   // TODO как комбинируются транзакции?
   Все равно вызывается lzReceive.


      1. Настройка типа сообщения
2. ABA (Сделать обычную отправку сообщения, а про ABA просто упомянуть.)
3. OFT
4. OFTAdapter?
5. Configurations

Посмотреть код DVN, вызывает ли он Executor? Кто вызывает Executor?

Native drop

Существует ценовой фид, который рассчитывает коэффициент конвертации между токеном источника газа и токеном назначения. 

Если вы отправляете 1 ETH, вы понесете более высокие расходы в зависимости от ценового фида назначения. Он не предназначен для передачи больших объемов активов.

// TODO

### ?? Stargate

// TODO Похоже не имеет отношения к LZ, но нужно проверить.

### Кейс с голосованием в арбитруме, а выполнением в эфире

// TODO Как Aragon использует LayerZero?
AAVE, PancakeSwap, Ethena и Balancer.
Ecosystem

### Настройка Security Stack

// TODO Может это уйдет в OApp config

## ?? Отличия от CCIP и Axelar

// TODO - Почему и как они используются в LZ?
