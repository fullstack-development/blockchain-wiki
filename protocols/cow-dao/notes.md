# CoW DAO

**Автор:** [Павел Найданов](https://github.com/PavelNaydanov) 🕵️‍♂️

CoW DAO - это целый набор продуктов под управлением собственного DAO.

## Список продуктов

TODO: Перечислить список продуктов и дать краткое описание каждого
- Cow Protocol
- Cow Swap
- Cow Amm
- Mev blocker
- Cow Explorer
- Widget

## История появления протокола

https://blog.cow.fi/gnosis-protocol-turns-cow-protocol-481c9fa90bb2

Предложение в Gnosis DAO об отделении Cow protocol, создании своего токена и своего DAO.
https://forum.gnosis.io/t/gip-13-phase-2-cowdao-and-cow-token/2735

После этого отделения протокол CoW имеет свою систему управления, свое дао, свой токен и так далее, запускает новый независимый бренд, но при этом, как я понял Gnosis был ранним инвестором. Своего рода Gnosis получил откупную при отсоединение проекта Cow Swap. Часть команды тоже перешла в новый протокол.

## CoW Protocol

Говорим, что Протокол CoW — это торговый протокол, который использует intentions и аукционы для поиска оптимальных цен и защиты заказов от MEV.

- https://docs.cow.fi/cow-protocol/concepts/how-it-works/protocol-vs-swap

### Что такое intent based?

https://medium.com/alliancedao/intents-are-just-7deaeb4336be
https://github.com/fullstack-development/blockchain-wiki/tree/main/protocols/UniswapX
https://docs.cow.fi/cow-protocol/concepts/introduction/intents

В этом разделе кратко нужно ввести читателя в предметную область intent based.

- Что такое намерение?
- Общая схема работы intent based протоколов.

### Как CoW protocol реализует модель intention?

- https://docs.cow.fi/cow-protocol
- Кто такие solvers? https://www.youtube.com/watch?v=QARLIeH5Cs0&ab_channel=DappConBerlin


- перерисовать схему, добавить на схему solvers, чтобы было понятно, какую роль они играют
- Какой профит получают солверы за свою работу?
- сказать, что источников ликвидности у Cow Swap много
- Сказать, что есть следующий алгоритм свапа: намерения группируются и в первую очередь ищутся совпадения среди самих намерений, затем что происходит дальше (приватные маркет мейкеры, приватная ликвидность или пулы)
- рассказать про аукционы https://docs.cow.fi/cow-protocol/tutorials/arbitrate

### Order types

- Market orders
- Limit orders
- TWAP orders
- Programmatic orders
  - ERC-1271?
  - https://blog.cow.fi/introducing-the-programmatic-order-framework-from-cow-protocol-088a14cb0375
  - https://docs.cow.fi/cow-protocol/reference/contracts/periphery/composable-cow
- Milkman orders
  - https://docs.cow.fi/cow-protocol/concepts/order-types/milkman-orders
  - https://github.com/cowdao-grants/milkman/blob/main/README.md код для милкмана
  - Адреса прайс чекеров https://github.com/cowdao-grants/milkman/blob/main/DEPLOYMENTS.md для милкмана

### Cow Hooks

- https://docs.cow.fi/cow-protocol/concepts/order-types/cow-hooks
- https://docs.cow.fi/cow-protocol/tutorials/hook-dapp

- Найти, как это реализовано в коде.
- Предложить свой вариант хука, чтобы показать, как это работает. Возможно это уже можно оформлять в отдельной статье.

Как я понял, это можно сделать только на ts, через специальную либу https://www.npmjs.com/package/@cowprotocol/hook-dapp-lib

Есть еще вот такая штука для более сложных сценариев https://github.com/cowdao-grants/cow-shed. Пока не понятно что это.

### Flash loans
- объяснение, как это работает https://docs.cow.fi/cow-protocol/tutorials/cow-swap/flash-loans
- https://github.com/cowprotocol/flash-loan-router/blob/main/README.md Код контракта flash loans

По сути ты описываешь, что хочешь сделать в appdata транзакции, а дальше солвер будет сам вызывать через специальный контракт для работы с флешлоанами и запускать settlement

### Контракты

- Разбор контрактов https://github.com/cowprotocol/contracts/tree/main

## Cow Swap

- Дальше говорим про разницу между cow протоколом и cow swap.
- Разбор того, как он там под капотом работает, от создания intention, до исполнения его солверами

CoW Swap - это первый интерфейс, созданный на основе протокола CoW, который в настоящее время является самым популярным. (https://docs.cow.fi/cow-protocol/concepts/how-it-works/protocol-vs-swap)

## Cow Amm

- Это amm, которая защищает поставщиков ликвидности от LVR (Loss-versus-rebalancing)

Контракты AMM находятся в репозитории:
- или тут https://github.com/balancer/balancer-v3-monorepo/blob/main/pkg/pool-cow/README.md
- или тут https://github.com/balancer/cow-amm

- Нужна схема, как это работает
- Кажется здесь надо разбираться как работают взвешенные пулы в Balancer, чтобы понимать, что и как

## Mev blocker

- от чего защищает
- как работает

Работает так:
1. это отдельный рпс провайдер
2. Подмешивает фальшивые транзакции
3. Транзакции отправляются до серчеров блока
4. Транзакции отправляются до билдеров блока
5. Включение транзакции в блока

Я так понимаю есть еще свой аукцион, который уже про добавление транзакций в блок.

## Cow Explorer

Это как etherscan только для Cow Swap
  - https://explorer.cow.fi/

## Widget

Это штука, которая позволяет встроить готовый модуль для обменов от Cow протокола на свою страничку

## Среда разработки

У них нет примеров кода, они сделали среду для обучения разработчиков интегрировать Cow Swap.

https://learn.cow.fi/tutorial/getting-started-order

Если что-то интересно есть в интеграциях, то можно тоже про это описать.

## Вывод

- Предоставление пользователям возможности оплачивать комиссию за газ в своих токенах продажи  без необходимости хранить собственный токен цепочки (например, ETH) в своем кошельке.
- Устранение комиссий за неудавшиеся транзакции
- Разрешение пользователям размещать несколько заказов одновременно

TODO: Я вижу минус, если один алгоритм для солвера хорошо написан, может ли он стать монополистом?

## Вопросы

Это вопросы на которые пока не нашел ответ.

1. Как работают солверы на аукционе? Вот они видят батч с ордерами, придумывают как их исполнить и что дальше? они их исполняют или передают на бекенд свое решение?
2. Как в этом всем замешан балансер?

## Идеи

Я думаю надо бить это на статьи по продуктам. Mev blocker точно отдельно обозревать, там еще надо в mev концепт погрузиться немного. Кто такие searchers, builders, как это работает в эфире.

- Решателей называть solvers.
- Намерения называть intentions.
Это потом правильно переведется на английский, да и звучит как-то получше.


Везде своими словами, не копировать даже из доки, каждая буква должна быть написана человеком, должно чувствоваться глубокое понимание того о чем написано и понятно, как автору, так и читателю.
