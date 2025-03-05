# Взаимодействие с протоколом LayerZero v2. OFT-токен  

**Автор:** [Роман Ярлыков](https://github.com/rlkvrv) 🧐  

В этой статье я покажу, как создавать и настраивать омничейн-приложения на базе LayerZero v2. В частности, мы напишем OFT (Omnichain Fungible Token) токен, разберем настройки такого приложения и обсудим возможные проблемы.  

Обзор верхнеуровневой архитектуры протокола и вайтпейпера я сделал в [отдельной](../architecture/README.md) статье (там же объясняется концепция омничейн-приложений). Здесь мы сфокусируемся на коде.  

*Примечание:* у LayerZero хорошая документация, поэтому, чтобы не повторяться, я буду иногда отсылать читателя к ней. В этой статье рассмотрим основные и не самые очевидные моменты.  

Задача статьи — познакомить вас с ключевыми контрактами и написать свой OApp, чтобы прочувствовать все особенности работы с LayerZero и понять, на что стоит обращать внимание.  

Статья подойдет тем, кто хочет разобраться с OFT-токенами и, возможно, создать свой. Во втором случае я рекомендую выполнять практические задания из статьи — в конце концов, это просто весело.  

Терминология:
- **Исходная сеть** - блокчейн, отправляющий данные в другую сеть.  
- **Сеть назначения** - блокчейн, принимающий данные из исходной сети.
- **OApp** - Omnichain Application.
- **OFT** -  Omnichain Fungible Token.
- **EID** - Endpoint ID.

## Создание простого OApp

Чтобы не заскучать, сразу перейдем к практике и отправим сообщение между OApp-приложениями, развернутыми в двух блокчейнах (для простоты будем использовать EVM-совместимые сети). Это поможет разобраться в базовых принципах работы омничейн-приложений и почувствовать все на практике. После этого сложные вещи будут даваться легче, а в голове сформируются правильные вопросы.  

В [документации](https://docs.layerzero.network/v2/developers/evm/getting-started#example-omnichain-application) предлагается развернуть два смарт-контракта: `SourceOApp` и `DestinationOApp`, которые отправляют сообщения между блокчейнами, используя Remix (см. раздел *Example Omnichain Application*). Эти контракты уже написаны — остается только их задеплоить и настроить.  

Это два очень простых смарт-контракта. `Source` наследуется от [OAppSender](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oapp-evm/contracts/oapp/OAppSender.sol), а `Destination` от [OAppReceiver](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oapp-evm/contracts/oapp/OAppReceiver.sol).  

Наша задача — переслать простое сообщение (строку) из одного блокчейна в другой.

Что нам понадобится? На самом деле, не так много:  

1. Два OApp-приложения, задеплоенные в разных блокчейнах.  
2. Адреса `Endpoint` в обеих сетях, а также их `EID` (Endpoint ID). Их можно найти в [этой таблице](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts).  

![contract-address-table](./img/contract-address-table.png)  
*Таблица с адресами основных контрактов и `EID`. Источник: LayerZero Chains.*  

### Source OApp  

Посмотрите на код `SourceOApp` (в Remix) — он довольно простой. Нас интересуют две функции:  

- `SourceOApp::quote` — позволяет рассчитать, сколько нативных токенов нужно передать в сеть назначения, чтобы хватило на выполнение транзакции и проверок в стеке безопасности. Параметр `_payInLzToken` устанавливается, если оплата будет производиться *не* в нативном токене сети.  

```solidity
function quote(
    uint32 _dstEid,
    string memory _message,
    bool _payInLzToken
) public view returns (MessagingFee memory fee) {
    bytes memory payload = abi.encode(_message);
    fee = _quote(_dstEid, payload, _options, _payInLzToken);
}
```

- `SourceOApp::send` — отправляет сообщение и передает нативные токены для оплаты газа в сети назначения.  

```solidity
function send(
    uint32 _dstEid,
    string memory _message
) external payable {
    // Кодируем сообщение перед вызовом _lzSend.
    bytes memory _encodedMessage = abi.encode(_message);
    _lzSend(
        _dstEid,
        _encodedMessage,
        _options,
        // Комиссия в нативном токене (или токене ZRO).
        MessagingFee(msg.value, 0),
        // Адрес отправителя в исходной сети (на случай возврата комиссии).
        payable(msg.sender) 
    );
    emit MessageSent(_message, _dstEid);
}
```

### Базовая настройка OApp  

Адрес `Endpoint` задается при деплое контракта. После развертывания нужно вызвать `SourceOApp::setPeer(uint32 eid, bytes32 peer)` в обоих контрактах (в исходной сети и в сети назначения).  

На самом деле, это функция контракта `OAppCore`, которая связывает приложения между собой.  

*Важно!* `SourceOApp::setPeer` принимает адрес в формате `bytes32`. Это сделано намеренно, так как форматы адресов в разных блокчейнах могут различаться (например, в EVM это 20 байт, а в Solana — 32 байта).  

![remix-set-peer](./img/remix-set-peer.png)  

Чтобы перевести EVM-адрес в `bytes32`, можно воспользоваться следующей функцией:  

```solidity
function addressToBytes32(address _addr) public pure returns (bytes32) {
    return bytes32(uint256(uint160(_addr)));
}
```

После выполнения транзакции можно проверить, что `peer` установлен верно.  

![remix-get-peer](./img/remix-get-peer.png)  

*Примечание:* `EID` необходим, потому что не у всех блокчейнов есть `chain ID`.  

### Destination OApp  

В OApp-сети назначения нас интересует одна ключевая функция — `_lzReceive`. Она переопределяется так, чтобы обрабатывать определенные типы сообщений. В нашем случае это обычная строка.  

```solidity
function _lzReceive(
    Origin calldata _origin,
    bytes32 /*_guid*/,
    bytes calldata message,
    address /*executor*/,  // Адрес исполнителя, указанный для OApp.
    bytes calldata /*_extraData*/  // Любые дополнительные данные или опции.
) internal override {
    // Декодируем полезную нагрузку, чтобы получить сообщение.
    data = abi.decode(message, (string));
    emit MessageReceived(data, _origin.srcEid, _origin.sender, _origin.nonce);
}
```

### Практическая часть  

Теперь выполним все шаги из документации по развертыванию приложений и отправке сообщения. Для большего погружения рекомендую использовать другие блокчейны из [этого списка](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts) вместо тех, что предложены в документации.  

*Примечание:* копируйте адреса контрактов сразу после деплоя. В Remix, если переключиться на другую сеть, развернутые контракты сбрасываются (даже если вкладка остается открытой).  

Напомню: чтобы в Remix получить доступ к функциям уже развернутого контракта, выберите этот контракт во вкладке **Contract** и вставьте его адрес в **At Address**.  

![remix-at-address](./img/remix-at-address.png)  

Порядок действий:
1. Выбираем два блокчейна. Проверяем, что у нас достаточно нативных токенов для оплаты газа.  
2. Переходим в документацию LayerZero → [Chains](https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts) и находим адреса `Endpoint` и соответствующие `EID`. Сохраняем их — они понадобятся дальше.  
3. Деплоим контракт `SourceOApp` в **исходную сеть**. Для этого потребуется адрес `Endpoint` в этой сети.  
4. Деплоим контракт `DestinationOApp` в **сеть назначения**, также используя соответствующий `Endpoint`. Сохраняем адрес.  
5. Переключаемся обратно на исходную сеть, переводим адреса в формат `bytes32`. Для этого вызываем `Source::addressToBytes32` (как для OApp в исходной сети, так и для OApp в сети назначения).  
6. Связываем OApps через `setPeer`, выполнив две транзакции:  
   - `Source::setPeer(uint32 eid, bytes32 peer)`  
   - `Destination::setPeer(uint32 eid, bytes32 peer)`  
7. Рассчитываем, сколько нативных токенов потребуется для оплаты газа в сети назначения. Для этого используем `Source::quote(uint32 dstEid, string message, bool payLzToken)`. Параметр `payLzToken` можно указать `false`.  
   
   ![remix-quote](./img/remix-quote.png)  

8. Вставляем рассчитанный `fee` (количество Wei) в поле **Value** в Remix и отправляем сообщение через `Source::send(uint32 dstEid, string message)`.  
   
   ![remix-value](./img/remix-value.png)  
   ![remix-send](./img/remix-send.png)  

9. Проверяем транзакцию на [testnet.layerzeroscan.com](https://testnet.layerzeroscan.com/). Ищем по хешу транзакции (его можно взять в логах Remix).  
   
   ![remix-tx-hash](./img/remix-tx-hash.png)  
   ![layerzero-scan-tx](./img/layerzero-scan-tx.png)  

10. Если все прошло успешно (статус **Delivered**), в сети назначения можно проверить полученное сообщение через `Destination::data`.  
   
    ![remix-data](./img/remix-data.png)  

*Примечание:* если у вас есть немного ETH в **Arbitrum** и POL в **Polygon**, можно воспользоваться развернутыми мной смарт-контрактами и проверить, как это работает в мейннете. Это обойдется всего в несколько центов, но иногда проще заплатить, чем искать тестовые токены.  

Для этого:  

- Откройте Remix.  
- Подключитесь к контрактам по указанным ниже адресам (через **At Address**).  
- Отправьте текстовое сообщение.  

**Важно:** работает только в одном направлении - **Arbitrum → Polygon**.  

Смарт-контракты:
- **Arbitrum:**  
  - `SourceOApp`: `0x6b5ebc0bdb2572533f1cbe09026663a524421594`  
  - `EID`: `30110`  
- **Polygon:**  
  - `DestinationOApp`: `0x0c02cb84eef5f3ea61be9dfec7f884dffc1fa6c0`  
  - `EID`: `30109`  

Примеры транзакций:  
- [Пример 1](https://layerzeroscan.com/tx/0x55615e9ee9be40614756fed61af5e5ad35b4e63cceefce4e3d49a6ccf0cf9f95)  
- [Пример 2](https://layerzeroscan.com/tx/0x9124aa03fefd50d7d2345c941e7e9e26c41d1b98023326548ce5346c0fa22257)  

Когда работаешь в мейннете, волей-неволей начинаешь все делать внимательнее и глубже вникаешь в детали. Хотя даже это не спасает от ошибок 😁. Я, например, несколько раз накосячил — указывал неверный `EID` и забывал отправить нативные токены. Так что рекомендую попробовать!  

## OFT-токен  

В предыдущем разделе мы создали базовое омничейн-приложение. Теперь можно задеплоить `DestinationOApp` в любой другой блокчейн (включая не-EVM сети), добавить новый `peer` в `SourceOApp` и отправлять туда сообщения.  

Минус этого приложения в том, что оно работает в одном направлении. Лучше делать такие решения универсальными, чтобы они могли и отправлять, и принимать сообщения. OApp-приложения могут содержать любую логику и обмениваться произвольными данными.  

Один из самых интересных кейсов использования — **OFT-токен**. Протокол LayerZero уже продумал, как создать такой токен с использованием их платформы, и разработал стандарт **OFT**. Это ERC20-токен, который может существовать в любом количестве блокчейнов. Чтобы поддержать новый блокчейн, достаточно развернуть в нем новое приложение и привязать его к остальным.  

Возникает логичный вопрос: чем это отличается от обычного моста? Я уже отвечал на него в обзорной статье, но если коротко — главное отличие в универсальных интерфейсах и возможности обеспечить действительно высокий уровень безопасности передачи токенов.  

### Пример USDT0  

Пример реального OFT-токена — [USDT0](https://usdt0.to/). Это хорошо знакомый всем Tether USD (USDT), который переводит свой токен на **OFT-рельсы**. Возможно, когда вы читаете эту статью, токен USDT уже мигрирован на USDT0 во всех сетях, кроме Ethereum. На данный момент он доступен только в нескольких блокчейнах.  

В случае с USDT0 использовали **OFTAdapter** — механизм, который блокирует/разблокирует исходный токен в базовой сети, а во всех остальных блокчейнах — минтит/сжигает. OFTAdapter необходим, если у вас уже есть обычный ERC20-токен, но вы хотите превратить его в OFT.  

![usdt0](./img/usdt0.png)  
*Источник: документация USDT0*  

К сожалению, у проекта нет публичного GitHub-репозитория, но все смарт-контракты верифицированы, и код можно посмотреть в блокчейн-эксплорерах (ссылки [здесь](https://docs.usdt0.to/technical-documentation/developer#id-3.-deployments)). Также есть интересные отчеты по аудиту USDT0 — рекомендую ознакомиться с ними [тут](https://github.com/Everdawn-Labs/usdt0-audit-reports). В них много полезной информации.  

## Что нужно для создания OFT-токена?  

Самый быстрый способ развернуть OFT-токен для LayerZero — [создать](https://docs.layerzero.network/v2/developers/evm/oft/quickstart) проект на своей машине через npm. Для этого выполняем команду:  

```bash
npx create-lz-oapp@latest
```  

Затем выбираем **OFT**.  

![create-lz-oapp](./img/create-lz-oapp.png)  

После выбора пакетного менеджера мы получим готовый проект с OFT-токеном. Причем он **из коробки** поддерживает как Hardhat, так и Foundry, что особенно удобно. Останется только изменить нейминг, задеплоить контракты и настроить их взаимодействие в разных сетях. В проекте уже есть все необходимое для деплоя, тестирования, а также скрипты для оценки газа.  

## Структура OFT-токена  

Базовая структура OFT выглядит так:  

![oapp-inherits-docs](./img/oapp-inherits-docs.png)  
*Источник: документация LayerZero*  

Но если посмотреть на OFT-токен более детально, он включает в себя чуть больше зависимостей. Для примера я написал токен [MetaLampOFTv1](./contracts/contracts/MetaLampOFTv1.sol). Читать схему **снизу вверх**.  

![oapp-inherits](./img/oapp-inherits.png)  
*Схема наследования OFT-токена*  

Здесь можно увидеть два дополнительных смарт-контракта — [OAppPreCrimeSimulator](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oapp-evm/contracts/precrime/OAppPreCrimeSimulator.sol) и [OAppOptionsType3](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol), о которых мы поговорим чуть позже. Также видно, что [OApp](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oapp-evm/contracts/oapp/OApp.sol) наследуется от [OAppCore](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oapp-evm/contracts/oapp/OAppCore.sol) и может как отправлять, так и получать сообщения через [OAppSender](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oapp-evm/contracts/oapp/OAppSender.sol) и [OAppReceiver](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oapp-evm/contracts/oapp/OAppReceiver.sol).  

*Примечание:* если вы не хотите разворачивать проект, готовый код можно посмотреть [здесь](./contracts/contracts/MetaLampOFTv1.sol). Для этого установите зависимости через `pnpm install` в папке `protocols/layerzero-v2/smart-contracts/contracts`.  

Также можно заглянуть в репозиторий [LayerZero-Labs/devtools](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oft-evm/contracts) — там есть все примеры.

## Базовый функционал OFT  

Так выглядит самый простой **ERC20 OFT-токен**:  

```solidity
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";

contract MetaLampOFTv1 is OFT {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_delegate) {}
}
```

- Параметры `_name` и `_symbol` передаются при деплое, так как для каждой новой сети потребуется развернуть отдельный экземпляр токена (OApp).  
- `_lzEndpoint` — это адрес Endpoint для взаимодействия с LayerZero.  
- `_delegate` — адрес владельца токена, который также отвечает за изменение настроек OApp.  

В смарт-контракт токена можно добавить любую дополнительную логику или зависимости (например, **Permit**). Но все, что касается механики OFT, уже реализовано в контракте `OFT`.  

Основные функции, которые нас интересуют в **OFT**, — `_debit` и `_credit`. Они реализуют базовую механику **mint/burn**, но их можно переопределить в основном контракте токена.  

### Отправка токенов из исходной сети (`send`)  

Главная функция для отправки токенов — [`OFTCore::send`](https://github.com/LayerZero-Labs/devtools/blob/05443835db976b7a528b883b19ddf02cb7f36d89/packages/oft-evm/contracts/OFTCore.sol#L175). Если помните, в примере с Remix у нас уже была похожая функция, но теперь она стала сложнее:  

```solidity
function send(
    SendParam calldata _sendParam, // Основные параметры для отправки сообщения
    MessagingFee calldata _fee, // Комиссия на оплату газа и стека безопасности
    address _refundAddress // Адрес возврата комиссии в исходной сети
) external payable virtual returns (
    MessagingReceipt memory msgReceipt, // Основной чек по транзакции
    OFTReceipt memory oftReceipt // Доп информация специфичная для OFT
) { ... }
```

Параметры, которые необходимо указать для отправки: 

```solidity
struct SendParam {
    uint32 dstEid; // Endpoint ID сети назначения.
    bytes32 to; // Адрес OApp в сети назначения.
    uint256 amountLD; // Количество токенов в локальных decimals.
    uint256 minAmountLD; // Минимальное количество токенов в локальных decimals.
    bytes extraOptions; // Опции, предоставленные вызывающей стороной.
    bytes composeMsg; // Сообщение для операции send().
    bytes oftCmd; // Команда OFT, не используется в стандартных реализациях.
}
```

Так выглядит MessagingReceipt:

```solidity
struct MessagingReceipt {
    bytes32 guid; // GUID для ончейн и оффчейн отслеживания сообщения.
    uint64 nonce; // Уникальный nonce для управления сообщением в канале.
    MessagingFee fee; // Комиссия на газ и оплату стека безопасности
}
```

#### Как работает `send`  

Если не углубляться в детали, функция `send` выполняет три ключевых шага:  

1. **Вызывает `_debit`** — сжигает токены или выполняет другую логику при отправке в сеть назначения (пока можно не обращать внимания на LD и SD amounts).  
2. **Формирует сообщение** через `_buildMsgAndOptions` — добавляет специфичные данные для OFT и настраивает параметры.  
3. **Отправляет сообщение** через `_lzSend` — это первый вызов базовой функции **OApp**. Все предыдущие шаги были лишь подготовкой. `_lzSend` передает сообщение через Endpoint и переводит ему средства для покрытия комиссии.  

Во время выполнения `send` вызываются и другие вспомогательные функции. Все `internal`-методы в контракте имеют модификатор `virtual`, поэтому их можно переопределять в своем OFT-токене.  

![oft-core-send-diagram](./img/oft-core-send-diagram.png)  
*Граф вызовов функции `OFTCore::send`*  

Я условно разделил поток выполнения на три основные ветки — так проще разобрать по шагам, как работает эта функция.

##### Local Decimals и Shared Decimals  

Теперь разберем отдельные аспекты отправки токенов, начиная с служебных функций `_debitView` и `_removeDust`, а также таких понятий, как **Local Decimals (LD)** и **Shared Decimals (SD)**. То есть посмотрим, что происходит в **ветке 1**.  

![oft-core-send-branch-1](./img/oft-core-send-branch-1.png)  
*Сжигание токенов и дополнительные расчеты для корректного отображения `amount`*  

Зачем нужны LD и SD? Чтобы обеспечить максимальную совместимость между разными блокчейнами (включая не-EVM сети) и при этом не потерять точность, для передачи токенов в LayerZero используется `uint64` и `decimals = 6`.  

Это значит, что максимальный `totalSupply` может быть 18,446,744,073,709.551615.  

Функцию `OFTCore::sharedDecimals` можно переопределить, уменьшив количество знаков после запятой. Например, если уменьшить `sharedDecimals` до 4, максимальное число возрастет до 1,844,674,407,370,955.1615, но точность снизится.  

Увеличивать `sharedDecimals` не рекомендуется — команда LayerZero протестировала такой формат и считает, что его точности достаточно для всех существующих блокчейнов.  

Как это работает? Есть два ключевых этапа:  

1. **Удаление "пыли"** — чтобы точно знать, сколько токенов будет отправлено.  
2. **Конвертация** между `local decimals` (используется в сети отправителя и получателя) и `shared decimals` (используется только при передаче).  

Для этого используется переменная `decimalConversionRate`, которая устанавливается в конструкторе:  

```solidity
decimalConversionRate = 10 ** (_localDecimals - sharedDecimals());
```

**Пример:**  

Допустим, в EVM-блокчейнах чаще всего `decimals = 18`, тогда:  
```solidity
decimalConversionRate = 10 ** (18 - 6) = 1,000,000,000,000
```

Если мы хотим перевести **1 токен**, то он в `decimals = 18` будет выглядеть как `1,123,123,123,123,123,123`.  

1. Удаление "пыли" (`_removeDust`). Функция `_removeDust` округляет значение вниз, удаляя "пыль":  

    ```solidity
    function _removeDust(uint256 _amountLD) internal view virtual returns (uint256 amountLD) {
        return (_amountLD / decimalConversionRate) * decimalConversionRate;
    }
    ```

    **До:** `1,123,123,123,123,123,123` (1.123123123123123123)  
    **После:** `1,123,123,000,000,000,000` (1.123123000000000000)  

2. Конвертация в SD (`_toSD`). Для передачи в сеть назначения выполняется конвертация в **shared decimals**:  

    ```solidity
    function _toSD(uint256 _amountLD) internal view virtual returns (uint64 amountSD) {
        return uint64(_amountLD / decimalConversionRate);
    }
    ```

    Мы обрезаем 12 знаков, получая `1,123,123` (1.123123).  

3. Обратная конвертация (`_toLD`). В сети назначения выполняется обратная конвертация:  

    ```solidity
    function _toLD(uint64 _amountSD) internal view virtual returns (uint256 amountLD) {
        return _amountSD * decimalConversionRate;
    }
    ```

    Если в сети назначения `decimals = 18`, мы снова получим 1.123123000000000000.  

Можете для примера взять ETH по текущим ценам и посчитать какие могут быть потери из-за такой точности. Я посчитал и это действительно "пыль".

Помимо `_removeDust`, функция `_debitView` выполняет дополнительную проверку на "проскальзывание", если при отправке взимаются дополнительные комиссии.  

Мы разобрали всю **ветку 1**. С функцией `ERC20::_burn` думаю все и так понятно.

#### Формирование сообщения и опций для его отправки  

Теперь разберем **ветку 2** — функцию `_buildMsgAndOptions`. Ее можно логически разделить на три этапа:  

1. Кодировка сообщения
2. Формирование опций
3. Проверка через инспектор (опционально)

![oft-core-send-branch-2](./img/oft-core-send-branch-2.png)  
*Формирование сообщения и опций для отправки*  

**Шаг 1:** Кодировка выполняется с помощью библиотеки [`OFTMsgCodec`](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oft-evm/contracts/libs/OFTMsgCodec.sol). Ее основная задача — корректно упаковать байты информации для передачи.  

```solidity
function _buildMsgAndOptions(
    SendParam calldata _sendParam, // Параметры отправки
    uint256 _amountLD // Количество токенов с local decimals
) internal view virtual returns (bytes memory message, bytes memory options) {
    // 1. Кодировка сообщения
    bool hasCompose;
    (message, hasCompose) = OFTMsgCodec.encode(
        _sendParam.to,
        _toSD(_amountLD),
        _sendParam.composeMsg
    );

    // 2. Формирование опций
    uint16 msgType = hasCompose ? SEND_AND_CALL : SEND;
    options = combineOptions(_sendParam.dstEid, msgType, _sendParam.extraOptions);

    // 3. Опциональная проверка через инспектор
    address inspector = msgInspector;
    if (inspector != address(0)) IOAppMsgInspector(inspector).inspect(message, options);
}
```

**Шаг 2:** Формирование опций. Из чего состоят опции мы рассмотрим чуть позже. Здесь рассмотрим как они объединяются через [`combineOptions`](https://github.com/LayerZero-Labs/devtools/blob/05443835db976b7a528b883b19ddf02cb7f36d89/packages/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol#L63).

Дело в том, что смарт-контакт `OAppOptionsType3` позволяет задавать предустановленные "принудительные" опции (`enforcedOptions`). Такие опции задает владелец OApp, например, если он точно знает, что в конкретном блокчейне нужно увеличить `gasLimit` или добавить обязательный *native drop* (об этом тоже позже).  

Для того чтобы можно было разграничить обычные сообщения и комбинированые (composed), в OFT добавлены два типа сообщений, в зависимости от типа можно устанавливать разные `enforcedOptions`:  
- **1 - `SEND`** — обычная отправка сообщения (включая перевод токенов);
- **2 - `SEND_AND_CALL`** — используется для `compose`-сообщений (отправка + вызов функции в сети назначения). 

**Пример**

Допустим, мы отправляем сообщение, как в примере с Remix, если вы вернетесь к контракту `Source` в нем заданы такие дефолтные опции:  

```solidity
bytes _options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(50000, 0);
```

Это значит `{ gasLimit: 50000, value: 0 }`. Теперь представим, что в сети назначения необходимо удвоить лимит газа в два раза + добавить 0.5 ETH native drop. Тогда владелец OApp задает `enforcedOptions`:  

```solidity
{ gasLimit: 100000, value: 0.5 ETH }
```

Финальный результат объединения:  

```solidity
{ gasLimit: 150000, value: 0.5 ETH }
```

Функция `combineOptions` объединяет опции следующим образом:  

```solidity
function combineOptions(
    uint32 _eid,
    uint16 _msgType,
    bytes calldata _extraOptions
) public view virtual returns (bytes memory) {
    bytes memory enforced = enforcedOptions[_eid][_msgType];

    if (enforced.length == 0) return _extraOptions;
    if (_extraOptions.length == 0) return enforced;

    if (_extraOptions.length >= 2) {
        _assertOptionsType3(_extraOptions);
        return bytes.concat(enforced, _extraOptions[2:]);
    }

    revert InvalidOptions(_extraOptions);
}
```

На схеме это будет выглядеть так:

![combine-options](./img/combine-options.png)  
*Выбор опций и их объединение*  

- Если `enforcedOptions` отсутствуют → используются `extraOptions`.  
- Если `extraOptions` отсутствуют → используются `enforcedOptions`.  
- Если заданы оба → `extraOptions` должны быть валидными, чтобы корректно объединиться.  

**Шаг 3:** Проверка через инспектор (опционально). Если в OApp задан адрес контракта `msgInspector`, то перед отправкой сообщения он проверяет параметры `message` и `options`.  

Это позволяет программно задать дополнительные проверки перед передачей данных в другой блокчейн.  

Мы разобрали **ветку 2** — процесс кодировки и формирования опций для отправки.

#### Отправка сообщения  

Наконец, добрались до **третьей ветки** выполнения функции `send`, которая отвечает за непосредственную отправку сообщения через Endpoint.  

![oft-core-send-branch-3](./img/oft-core-send-branch-3.png)  
*Схема вызовов для отправки сообщения*  

Вызывается внутренняя функция `OAppSender::_lzSend`, которая выполняет три ключевых действия:  

1. Вызывает `_payNative`, чтобы проверить, хватает ли `msg.value` для оплаты `gasLimit` в сети назначения, либо переводит токены на Endpoint через `safeTransferFrom`, если выбрана опция оплаты через `_lzPayToken`.  
2. Проверяет, существует ли `peer`, которому отправляется сообщение (`getPeerOrRevert`).  
3. Вызывает `Endpoint.send{ value: nativeFee }()`, отправляя сообщение в стек безопасности.  

После этого сообщение передается в Endpoint, который отвечает за его дальнейшую обработку, а также оплату услуг DVNs и Executor.  

### Получение сообщения в сети назначения  

Получение сообщения происходит через базовую функцию [`OAppReceiver::lzReceive`](https://github.com/LayerZero-Labs/devtools/blob/05443835db976b7a528b883b19ddf02cb7f36d89/packages/oapp-evm/contracts/oapp/OAppReceiver.sol#L95) — это стандартная точка входа для всех входящих сообщений. Она выполняет базовые проверки перед вызовом `OAppReceiver::_lzReceive`, которая уже переопределена с учетом логики токена в [`OFTCore`](https://github.com/LayerZero-Labs/devtools/blob/05443835db976b7a528b883b19ddf02cb7f36d89/packages/oft-evm/contracts/OFTCore.sol#L266).  

Выполняются две проверки:  

1. Функцию `lzReceive` мог вызвать **только** Endpoint.  
2. Отправитель сообщения должен совпадать с `peer`, который был установлен для исходной сети через `setPeer`.  

После этого управление передается в `OFTCore::_lzReceive`.  

![oft-core-lz-receive](./img/oft-core-lz-receive.png)  
*Граф вызовов для lzReceive*  

Функция `OFTCore::_lzReceive` выполняет два простых шага:  

- Вызывает `_credit`, чтобы сминтить токены в сети назначения (или выполнить другую заложенную в токене логику).  
- Проверяет, есть ли дополнительные транзакции для выполнения `Endpoint::sendCompose`, и при необходимости добавляет их в очередь.  

```solidity
function _lzReceive(
    Origin calldata _origin,
    bytes32 _guid,
    bytes calldata _message,
    address /*_executor*/, // @dev не используется в дефолтной реализации.
    bytes calldata /*_extraData*/ // @dev не используется в дефолтной реализации.
) internal virtual override {
    // Приводим адрес к EVM-формату
    address toAddress = _message.sendTo().bytes32ToAddress();

    // Вызываем OFT::_credit
    uint256 amountReceivedLD = _credit(toAddress, _toLD(_message.amountSD()), _origin.srcEid);

    // Если есть дополнительные транзакции, добавляем их в очередь Endpoint
    if (_message.isComposed()) {
        bytes memory composeMsg = OFTComposeMsgCodec.encode(
            _origin.nonce,
            _origin.srcEid,
            amountReceivedLD,
            _message.composeMsg()
        );
        endpoint.sendCompose(toAddress, _guid, 0 /* индекс compose-сообщения */, composeMsg);
    }

    emit OFTReceived(_guid, _origin.srcEid, toAddress, amountReceivedLD);
}
```

*Важно!* Чтобы OApp мог работать с `compose`-транзакциями, он должен реализовать интерфейс [`IOAppComposer`](https://github.com/LayerZero-Labs/devtools/blob/05443835db976b7a528b883b19ddf02cb7f36d89/packages/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol). В базовой реализации этой функции нет.  

### Оценка `gasLimit` и комиссии стека безопасности  

Для успешного выполнения транзакции в сети назначения необходимо правильно рассчитать два параметра:  

1. **Количество газа** (`gasLimit`), необходимое для выполнения транзакции.  
2. **Стоимость газа в сети назначения**, выраженную в токенах исходной сети (например, если отправка идет из Ethereum в Polygon, расчет производится в POL, но оплатить нужно в ETH).  

С `gasLimit` не все так очевидно. Для разных блокчейнов можно либо выставлять его **с запасом**, либо рассчитывать эмпирически. Позже мы разберем, как проверить установленное значение перед отправкой.  

Допустим, для **EVM-сетей** берем усредненное значение **80 000 единиц газа**. Тогда опции выглядят так:  

```solidity
bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(80000, 0);
```

Далее нужно сформировать структуру [`SendParam`](https://github.com/LayerZero-Labs/devtools/blob/05443835db976b7a528b883b19ddf02cb7f36d89/packages/oft-evm/contracts/interfaces/IOFT.sol#L10), заполнив все необходимые поля:  

```solidity
SendParam memory sendParam = SendParam(
    40267, // EID
    addressToBytes32(0x32bb35Fc246CB3979c4Df996F18366C6c753c29c), // Адрес получателя OFT-токенов в сети назначения
    1e18, // amountLD
    1e18, // minAmountLD
    options,
    "", // composeMsg
    ""  // oftCmd
);
```

Чтобы посчитать комиссию стека безопасности и Executer, вызываем [`OFTCore::quoteSend`](https://github.com/LayerZero-Labs/devtools/blob/05443835db976b7a528b883b19ddf02cb7f36d89/packages/oft-evm/contracts/OFTCore.sol#L145):  

```solidity
MessagingFee memory fee = OFT.quoteSend(sendParam, false);
```

![oft-core-quote-send](./img/oft-core-quote-send.png)  
*Граф вызовов quoteSend*  

Шаги 1 и 2 здесь схожи с `OFTCore::send`, но `_debit` не вызывается. На **третьем шаге** выполняется вызов `Endpoint::quote`, где рассчитывается комиссия на основе цен на газ в сети назначения и установленных параметров безопасности.  

Расчеты, выполняемые Endpoint, можно посмотреть [здесь](https://github.com/LayerZero-Labs/LayerZero-v2/blob/a3637f851ab1b987bff9fb3db31bf40a59ac374b/packages/layerzero-v2/evm/protocol/contracts/EndpointV2.sol#L55).  

Зная рассчитанную комиссию, можно отправить сообщение:  

```solidity
OFT.send{ value: fee.nativeFee }(sendParam, fee, refundAddress);
```

Пример можно посмотреть в тестах — [`test_send_oft`](./contracts/test/foundry/MetaLampOFTv1.t.sol).  

#### Лимит `gasLimit`  

Ранее мы обсуждали `enforcedOptions`. Если уже рассчитано среднее значение газа для конкретной сети, его можно задать через [`OAppOptionsType3::setEnforcedOptions`](https://github.com/LayerZero-Labs/devtools/blob/05443835db976b7a528b883b19ddf02cb7f36d89/packages/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol#L28).

### Оценка лимитов токена  

Для OFT существует дополнительная функция предварительной проверки [`OFTCore::quoteOFT`](https://github.com/LayerZero-Labs/devtools/blob/05443835db976b7a528b883b19ddf02cb7f36d89/packages/oft-evm/contracts/OFTCore.sol#L108). Она может быть настроена в зависимости от требований конкретного токена.  

```solidity
function quoteOFT(
    SendParam calldata _sendParam
) external view virtual returns (
    OFTLimit memory oftLimit, // Опциональные настраиваемые лимиты. По умолчанию от 0 до totalSupply.
    OFTFeeDetail[] memory oftFeeDetails, // Комиссии токена, тоже опционально.
    OFTReceipt memory oftReceipt // amountSentLD и amountReceivedLD
) {}
```

## Как задеплоить и настроить OFT-токен  

Если проект OFT-токена был создан через `npx create-lz-oapp@latest`, в нем уже есть необходимые скрипты для деплоя. Достаточно создать файл `.env` и настроить нужные сети в [`hardhat.config.ts`](./contracts/hardhat.config.ts) для деплоя и верификации контрактов в эксплорерах.  

После этого можно запустить команду:  

```bash
npx hardhat lz:deploy
```

Затем следовать инструкциям, в качестве тега указать название смарт-контракта. Подробная инструкция есть [в документации](https://docs.layerzero.network/v2/developers/evm/create-lz-oapp/deploying) или в [`README`](./contracts/README.md#layerzero-hardhat-helper-tasks) проекта.  

![deploy-contracts](./img/deploy-contracts.png)  
*Деплой смарт-контрактов в тестовые блокчейны*  

После деплоя контракты развернуты, но их еще нужно настроить и связать между собой.  

Первым шагом необходимо создать конфигурацию. Для этого есть отдельный hardhat-скрипт:  

```bash
npx hardhat lz:oapp:config:init --contract-name MetaLampOFTv1 --oapp-config layerzero.config.ts
```

В результате создается файл [`layerzero.config.ts`](./contracts/layerzero.config.ts), в котором задаются стандартные параметры стека безопасности, а также указывается адрес Executor для выбранных сетей.  

Следующий шаг — применение этих настроек к OApps (контрактам токенов в разных сетях) и контрактам Endpoint.  

```bash
npx hardhat lz:oapp:wire --oapp-config layerzero.config.ts
```

Этот скрипт выполнит все необходимые транзакции в каждой сети. Поскольку их будет много, стоит убедиться, что хватает средств на оплату газа.  

В процессе будут вызваны следующие функции:  

- `OFTToken::setPeer`  
- `OFTToken::setEnforcedOptions` (если они указаны в конфигурации)  
- `Endpoint::setConfig`  
- `Endpoint::setSendLibrary`  
- `Endpoint::setReceiveLibrary`  

Для каждого блокчейна можно отдельно задать `setEnforcedOptions` который мы обсуждали выше.

Прелесть в том, что если вы измените какие-то опции, то при следующем запуске скрипта выполнятся только те транзакции, которые нужны для установки новых опций, все остальное будет пропущено.

Подробнее про конфигурацию можно почитать [в документации](https://docs.layerzero.network/v2/developers/evm/protocol-gas-settings/default-config).  

## Отправка транзакции  

Отправка омничейн-токенов — не самый простой процесс. Без вспомогательных скриптов обойтись сложно, поэтому я написал Foundry-скрипт [`SendTokens`](./contracts/scripts/SendTokens.s.sol), который позволяет пересылать токены между контрактами `MetaLampOFTv1` в сетях Ethereum Sepolia и Polygon.  

Перед отправкой токенов их нужно получить на баланс. Для этого в контракте есть функция `claim`, которая начисляет 100 MLOFTv1. Проще всего вызвать ее через блокчейн-эксплореры соотвествующих блокчейнов (ссылки на контракты есть [здесь](./contracts/README.md)).  

Команда для отправки токенов:  

```bash
pnpm send \
--rpc-url <rpc_url> \
<sender_address> \
<src_oft_oapp_address> \
<dst_recipient_address> \
<amount_LD> \
<dst_eid> \
--broadcast
```

Пример отправки:  

```bash
pnpm send \
--rpc-url sepolia \
0x32bb35Fc246CB3979c4Df996F18366C6c753c29c \
0xcd5407ae7FA70C6ea1f77eDD7A3dde34BED187F5 \
0x32bb35Fc246CB3979c4Df996F18366C6c753c29c \
1000000000000000000 \
40267 \
--broadcast
```

Результат:  

```bash
== Logs ==
  GUID: 
  0x832318c92f1b0abe842f8ec5059d47aad92df8ca8de6a94b4bf8be301b689952
  MessagingReceipt: nonce: 4, fee: 75768729416500
  OFTReceipt: amountSentLD: 1000000000000000000, amountReceivedLD: 1000000000000000000

##### sepolia
✅  [Success] Hash: 0xb791c8aae098e5bfe449ddf58e012beebbf1ff2c3b81960adddd6abc67a7620e
```

После отправки можно взять хэш транзакции и проверить ее статус в [LayerZeroScan](https://testnet.layerzeroscan.com/). Если статус **"Delivered"**, то токены успешно дошли до сети назначения. Можно проверить баланс в сети назначения, а также `totalSupply` в обеих сетях.  

*Примечание:* рекомендую сначала запустить команду **без флага** `--broadcast`, чтобы посмотреть, сколько **fee** потребуется для транзакции. Например, при отправке в обратном направлении мне рассчитали очень высокий `nativeFee` в Polygon Amoy — вероятно, из-за проблем с `priceFeed`.

### Что если транзакция не выполнилась?  

У меня была ситуация, когда я отправил транзакцию с недостаточным `gasLimit`, из-за чего она упала в сети назначения. В результате токены были **сожжены в исходной сети**, но не были выпущены в сети назначения, и общий `totalSupply` нарушился.  

Решение оказалось простым: я вызвал `Endpoint::lzReceive` в сети назначения, передав аргументы застрявшей транзакции, после чего она была успешно выполнена. Такую транзакцию может выполнить **любой**, кто оплатит газ, так как она уже прошла все проверки, и не важно, кто будет исполнителем.  

Это одно из преимуществ протокола LayerZero — возможность исправлять некоторые ошибки вручную. Однако это не означает, что он полностью защищает от всех возможных ошибок. Поэтому важно тщательно тестировать все кейсы использования вашего OFT-токена.  

## Средняя оценка `gasLimit`  

В проекте, созданном через `npx create-lz-oapp@latest`, есть скрипты для оценки газа (`lzReceive` и `lzCompose`). Они запускают форк нужной сети, прогоняют транзакции указанное количество раз и выдают средние значения.  

На момент написания статьи команда запуска `lzReceive` в шаблоне была ошибочной. Я исправил ее в [этом репозитории](./contracts/README.md#estimating-lzreceive-and-lzcompose-gas-usage).  

Есть несколько нюансов:  

1. Для запуска скрипта требуется сообщение в формате `bytes`.  
2. Если получатель в сети назначения не имеет баланса, оценка газа будет выше. Первая запись в слот смарт-контракта дороже, чем последующие перезаписи.  
3. Результаты скрипта показались мне заниженными по сравнению с замерами в Gas Profiler от Tenderly.  

Чтобы получить сообщение в `bytes`, используем команду:  

```bash
forge script scripts/SendTokens.s.sol \
--via-ir \
--sig "encode(address,uint256,bytes)" \
<recipient_address> \
<amount_LD> \
<compose_msg>
```

Пример:  

```bash
forge script scripts/SendTokens.s.sol \
--via-ir \
--sig "encode(address,uint256,bytes)" \
0x4cD6778754ba04F069f8D96BCD7B37Ccae6A145d \
1000000000000000000 \
"0x"
```

Выходные данные:  

```bash
== Return ==
_msg: bytes 0x0000000000000000000000004cd6778754ba04f069f8d96bcd7b37ccae6a145d00000000000f4240
```

Теперь можно запустить скрипт для оценки газа:  

```bash
pnpm gas:lzReceive \
<rpcUrl> \
<endpointAddress> \
"(<srcEid>,<sender>,<dstEid>,<receiver>,[<message>],<msg.value>)<numOfRuns>"
```

Где:  
- `rpcUrl` — RPC URL сети, для которой считаем средний `gasLimit`.  
- `endpointAddress` — адрес Endpoint в этой сети.  
- `srcEid` — EID исходной сети.  
- `sender` — адрес OApp в исходной сети.  
- `dstEid` — EID сети назначения.  
- `receiver` — адрес OApp в сети назначения.  
- `message` — массив сообщений в формате `bytes`.  
- `msg.value` — количество нативных токенов (в wei).  
- `numOfRuns` — количество запусков.  

Пример:  

```bash
pnpm gas:lzReceive \
polygonAmoy \
0x6EDCE65403992e310A62460808c4b910D972f10f \
"(40161,0x000000000000000000000000cd5407ae7fa70c6ea1f77edd7a3dde34bed187f5,40267,0x54d412fee228e13a42f38bc760faeffdfe838536,[0x0000000000000000000000004cd6778754ba04f069f8d96bcd7b37ccae6a145d00000000000f4240],0,10)"
```

Выходные данные:  

```bash
== Logs ==
  Starting gas profiling for lzReceive on dstEid: 40267
  ---------------------------------------------------------
  Aggregated Gas Metrics Across All Payloads:
  Overall Average Gas Used: 19051
  Overall Minimum Gas Used: 19051
  Overall Maximum Gas Used: 19051
  Estimated options:
  0x00030100110100000000000000000000000000004e23
  ---------------------------------------------------------
  Finished gas profiling for lzReceive on dstEid: 40267
  ---------------------------------------------------------
```

### OFTProfilerExample  

Мне больше понравился скрипт [`OFTProfilerExample`](./contracts/scripts/OFTProfilerExample.s.sol).  

Он запускается с предустановленными параметрами, но выдает результаты, приближенные к реальным. Его конфигурации можно изменять, и он легко запускается:  

```bash
pnpm gas:run 10
```

Где `10` — число прогонов. Если скрипт не запускается, попробуйте убрать флаг `--via-ir` в команде, она находится в `package.json`.  

## PreCrime  

В исходной сети есть несколько механизмов для проверки транзакции перед отправкой:  
- `quote`  
- `msgInspector`  
- `enforcedOptions`  

Но в **сети назначения** все сложнее, так как состояние другого блокчейна неизвестно.  

В базовой реализации OFT-токена остался один смарт-контракт который мы не рассматривали — [`OAppPreCrimeSimulator`](https://github.com/LayerZero-Labs/devtools/blob/05443835db976b7a528b883b19ddf02cb7f36d89/packages/oapp-evm/contracts/precrime/OAppPreCrimeSimulator.sol).  

Этот контракт позволяет подключить [`PreCrime`](https://github.com/LayerZero-Labs/devtools/blob/05443835db976b7a528b883b19ddf02cb7f36d89/packages/oapp-evm/contracts/precrime/PreCrime.sol). Модуль `PreCrime` используется для **офчейн-симуляции `_lzReceive`**, по задумке может работать сразу со всеми сетями где развернуто приложение. 

При этом вызов `OAppPreCrimeSimulator::lzReceiveAndRevert` **всегда** завершается `revert`, а результаты симуляции читаются из ошибки `SimulationResult`, куда они записываются через `PreCrime::buildSimulationResult`.  

Это дополнительный слой безопасности, но **главная особенность** PreCrime — его интеграция со стеком безопасности. То есть у него есть полномочия отменять трназакции еще на этапе проверок в канале передачи данных.

Бэкенд может отслеживать транзакции и использовать `PreCrime` для проверки основных инвариантов протокола. Если обнаружена вредоносная транзакция, она отменяется в `MessagingChannel`, прежде чем попадет в Executor.

## Какие бывают опции и как они устроены?  

Протокол LayerZero содержит множество особенностей, которые важно понимать при разработке. Одна из таких деталей — **options**.  

Мы уже неоднократно использовали `options` в самой простой форме, например так:  

```solidity
uint128 GAS_LIMIT = 50000; // gasLimit для Executor
uint128 MSG_VALUE = 0; // msg.value для lzReceive() (wei)

bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(GAS_LIMIT, MSG_VALUE);
```

За формирование опций отвечает библиотека [`OptionsBuilder`](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol).  Первое, что делает `OptionsBuilder`, это вызов функции `newOptions`.


```solidity
function newOptions() internal pure returns (bytes memory) {
    return abi.encodePacked(TYPE_3);
}
```

Контракт `OFTCore` наследуется от `OAppOptionsType3`, который проверяет, что **все опции должны быть типа `TYPE_3`** через `_assertOptionsType3`.  

Кроме того, `OptionsBuilder::addExecutorLzReceiveOption` имеет модификатор `onlyType3`.  

Почему нельзя использовать `TYPE_1` и `TYPE_2`? Это устаревшие контейнеры для упаковки опций из LayerZero v1. В LayerZero v2 используется только `TYPE_3`, так как он более гибкий и позволяет расширять функциональность.  

#### Содержимое контейнера  

Опции разных типов:  
- `TYPE_1` — содержал только `gasLimit`.  
- `TYPE_2` — добавлял возможность передачи нативных токенов (`native drop`).  
- `TYPE_3` — включает дополнительные параметры и позволяет комбинировать опции.  

Контейнер `TYPE_3` состоит из:  
- типа контейнера,  
- ID воркера,  
- размера опций,  
- типа опций,  
- самих опций.  

Сначала добавляется тип контейнера (`TYPE_3`):  

![option-type-3-1](./img/options-type-3-1.png)  

После этого формируются сами опции. Например, в `addExecutorLzReceiveOption` данные кодируются через библиотеку `ExecutorOptions`:  

```solidity
// OptionsBuilder library
function addExecutorLzReceiveOption(
    bytes memory _options,
    uint128 _gas,
    uint128 _value
) internal pure onlyType3(_options) returns (bytes memory) {
    bytes memory option = ExecutorOptions.encodeLzReceiveOption(_gas, _value);
    return addExecutorOption(_options, ExecutorOptions.OPTION_TYPE_LZRECEIVE, option);
}

// ---------------------------------------------------------

// ExecutorOptions library
function encodeLzReceiveOption(uint128 _gas, uint128 _value) internal pure returns (bytes memory) {
    return _value == 0 ? abi.encodePacked(_gas) : abi.encodePacked(_gas, _value);
}
```

Здесь выполняется конкатенация `GAS_LIMIT` и `MSG_VALUE`:  

![options-type-3-5](./img/options-type-3-5.png)  

После этого добавляются ID воркера, размер и тип опции:  

```solidity
function addExecutorOption(
    bytes memory _options,
    uint8 _optionType,
    bytes memory _option
) internal pure onlyType3(_options) returns (bytes memory) {
    return abi.encodePacked(
        _options,
        ExecutorOptions.WORKER_ID,
        _option.length.toUint16() + 1, // размер опции + 1 байт для типа
        _optionType,
        _option
    );
}
```

Здесь используются:  
- **Worker ID** (на данный момент их всего два):
  - Executor (`id = 1`) — обрабатывает опции через [`ExecutorOptions`](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/messagelib/contracts/libs/ExecutorOptions.sol).  
  - DVN (`id = 2`) — используется [`DVNOptions`](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/messagelib/contracts/uln/libs/DVNOptions.sol).  
- **Option Type** (пока их 5):  
  - `OPTION_TYPE_LZRECEIVE` = 1  
  - `OPTION_TYPE_NATIVE_DROP` = 2  
  - `OPTION_TYPE_LZCOMPOSE` = 3  
  - `OPTION_TYPE_ORDERED_EXECUTION` = 4  
  - `OPTION_TYPE_LZREAD` = 5  

Финальная структура `addExecutorLzReceiveOption`:  
- `worker id = 1` (Executor)  
- `option type = 1` (`OPTION_TYPE_LZRECEIVE`)  
- `option length = 17` (gasLimit = 16 байт + 1 байт type)  

Если `value > 0`, длина `option` будет больше (`gasLimit 16 + value 16 + type 1 = 33 байта`). В нашем случае нулевой `value` отбрасывается.
В результате кодировка опций будет такой:  

```bash
0003 01 0011 01 0000000000000000000000000000c350

opt.type | work.id | ex.opt.type.length | ex.opt.type |         option          |
uint16   | uint8   | uint16             | uint8       | uint128         | 0     |
3        | 1       | 17                 | 1           | 50000 (gasLimit)| value |
```

![options-type-3-2-4](./img/options-type-3-2-4.png)  
*Расположение данных в контейнере TYPE_3*  

### Особенности задания опций  

Другие опции можно найти в [`OptionsBuilder`](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol).  

Также можно попробовать сформировать разные виды опций в [Remix](https://remix.ethereum.org/#url=https://docs.layerzero.network/LayerZero/contracts/OptionsGenerator.sol&lang=en&optimize=false&runs=200&evmVersion=null&version=soljson-v0.8.26+commit.8a97fa7a.js).

#### Работа с gasLimit  

Параметр `gasLimit` рассчитывается на основе профилирования расхода газа в сети назначения. "Стоимость" выполнения опкодов может отличаться в разных блокчейнах, поэтому важно учитывать особенности каждой сети.  

У каждого блокчейна есть **максимальный лимит газа** (`nativeCap`), который можно передать в сеть назначения. Получить эту информацию можно через `Executor::dstConfig(dstEid)`, которая возвращает структуру `DstConfig`:  

```solidity
struct DstConfig {
    uint64 baseGas;
    uint16 multiplierBps;
    uint128 floorMarginUSD;
    uint128 nativeCap;
}
```

- **`baseGas`** — фиксированная стоимость газа для базовых операций (`lzReceive`, верификация через стек безопасности). Это минимальное количество газа для самого маленького сообщения.  
- **`multiplierBps`** — множитель в **базисных пунктах** (1 bps = 0,01%). Используется для расчёта дополнительного газа в зависимости от размера сообщения.  
- **`floorMarginUSD`** — минимальная плата в USD для предотвращения спама и покрытия затрат. Если рассчитанная стоимость транзакции в USD ниже этого значения, она **устанавливается на `floorMarginUSD`**.  
- **`nativeCap`** — максимальный лимит газа, который OApp может указать для выполнения сообщения в сети назначения.  

Эти данные можно получить в проекте, выполнив команду:  

```bash
npx hardhat lz:oapp:config:get:executor
```

#### Native drop  

`Native drop` — это передача **нативных токенов** в сеть назначения. Например, в `addExecutorLzReceiveOption` второй параметр (`MSG_VALUE`) используется именно для этого.  

Есть также отдельная опция `addExecutorNativeDropOption`, которая принимает `amount` (сумму) и `receiver` (адрес получателя) и не требует указания `gasLimit`:  

```solidity
function addExecutorNativeDropOption(
    bytes memory _options,
    uint128 _amount,
    bytes32 _receiver
) internal pure onlyType3(_options) returns (bytes memory) {
    bytes memory option = ExecutorOptions.encodeNativeDropOption(_amount, _receiver);
    return addExecutorOption(_options, ExecutorOptions.OPTION_TYPE_NATIVE_DROP, option);
}
```

*Примечание:* Ранее в протоколе было ограничение на native drop - 0.5 токена в эквиваленте нативного токена сети (например ETH, BNB и т.д.). Более того, было предостережение, что чем больше сумма, тем больше расходы на передачу. Сейчас об этом нет упоминаний, но нужно иметь в виду что такого рода ограничения тоже могут возникнуть.

## Заключение  

Стандарт OFT оставил положительное впечатление. Он гибкий, дает широкие возможности настройки, а "из коробки" уже предоставляет весь необходимый функционал для создания простого ERC20 OFT-токена.  

Отдельно стоит отметить удобство быстрого развертывания проекта:  
- Готовые тесты;
- Скрипты hardhat и foundry для деплоя и настройки OApps в разных блокчейнах;
- Инструменты для оценки газа.

Несмотря на надежность канала передачи данных LayerZero, всегда есть риск пограничных кейсов, особенно если токен включает комиссии, административные функции или сложные механики.  

Поэтому важно:  
- Тщательно тестировать токен  
- Проводить аудит кода  
- Проверять поведение в мейннете, так как большая часть протокола работает офчейн (DVN, стек безопасности, Executor). В тестовых сетях оценка комиссий может давать некорректные результаты.  

Практика показывает, что даже крупные проекты, такие как Tether, не застрахованы от ошибок. Аудит и внимательное тестирование — ключевые факторы безопасности.  

#### Ссылки  
- [GitHub: LayerZero v2](https://github.com/LayerZero-Labs/LayerZero-v2)  
- [GitHub: LayerZero-Labs/devtools](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oft-evm/contracts)  
- [Docs: LayerZero v2](https://docs.layerzero.network/v2)  
- [Docs: Solidity API](https://docs.layerzero.network/v2/developers/evm/technical-reference/api#endpointv2)  
- [Docs: LayerZero Glossary](https://docs.layerzero.network/v2/home/glossary#lzcompose)  
- [Docs: USDT0](https://docs.usdt0.to/)  
- [Audit: USDT0](https://github.com/Everdawn-Labs/usdt0-audit-reports)  
- [LayerZeroScan](https://layerzeroscan.com/)