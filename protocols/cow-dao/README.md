# CoW DAO

**Автор:** [Алексей Куценко](https://github.com/bimkon144) 👨‍💻

[CoW DAO](https://cow.fi/) - это целый набор продуктов под управлением собственного DAO.

Основным продуктом является cow protocol.

В основе продукта cow protocol лежит концепция CoW ([Coincidence of Wants](https://docs.cow.fi/cow-protocol/concepts/how-it-works/coincidence-of-wants)), которая позволяет трейдерам обмениваться токенами напрямую, без лишних посредников.

Представьте, что вы хотите продать ETH за USDC, а кто-то другой хочет продать USDC за ETH. В обычном DEX каждый из вас заплатил бы комиссию за свою сделку сторонним поставщикам ликвидности и конечно же за газ.
А в CoW Swap вы можете просто обменяться напрямую, заплатив только лишь часть продаваемых токенов исполнителю транзакции! Это как найти идеального торгового партнёра на рынке.

## Список продуктов

**CoW Protocol**
Сердце всей системы - полностью open source торговый протокол, который использует пакетные аукционы и Coincidence of Wants.

**CoW Swap**
[Веб-интерфейс](https://github.com/cowprotocol/cowswap), через который пользователи взаимодействуют с протоколом торговли.

**CoW AMM**
Специальный пул ликвидности, который решает главную проблему обычных AMM - LVR (Loss-versus-rebalancing) из-за арбитражников. LVR - это форма арбитража, которая возникает всякий раз, когда на AMM указана устаревшая цена по сравнению с какой-либо другой торговой площадкой, на которой очень быстро меняется цена, например Binance.
За счет разницы цен, арбитражник может "отбирать" потенциальную прибыль у LP в AMM пуле.

**MEV Blocker**
Созданный RPC endpoint для защиты транзакций от MEV, таких как frontrunning и sandwitching. К тому же, пользователи могут получить прибыль от backrunning их транзакций.

**Cow Explorer**
Похожий на etherscan [обозреватель](https://explorer.cow.fi/), но созданный для визуализации выставленных и выполненных ордеров в протоколе.

**Widget**

C помощью [виджета](https://widget.cow.fi/) можно создавать кастомный интерфейс для взаимодействия с протоколом в своем приложении.

## Как всё начиналось: от Gnosis Protocol к CoW Swap

История CoW Swap началась в экосистеме [Gnosis](https://www.gnosis.io/) - одного из старейших проектов Ethereum.

**Gnosis Protocol v1 (2020)**

Первая версия была амбициозной попыткой создать децентрализованный обменник с ордербуком прямо в блокчейне. Идея была хорошей, но на практике возникли проблемы:

- Каждый ордер стоил дорого из-за высоких комиссий за газ
- Хранение ордеров в блокчейне ограничивало ликвидность

Таким образом, необходим был подход, который помог бы улучшить ситуацию вышеуказанных проблем.

**Gnosis Protocol v2 (2021)**

В 2021 году команда сделала серьёзный апгрейд:

- Убрали ордербук из блокчейна (сделали off-chain)
- Переход на систему intentions и solvers. Если коротко, то теперь пользователи просто подписывают свои торговые intentions off-chain, а solvers соревнуются за право их исполнить on-chain самым выгодным способом.

**CoW Protocol (2022)**

Успех Gnosis Protocol v2 привел к важному решению - команда предложила Gnosis DAO отделить протокол в самостоятельный проект. В январе 2022 года было подано [предложение GIP-13](https://forum.gnosis.io/t/gip-13-phase-2-cowdao-and-cow-token/2735) о создании независимого CoW Protocol с собственным токеном и DAO.

Процесс отделения был взаимовыгодным:
- **Gnosis DAO получила 10% токенов COW** как компенсацию за предыдущие инвестиции в развитие команды и протокола
- **Команда разработчиков получила 15% токенов** для привлечения новых разработчиков
- **Пользователи получили аирдроп** за использование протокола

Весной 2022 года был запущен токен COW и создана [CoW DAO](https://docs.cow.fi/governance) - полностью независимая децентрализованная организация. CoW Swap стал флагманским интерфейсом нового протокола.

Управление происходит через систему предложений [CIP](https://docs.cow.fi/governance/process) (CoW Improvement Proposals) - каждое важное решение обсуждается сообществом и проходит голосование.

Токен [COW](https://coinmarketcap.com/currencies/cow-protocol/) выполняет три ключевые функции в экосистеме:

- Участие в управлении протоколом через голосование в DAO
- Внесение залога solvers как гарантия добросовестности
- Стимулирование активных участников экосистемы: вознаграждение solvers за успешное исполнение пакетных аукционов и финансирование разработчиков через гранты CowDAO для улучшения протокола

Таким образом протокол CoW имеет свою собственную систему управления, свой токен и свою команду под новым брендом.

## CoW Protocol

Протокол CoW - это торговый протокол, который использует intent-based модель, solvers и аукционы для поиска оптимальных цен и защиты транзакций от MEV.

### Архитектура системы

Прежде чем погрузиться в детали, давайте посмотрим на общую архитектуру CoW Protocol:

```mermaid
graph TB
    subgraph "User Layer"
        U1[👤 User 1]
        U2[👤 User 2]
        UN[👤 User N]
        UI[🖥️ CoW Swap UI]
        Widget[📱 CoW Widget]
    end
    
    subgraph "Protocol Layer"
        OrderBook[📋 Order Book<br/>off-chain storage]
        Autopilot[🤖 Autopilot<br/>orchestrator]
        
        subgraph "Solvers"
            S1[🔧 Solver 1<br/>Driver + Engine]
            S2[🔧 Solver 2<br/>Driver + Engine]
            SN[🔧 Solver N<br/>Driver + Engine]
        end
    end
    
    subgraph "Blockchain Layer"
        Settlement[⚖️ Settlement<br/>Contract]
        VaultRelayer[🏦 Vault Relayer<br/>Contract]
        
        subgraph "External Liquidity"
            Uniswap[🦄 Uniswap]
            Curve[🌀 Curve]
            Balancer[⚖️ Balancer]
            Other[🔗 Other DEXs]
        end
    end
    
    subgraph "Infrastructure"
        MEVBlocker[🛡️ MEV Blocker<br/>RPC]
        Explorer[🔍 CoW Explorer]
    end
    
    %% User connections
    U1 --> UI
    U2 --> Widget
    UN --> UI
    UI --> OrderBook
    Widget --> OrderBook
    
    %% Order processing
    OrderBook --> Autopilot
    Autopilot --> S1
    Autopilot --> S2
    Autopilot --> SN
    
    %% Solver connections
    S1 --> Settlement
    S2 --> Settlement
    SN --> Settlement
    
    %% Settlement connections
    Settlement --> VaultRelayer
    Settlement --> Uniswap
    Settlement --> Curve
    Settlement --> Balancer
    Settlement --> Other
    
    %% MEV Protection
    UI --> MEVBlocker
    MEVBlocker --> OrderBook
    
    %% Monitoring
    Settlement --> Explorer
```

**Основные компоненты:**

- **User Layer** - интерфейсы для взаимодействия пользователей с протоколом
- **Protocol Layer** - ядро системы с координацией аукционов и соревнованием solvers
- **Blockchain Layer** - смарт-контракты для исполнения сделок и доступ к внешней ликвидности
- **Infrastructure** - вспомогательные сервисы для защиты от MEV и мониторинга

### Что такое intent based?

Чтобы понять CoW Protocol, нужно сначала разобраться с концепцией `intent-based` (основанных на intentions) протоколов - это кардинально другой подход к взаимодействию с блокчейном.

**intent (intention)** - это способ сказать блокчейну "что вы хотите получить", а не "как именно это сделать". Это как разница между заказом такси ("довезите меня до аэропорта") и самостоятельным вождением (выбор маршрута, поворотов, полос).

**Традиционный подход:**
- Пользователь сам выбирает DEX (Uniswap, SushiSwap)
- Сам рассчитывает маршрут обмена
- Сам отправляет транзакцию с конкретными параметрами
- Несет все риски (MEV, проскальзывание, неоптимальные цены)

**Intent-based подход:**
- Пользователь просто выражает желание: "хочу обменять 1000 USDC на ETH"
- Специальные участники (solvers) соревнуются за право найти лучший способ исполнить это `intent`
- Пользователь получает лучший результат без необходимости разбираться в технических деталях

#### Общая схема работы intent-based протоколов

Все intent-based протоколы работают по похожей схеме:


```mermaid
sequenceDiagram
    participant User as 👤 User
    participant Protocol as 🔄 Intent-based Protocol
    participant Solver1 as 🤖 Solver 1
    participant Solver2 as 🤖 Solver 2
    participant SolverN as 🤖 Solver N
    participant Blockchain as ⛓️ Blockchain
    
    Note over User, Blockchain: 1. Intent Expression (off-chain)
    User->>Protocol: Signs intent<br/>"Want to swap 1000 USDC for ETH"
    
    Note over User, Blockchain: 2. Solver Auction (off-chain)
    Protocol->>Solver1: Sends intent
    Protocol->>Solver2: Sends intent
    Protocol->>SolverN: Sends intent
    
    Solver1->>Protocol: Proposes solution A<br/>(price, route, gas)
    Solver2->>Protocol: Proposes solution B<br/>(best price!)
    SolverN->>Protocol: Proposes solution N<br/>(high gas)
    
    Protocol->>Protocol: Selects best solution<br/>(Solver 2 wins)
    
    Note over User, Blockchain: 3. Execution (on-chain)
    Protocol->>Solver2: Authorizes execution
    Solver2->>Blockchain: Submits transaction<br/>with optimal route
    Blockchain->>User: User receives ETH<br/>at best price
    
    Note over User, Blockchain: ✅ Result: best price
```

1. **Выражение intent** - пользователь подписывает сообщение о своих торговых целях (off-chain)
2. **Аукцион solvers** - специальные участники соревнуются за право исполнить intention
3. **Исполнение** - победивший solver выполняет intent наилучшим способом

### Как CoW protocol реализует модель intention?

CoW Protocol реализует intent-based модель через систему solvers, которые соревнуются за право исполнить пакеты (`batch`) intentions пользователей наилучшим способом участвуя в `batch auctions`.

**Ключевые элементы в CoW Protocol:**

- **Intentions** - off-chain ордера подписанные через EIP-712, ERC-1271, eth-sign или наличие Presign на контракте.

- **Solvers** - участники протокола, которые соревнуются за право обработать пакет из `intentions`. Под соревнованием понимается нахождение самого выгодного маршрута обмена всех ордеров пользователей.

```mermaid
sequenceDiagram
    participant User1 as 👤 User 1
    participant User2 as 👤 User 2
    participant UserN as 👤 User N
    participant CoWProtocol as 🔄 CoW Protocol<br/>(Order Book)
    participant Solver1 as 🤖 Solver 1
    participant Solver2 as 🤖 Solver 2
    participant SolverN as 🤖 Solver N
    participant Settlement as ⚖️ Settlement<br/>Contract
    participant DEX as 🏪 External DEX<br/>(Uniswap, etc.)
    
    Note over User1, DEX: 1. Intent Expression (off-chain)
    User1->>CoWProtocol: Signs intent:<br/>"Sell 1000 USDC for ETH"
    User2->>CoWProtocol: Signs intent:<br/>"Sell 0.5 ETH for DAI"
    UserN->>CoWProtocol: Signs intent:<br/>"Sell DAI for USDC"
    
    Note over User1, DEX: 2. Batch Formation & Solver Auction
    CoWProtocol->>CoWProtocol: Forms batch of intentions
    
    CoWProtocol->>Solver1: Sends batch
    CoWProtocol->>Solver2: Sends batch
    CoWProtocol->>SolverN: Sends batch
    
    Note over Solver1, SolverN: Solvers analyze batch and find optimal solutions
    
    Solver1->>Solver1: Finds CoW opportunities<br/>+ external liquidity
    Solver2->>Solver2: Finds ring trades<br/>+ better DEX routes
    SolverN->>SolverN: Finds direct swaps<br/>+ high gas costs
    
    Solver1->>CoWProtocol: Solution A:<br/>Price: 0.46 ETH, Gas: 0.003 ETH
    Solver2->>CoWProtocol: Solution B:<br/>Price: 0.47 ETH, Gas: 0.002 ETH ⭐
    SolverN->>CoWProtocol: Solution N:<br/>Price: 0.45 ETH, Gas: 0.005 ETH
    
    CoWProtocol->>CoWProtocol: Selects best solution<br/>(Solver 2 wins auction)
    
    Note over User1, DEX: 3. Execution (on-chain)
    CoWProtocol->>Solver2: Authorizes execution
    
    Solver2->>Settlement: Calls settle() with:<br/>- CoW matches (User1↔User2)<br/>- External trades for UserN
    
    alt CoW Opportunities Found
        Settlement->>Settlement: Direct P2P exchange<br/>User1 USDC → User2<br/>User2 ETH → User1
    else External Liquidity Needed
        Settlement->>DEX: Execute trade for UserN<br/>DAI → USDC via Uniswap
        DEX->>Settlement: Returns USDC
    end
    
    Settlement->>User1: Receives ETH at best price
    Settlement->>User2: Receives DAI at best price
    Settlement->>UserN: Receives USDC at best price
```

Таким образом, порядок работы можно описать так:

1. Создание `intent` пользователями.
2. Формирование пакета `intentions` в `batch auction`.
3. Проведение `batch auction` среди solvers, где solvers ищет совпадение среди самих intentions - CoW ([Coincidence of Wants](https://docs.cow.fi/cow-protocol/concepts/how-it-works/coincidence-of-wants)), а затем уже внешние, приватные ликвидности, пулы uniswap, balancer и тд.
4. Исполнение `batch auction` в блокчейне.

Рассмотрим существующие типы Coincidence of Wants, которые являются одной из главных фишек протокола:

**Простой обмен (Direct CoW)**

Самый простой случай - когда два трейдера хотят обменяться напрямую.

![alt text](./img/direct.png)

*Полное исполнение двух ордеров:*
- Alice хочет продать 1000 DAI за ETH
- Bob хочет продать 0.5 ETH за DAI
- Система находит это совпадение, и вы обмениваетесь напрямую

Это позволяет обойти комиссию провайдеров ликвидности (LP) в обменниках.

*Частичное исполнение ордеров:*
- Alice хочет продать DAI за 0.5 ETH
- Bob хочет продать только 0.3 ETH за 600 DAI
- Система находит это совпадение, и вы обмениваетесь частично: 600 DAI на 0.3 ETH

Остаток вашего ордера (400 DAI) будет заполняться через внешние источники ликвидности, такие как Uniswap или 1inch.

**Пакетирование (Batching)**

Часто пакет аукциона содержит intentions от разных пользователей, желающих выполнить одинаковый тип обмена:

- Алиса хочет получить ETH и готова отдать USDC
- Боб также хочет получить ETH и готов отдать USDC
- Вместо выполнения двух отдельных сделок через Uniswap, solver объединяет эти intentions в одну транзакцию

![alt text](./img/batching.png)

Такой "батчинг" оптимизирует расходы на газ, поскольку взаимодействие со смарт-контрактами AMM происходит меньшее количество раз.

**Промежуточный обмен**

Промежуточный CoW происходит, когда в пакете есть "промежуточные" сделки, которые могут быть соединены:

- Alice хочет получить USDC и отдаёт за него токены COW
- Bob хочет получить COW и отдаёт за него токены USDT

Напрямую эти сделки не сопоставляются, но через промежуточный токен ETH solver создает цепочку обменов:

1. Alice отдаёт COW → получает ETH → получает USDC
2. Bob отдаёт USDT → получает ETH → получает COW

![alt text](./img/intermediate.png)

В этой схеме образуется общий сегмент: COW → ETH (Alice) и ETH → COW (для Bob).

Solver замыкает этот сегмент напрямую между пользователями.

**Важно:** ETH используется только как расчетная валюта, фактически токены COW от Alice напрямую поступают к Bob, минуя промежуточные преобразования.

*Преимущества такого подхода:*
1. **Меньше комиссий** - исключаются дублирующиеся шаги обмена
2. **Меньше проскальзывания** - прямой обмен не влияет на рыночную цену
3. **Экономия на газе** - меньше взаимодействий со смарт-контрактами
4. **Меньшее влияние на пулы ликвидности** - более стабильные цены для всех пользователей

**Кольцевой обмен (Ring Trade)**

Кольцевой CoW объединяет три или более пользователей, чьи intentions образуют замкнутую цепочку обменов:

- Alice хочет получить ETH, отдавая DAI
- Bob хочет получить USDC, отдавая ETH
- Niko хочет получить COW, отдавая USDC
- Vlad хочет получить DAI, отдавая COW

Вместо отдельных сделок solver создает кольцевую структуру, где каждый получает желаемый токен напрямую:

1. DAI от Alice → Vlad
2. COW от Vlad → Niko
3. USDC от Niko → Bob
4. ETH от Bob → Alice

![alt text](./img/ring.png)

Каждый токен перемещается только один раз, напрямую между участниками, без использования внешних пулов ликвидности.

*Преимущества кольцевого обмена:*
- Максимальная экономия на комиссиях и газу
- Полное отсутствие проскальзывания
- Справедливое ценообразование для всех участников
- Эффективное использование ликвидности без воздействия на рынок

Следует упомянять, что источников ликвидности у cow protocol множество.

Использование внешних источников ликвидности:
- AMM (Uniswap, Sushiswap, Balancer, CoW Amm, Curve и другие)
- Агрегаторы (1inch, Paraswap, Matcha и другие)
- Частные маркет-мейкеры (Ликвидность доступная самим solvers, либо даже CEX)

Эти типы p2p обмена совместно с использованием внешней ликвидности позволяют добиться существенной оптимизации по комиссиям и газу.

### Arbitrate auctions

Разберем верхнеуровнево архитектуру работы `batch auction`.

```mermaid
sequenceDiagram
    participant User as 👤<br/>User
    participant OrderBook as 📚<br/>Order book
    participant Autopilot as 🤖<br/>Autopilot
    participant Solver as ⚡<br/>Solver
    
    User->>OrderBook: POST /order
    Autopilot->>OrderBook: Request solvable orders
    OrderBook-->>Autopilot: Response solvable orders
    Autopilot->>Autopilot: Create auction
    Autopilot->>Solver: /solve
    Solver-->>Autopilot: Score
    Autopilot->>Solver: /settle
    Solver->>Solver: Settles transaction on-chain
    Solver-->>Autopilot: Transaction hash
    Solver->>User: User receives tokens
```

Эти три главные компонента требуются для функционирования аукциона.

**Order book** - это офф-чейн компонент с базой данных, через API которого размещают, отменяют и получают активные ордера. Он обеспечивает взаимодействие трейдеров, UI и других интерфейсов с CoW Protocol.

**Autopilot** - это офф-чейн сервис, которая принимает ордера с `order book` и организует аукцион. Она отправляет всем solvers об этом аукционе. Собирает оценки от solvers и выбирает лучшего, которому поручает выполнить задачи. Если кто-то из solvers ведет себя нечестно, например, завышает оценку, система может наказать его через DAO.

**Solver** - независимые участники протокола, которые соревнуются за право исполнить пакет ордеров. Каждый solver анализирует полученный от Autopilot пакет intentions, ищет оптимальные пути исполнения и даёт оценку для Autopilot.

Для большего понимания рассмотрим каждого участника системы более детально.

#### Orderbook

По сути это офф-чейн сервис [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) стейта, который состоит из API и базы данных. Код можно посмотреть [тут](https://github.com/cowprotocol/services/tree/main/crates/orderbook).

Orderbook является **главной точкой входа** в протокол. Через его API пользователи, UI и другие интеграции могут:

- Получать котировки для ордеров (`post/quote`)
- Размещать ордера (`post/orders`)
- Отменять ордера (`delete/orders`)
- Получать информацию о текущем решенном аукционе
- Отслеживать статус своих ордеров

Полный список [API](https://docs.cow.fi/cow-protocol/reference/apis/orderbook).

Схему взаимодействия `orderBook` можно рассмотреть ниже:

```mermaid
sequenceDiagram
    participant User
    participant Order book
    participant Solver1  
    participant SolverN
    participant Database
    
    User->>Order book: POST /quote
    Order book->>Solver1: quote?
    Order book->>SolverN: quote?
    
    Solver1->>Solver1: compute matching for<br/>single order batch
    SolverN->>SolverN: compute matching for<br/>single order batch
    
    Solver1-->>Order book: result
    SolverN-->>Order book: result
    
    Order book->>Order book: simulate quote
    Order book->>Order book: pick best result
    
    Order book->>Database: store quote
    Order book-->>User: quote
    
    User->>User: sign order
    
    User->>Order book: POST /order
    
    Order book->>Order book: verify order
    
    Order book->>Database: fetch quote
    
    alt if quote not found
        Order book->>Solver1: quote?
        Order book->>SolverN: quote?  
        Solver1-->>Order book: result
        SolverN-->>Order book: result
        Order book->>Order book: simulate & pick
    end
    
    Order book->>Database: insert order
    Order book-->>User: order UID
    
    User->>User: wait for happy moo
    
    User->>Order book: GET /trades
    Order book->>Database: lookup order
    Database-->>Order book: order & trades
    Order book-->>User: trades
```

Можно разбить на 3 этапа: Получение котировки (quote), размещение ордера и обработка и мониторинг ордера.

**Получение котировки**

1. `User → Order book: POST /quote`
   Пользователь отправляет запрос котировки с параметрами сделки, чтобы понять, сколько токенов он получит при обмене.

2. `Order book → Solver1/SolverN: quote?`
   Orderbook запрашивает solvers для решения `batch` с одним ордером, и solvers возвращают свои предложения.

3. `Order book → Order book: simulate & pick best result`
   Orderbook симулирует котировки и выбирает лучшую, максимизирующую output для трейдера, затем сохраняет её в базе данных.

4. `Order book → User: quote`
   Возвращает котировку трейдеру для подписи.

**Размещение ордера**

1. `User → Order book: sign & POST /order`
   Пользователь подписывает ордер офф-чейн и отправляет его в Order book для включения в следующий batch.

2. `Order book → Order book: verify order & fetch quote`
   Order book проверяет валидность ордера (формат, балансы, подпись, appData) и ищет соответствующую котировку для классификации. Если котировка не найдена, создается новая.

3. `Order book → Database → User: insert order & return UID`
   Order book сохраняет валидированный ордер в базе данных для autopilot и возвращает уникальный идентификатор пользователю.

**Обработка и мониторинг ордера**

1. `User → User: wait for happy moo`
   Пользователь ждет исполнения ордера. Теперь очередь autopilot и solvers распределить и исполнить ордер ("happy moo" = успешное исполнение в стиле CoW).

2. `User → Order book: GET /trades`
   После исполнения пользователь запрашивает информацию о выполненной сделке.

3. `Order book → Database → User: lookup & return trades`
   Order book ищет информацию об ордере в базе данных и возвращает пользователю данные о выполненной сделке и результатах solver competition.

#### Autopilot

Код офф-чейн сервиса можно посмотреть [тут](https://github.com/cowprotocol/services/tree/main/crates/autopilot)

**Когда создаются новые аукционы:**

Autopilot работает постоянно и запускает новый аукцион в трех случаях. Первый - когда пользователи создают, отменяют или меняют свои ордера. Второй - когда в блокчейне появляется новый блок и может поменяться состояние сети. Третий - если прошло больше 2 секунд с момента последнего блока и система решает проверить обновления.

Такая логика нужна, чтобы не создавать пустые аукционы без изменений. На каждый аукцион solvers получают 15 секунд.

После выбора победителя у solver есть ограниченное время отправить транзакцию в сеть. Если solver не отправляет транзакцию в течение этого времени, то ордера возвращаются в следующий аукцион.

**Детальная диаграмма работы Autopilot:**

```mermaid
sequenceDiagram
    participant Database as database
    participant Blockchain as blockchain  
    participant Autopilot as autopilot
    participant Solver1 as solver 1
    participant Solver2 as solver 2
    participant Solver3 as solver 3

    par
        Autopilot->>Database: Get order information
        Note right of Database: UIDs, signatures, owners...
    and
        Autopilot->>Blockchain: Get order information
        Note right of Blockchain: On-chain cancellations, ETH flow...
    end

    Autopilot->>Autopilot: Cut auction

    par
        Autopilot->>Solver1: /solve
        Note right of Autopilot: [broadcast current auction]
    and
        Autopilot->>Solver2: /solve
    and  
        Autopilot->>Solver3: /solve
    end

    Solver1-->>Autopilot: Proposed batch
    Solver2-->>Autopilot: Proposed batch
    Solver3-->>Autopilot: Proposed batch

    Autopilot->>Autopilot: Pick winner

    Autopilot->>Solver1: /settle

    Solver1-->>Blockchain: Execute transaction
    Blockchain->>Solver1: Transaction receipt
    Solver1-->>Autopilot: Transaction hash

    Autopilot-->>Database: Store auction data
```

Процесс работы можно разбить на 3 этапа: сбор данных, формирование аукциона, соревнование solvers и исполнение.

**Сбор данных об ордерах**

1. `Autopilot → Database & Blockchain: Get order information`
   Autopilot запрашивает информацию из общей базы данных с Orderbook (UIDs, офф-чейн подписи, владельцы) и мониторит блокчейн:
   - **Pre-signatures**: отслеживает события `PreSignature` когда пользователи подписывают ордера on-chain через функцию `setPreSignature`
   - **Отмены ордеров**: мониторит события `OrderInvalidated` при вызове функции `invalidateOrder`
   - **ETH flow**: мониторит события ETH Flow контракта - когда пользователи создают новые ордера с использование нативного токена сети.

2. `Autopilot → Autopilot: Cut auction`
   Autopilot формирует пакет аукциона из всех торгуемых ордеров. Далее сервис получает цены на эти токены в ETH из множественных источников (solvers, Paraswap, 1inch, Uniswap pools). Эти цены включаются в пакет аукциона, чтобы solvers имели одинаковую цену токенов и также для упрощения перевода в `scores` по единым ценам в ETH. Если цену токена в ETH получить нельзя, ордер исключается. По сути это как ценовой оракл для всех solvers.
   Далее, фильтрует ордера которые не могут быть исполнены: просроченные, с недостаточным балансом для fill-or-kill, без approve на контракт через который будет происходить трейд, с неподдерживаемыми токенами, с невалидными ERC-1271 подписями.

**Соревнование solvers**

1. `Autopilot → Solver1/2/3: /solve`
   Autopilot рассылает пакет аукциона всем зарегистрированным solvers. Solvers имеют ограниченное время (по умолчанию 15 секунд, настраивается через `solve_deadline` в конфигурации Autopilot) для анализа аукциона и возврата решения. Это ограничение для поддержания быстрых циклов аукционов.

2. `Solver1/2/3 → Autopilot: Proposed batch`
   Solvers анализируют аукцион и возвращают свои предложения с рассчитанными `scores`, которые представляют качество решения.

3. `Autopilot → Autopilot: Pick winner`
   При выборе победителя Autopilot делает дополнительные проверки и фильтрацию решений для обеспечения честности. Подробнее об этой системе фильтрации смотреть раздел "Расчет Score и алгоритм выбора победителей".

**Исполнение и завершение**

1. `Autopilot → Winner: /settle`
   Autopilot уведомляет победителя о необходимости исполнить решение. Solver отвечает за исполнение транзакции on-chain.

2. `Winner → Blockchain → Autopilot: Execute & report`
   Solver исполняет транзакцию в блокчейне и сообщает hash транзакции Autopilot.
3. `Autopilot → Database: Store auction data`
   Autopilot сохраняет все данные аукциона: предложения от solvers, scores, surplus fees для limit ордеров, результаты on-chain исполнения. Эти данные используются для расчета solver payouts. Некорректное поведение solvers выявляется на этапе расчета выплат.
   
По сути, Autopilot играет роль судьи в соревновании между solvers. Он определяет правила игры для каждого раунда - какие ордера участвуют, по каким ценам считать результат. При этом система построена на умном балансе между скоростью и безопасностью: solvers могут быстро соревноваться и исполнять решения, а проверка честности происходит на этапе выбора победителя, а так же после завершения аукциона. Это похоже на спортивные соревнования, где судья фиксирует результаты в реальном времени, а детальный анализ и возможные санкции проводятся позже. Такой подход позволяет протоколу работать с высокой скоростью, не жертвуя при этом надежностью.

#### Solvers

Solvers представляет из себя off-chain сервис из двух компонентов: driver и solver engine.

```mermaid
sequenceDiagram
    participant Autopilot as 🤖<br/>autopilot
    participant Driver as 🔧<br/>driver
    participant Engine as 🧠<br/>solver engine

    Autopilot->>Driver: auction
    Driver->>Driver: pre-process auction
    Driver->>Driver: fetch liquidity
    Driver->>Engine: auction
    Engine-->>Driver: set of solutions
    Driver->>Driver: post-process solutions
    Driver-->>Autopilot: participate with the best solution
    Autopilot->>Driver: request to execute the settlement,<br/>in case this solver won
    Driver->>Driver: execute the settlement
```

**Driver** - координирует работу solver: получает аукцион от Autopilot, подготавливает данные для Engine, обрабатывает решения, оценивает, отправляет решение в autopilot и исполняет их в блокчейне. Есть [открытый исходный код](https://github.com/cowprotocol/services/tree/main/crates/driver).

**Solver Engine** - реализует алгоритмы сопоставления ордеров для поиска оптимальных решений. Получает данные от Driver, находит лучшие пути исполнения и возвращает инструкции для достижения результата в блокчейне. Различные solvers с открытым исходным кодом доступны в [CoW Protocol solvers](https://github.com/cowprotocol/services/tree/main/crates/solvers). Но для того чтобы выиграть аукцион, команды разрабатывают свои собственные супер оптимизированные алгоритмы с приватной ликвидностью `solver engine`.

Работу solver можно разбить на 4 этапа: подготовительная фаза, фаза решения, финализация и участие, исполнение (если solver победил).

**Детальная схема работы Solver:**

**Подготовительная фаза**

1. `Autopilot → Driver: auction`
   Autopilot отправляет новый аукцион всем зарегистрированным solvers. Driver получает "сырой" аукцион с минимальным набором данных.

2. `Driver → Driver: pre-process auction`
   Driver обогащает аукцион дополнительной информацией: метаданные токенов (decimals, symbols), фильтрует невыполнимые ордера (недостаточные балансы, истекшие), делает базовую приоритизацию.

3. `Driver → Driver: fetch liquidity`
   Driver собирает актуальные данные о ликвидности из кешированных источников: AMM пулы (Uniswap, Balancer, Curve), агрегаторы, частные источники ликвидности команды.

**Фаза решения**

4. `Driver → Engine: auction`
   Driver передает полностью подготовленный аукцион в Solver Engine со всей необходимой информацией для принятия решений.

5. `Engine → Driver: set of solutions`
   Solver Engine анализирует аукцион своими алгоритмами и возвращает набор возможных решений с их оценками качества.

**Финализация и участие**

6. `Driver → Driver: post-process solutions`
   Driver проверяет корректность решений, симулирует их исполнение, объединяет совместимые решения для повышения эффективности, делает расчет score и выбирает лучшее решение для участия.

7. `Driver → Autopilot: submit solution`
   Driver отправляет лучшее решение с рассчитанным score:

   ```rust
   // https://github.com/cowprotocol/services/blob/main/crates/driver/src/infra/api/routes/solve/dto/solve_response.rs
   pub struct Solution {
      solution_id: u64,              // Уникальный ID решения
      score: eth::U256,             //  Оценка решения пакетного аукциона
      submission_address: eth::H160, // Адрес solver для исполнения
      orders: HashMap<OrderId, TradedOrder>, // Исполненные ордера с деталями
      clearing_prices: HashMap<eth::H160, eth::U256>, // Цены исполнения, предлагаемые solver
   }
   ```

8. `Autopilot → Driver: execute settlement (if winner)`
   При победе в аукционе Driver исполняет решение on-chain.

Архитектура разделяет ответственность: Driver обеспечивает интеграцию с протоколом, Engine реализует алгоритмы сопоставления.

#### Расчет score и алгоритм выбора победителей

**Расчет score**

Ключевой механизм конкуренции между solvers это расчет `score` (оценки качества) решений, который определяет победителя аукциона.

Формула расчета Score согласно [CIP-38](https://forum.cow.fi/t/cip-38-solver-computed-fees-rank-by-surplus/2061) и [CIP-65](https://forum.cow.fi/t/cip-65-updating-score-definition-for-buy-orders/2930)

```
Score = (User Surplus + Protocol Fees) в ETH
```

**Для sell ордера:**
```
score = (surplus + protocol_fees) × native_price_buy_token
# surplus для sell ордера уже в buy токене
```

**Для buy ордера:**
```
score = (surplus + protocol_fees) × p_limit × native_price_buy_token
где p_limit = limit_buy_amount / limit_sell_amount
```

> **Объяснение:** Для buy ордеров surplus находится в sell токене, поэтому сначала конвертируем его в buy токены через лимитное отношение p_limit, а затем в ETH через native_price_buy_token.

Где:
- `surplus` - дополнительная стоимость, которую получает пользователь сверх лимитной цены
- `protocol_fees` - комиссии протокола
- `native_price_buy_token` - цена покупаемого токена в ETH (цена из аукциона)

**Пример расчета для sell ордера:**
```
Sell ордер: продать 1 ETH за USDC
- Лимитная цена: 1 ETH = 2000 USDC
- Фактическое исполнение: 1 ETH = 2050 USDC
- User surplus: 2050 - 2000 = 50 USDC (surplus в buy токене)
- Protocol fees: 5 USDC
- Цена USDC: 0.0004 ETH

Score = (50 + 5) × 0.0004 = 0.022 ETH
# Используем цену USDC, так как surplus и fees в USDC (buy токен)
```

**Пример расчета для buy ордера:**
```
Buy ордер: купить 100 USDC за DAI
- limit_buy_amount: 100 USDC
- limit_sell_amount: 102 DAI (готов заплатить максимум)
- executed_sell_amount: 98 DAI (заплатил фактически)
- executed_buy_amount: 100 USDC (получил)

1. Surplus в sell токене: 102 - 98 = 4 DAI
2. Protocol fees: 0.5 DAI
3. p_limit = 100 USDC / 102 DAI = 0.98 USDC/DAI
4. Цена USDC: 0.0004 ETH

Score = (4 + 0.5) × 0.98 × 0.0004 = 0.001764 ETH
# Используем цену USDC, так как конвертируем итоговый surplus в USDC (buy токен)

Пошагово:
- 4.5 DAI surplus конвертируется в buy токены: 4.5 × 0.98 = 4.41 USDC
- 4.41 USDC конвертируется в ETH: 4.41 × 0.0004 = 0.001764 ETH
```

**Реализация функции расчета score:**

```rust
// https://github.com/cowprotocol/services/blob/main/crates/driver/src/domain/competition/solution/scoring.rs
fn score(&self, native_prices: &auction::Prices) -> Result<eth::Ether, Error> {
    let native_price_buy = native_prices
        .get(&self.signed_buy.token)
        .ok_or(Error::MissingPrice(self.signed_buy.token))?;

    let surplus_in_surplus_token = self
        .user_surplus()?
        .0
        .checked_add(self.fees()?.0)
        .ok_or(Error::Math(Math::Overflow))?;

    let score = match self.side {
        // surplus для sell ордеров уже в buy токенах, просто конвертируем в ETH
        Side::Sell => native_price_buy.in_eth(eth::TokenAmount(surplus_in_surplus_token)),
        
        Side::Buy => {
            // surplus для buy ордеров в sell токенах. Конвертируем в buy токены:
            // buy_amount = surplus * buy_price / sell_price
            let surplus_in_buy_tokens: eth::U256 = surplus_in_surplus_token
                .full_mul(self.signed_buy.amount.0)         // surplus * buy_price  
                .checked_div(self.signed_sell.amount.0.into())  // / sell_price
                .ok_or(Error::Math(Math::DivisionByZero))?
                .try_into()
                .map_err(|_| Error::Math(Math::Overflow))?;

            // Затем конвертируем buy токены в ETH
            native_price_buy.in_eth(surplus_in_buy_tokens.into())
        }
    };
    Ok(score)
}
```

**Алгоритм выбора победителей**

После получения решений от всех solvers, Autopilot запускает многоэтапный процесс отбора с независимой верификацией score:

**1. Пересчет Score для верификации**
Autopilot независимо пересчитывает score для каждого решения, используя те же цены токенов из аукциона (а не текущие рыночные цены). Решения, для которых не удается пересчитать score, автоматически отбрасываются.

**2. EBBO проверка честности (Equal or Better than Best Offer)**
Проверяется, что цены в решении не хуже лучших предложений на источниках ликвидности (Uniswap, Sushiswap, Balancer и др.). Решения, нарушающие EBBO, отбрасываются как "unfair".

**3. Сортировка и выбор победителя**
Выбирается решение с наивысшим пересчитанным score.

**Реализация логики выбора победителей:**

```rust
// https://github.com/cowprotocol/services/blob/main/crates/autopilot/src/domain/competition/winner_selection/combinatorial.rs
fn partition_unfair_solutions(&self, mut participants: Vec<Participant<Unranked>>, 
                             auction: &domain::Auction) -> PartitionedSolutions {
    // ПЕРЕСЧЕТ SCORE в autopilot для верификации!
    let scores_by_solution = compute_scores_by_solution(&mut participants, auction);
    
    // Сортировка по ПЕРЕСЧИТАННОМУ score
    participants.sort_by_key(|participant| {
        std::cmp::Reverse(participant.solution().computed_score().expect("computed").get().0)
    });
    
    // Fairness check с baseline scores (EBBO)
    let baseline_scores = compute_baseline_scores(&scores_by_solution);
    let (fair, unfair) = participants.into_iter().partition_map(|p| {
        if aggregated_scores.iter().all(|(pair, score)| {
            baseline_scores.get(pair).is_none_or(|baseline| score >= baseline)  // EBBO check
        }) {
            Either::Left(p)   // Fair solution
        } else {
            Either::Right(p)  // Unfair solution - отбрасывается
        }
    });
    
    PartitionedSolutions { kept: fair, discarded: unfair }
}
```

Система обеспечивает честность через три уровня правил: smart contract (рассмотрим позже), off-chain протокол (Autopilot) и social consensus (governance со штрафами).

### Профит solvers за свою работу

**Система вознаграждений solvers**

Протокол субсидирует solver competition на всех поддерживаемых сетях, выплачивая rewards еженедельно (каждый вторник) в токенах COW за период предыдущих 7 дней.

**Требования для участия:**
- Залог: $500,000 USD в cUSDC + 1,500,000 COW токенов
- Техническая инфраструктура для работы solver engine + driver

**Два типа вознаграждений:**

1. **Solver Competition Rewards** (основное соревнование)
   - Используется механизм [Vickrey–Clarke–Groves](https://en.wikipedia.org/wiki/Vickrey%E2%80%93Clarke%E2%80%93Groves_auction)
   - Вознаграждение рассчитывается по формуле: `payment = cap(totalScore - referenceScore - missingScore)`

     - `totalScore` - сумма scores всех winning solutions в аукционе
     - `referenceScore` - total score гипотетического аукциона, как если бы данного solver вообще не существовало (все его предложения удалены из рассмотрения)
     - `missingScore` - сумма scores тех winning solutions данного solver, которые провалились при исполнении on-chain (reverted)
     - `cap(x)` - функция ограничения выплат в зависимости от сети. 
   
     *Примечание: если расчет дает отрицательное значение, solver должен доплатить протоколу. Да такое бывает.*

2. **Price Estimation Competition** (конкуренция котировок)
   - Награды за предоставление котировок. т.е это результат работы solvers, которые показывают юзеру в веб интерфейсе, когда он хочет узнать за сколько ему обменяют его токены.
   - Выплаты за каждый исполненный ордер, для которого solver предоставил котировку:
     - **Ethereum**: min{0.0006 ETH, 6 COW}
     - **Arbitrum**: min{0.0002 ETH, 6 COW}
     - **Gnosis Chain**: min{0.15 xDAI, 6 COW}
     - **Base**: min{0.0002 ETH, 6 COW}

Таким образом, solver сам покрывает расходы на газ, и несет ответственность в виде штрафа за неудачные транзакции в блокчейн.
В целом по этой причине, такой значительный размер залога требуется от solvers.

### Комиссия протокола и партнеров

Важные понятия:

> **Излишек (Surplus)** - разница между фактической ценой исполнения и минимальной ценой исполнения **лимитного ордера**. Это то, насколько лучше вы получили по сравнению с вашим минимальным требованием. Например, если вы установили минимальную цену 0.45 ETH за 1000 USDC, а ордер исполнился по цене 0.47 ETH, то Surplus составит 0.02 ETH.

> **Улучшение цены (Quote improvement)** - разница между фактической ценой исполнения и предварительно рассчитанной котировочной ценой для **рыночного ордера**, если эта разница положительная. Это то, насколько лучше вы получили по сравнению с расчетом, показанным в интерфейсе. Например, если интерфейс показывает, что вы получите 0.45 ETH за 1000 USDC, но фактически вы получаете 0.46 ETH, улучшение цены составит 0.01 ETH.

*Ключевое отличие*: `Surplus` сравнивает с вашими собственными условиями при создании лимитного ордера, а `Quote improvement` - с предварительным расчетом системы для рыночного ордера.

**Текущая структура комиссий протокола**

Система использует следующие типы комиссий, которые поступают в казну протокола:

* **Комиссия с `Surplus` для лимитных ордеров**
  * *Определение*: 50% от `Surplus`, но не более 1% от общего объема ордера
  * *К каким ордерам применяется*: только к лимитным ордерам, которые не могут быть исполнены на момент создания (т.е если цена покупки или продажи не соответствует текущей цене по рынку)
  * *Формула расчета*: surplus × 0.5 ИЛИ volume × 0.01 (в зависимости от того, какое число меньше)

* **Комиссия с `Quote improvement` для рыночных ордеров**
  * *Определение*: 50% от положительного улучшения котировки для рыночных ордеров, но не более 1% от общего объема ордера
  * *К каким ордерам применяется*: все рыночные ордера, где пользователь получает лучшую цену, чем было указано в котировке
  * *Формула расчета*: quote_improvement × 0.5 ИЛИ volume × 0.01 (в зависимости от того, какое число меньше)

* **Комиссия с объема на Gnosis Chain**
  * *Определение*: 0.1% (10 базисных пунктов) от общего объема ордера
  * *К каким ордерам применяется*: все рыночные ордера, лимитные ордера и TWAP на Gnosis Chain, за исключением пар токенов с коррелирующими ценами (например пара USDC/USDT)
  * *Формула расчета*: volume × 0.001

**Пример расчета комиссии для лимитного ордера**:
Создаём лимитный ордер на продажу 1000 USDC за ETH, по курсу не менее 0.5 ETH за 1000 USDC.
Solver находит способ исполнить ордер, но потратит 4 USDC на газ.

* Расходы на газ: solver потратил эквивалент 4 USDC на исполнение ордера (удерживается из продаваемого токена)
* Вы отдаёте: 1000 USDC
* Удерживается: 4 USDC (компенсация за газ)
* Solver обменивает оставшиеся 996 USDC и получает 0.5279 ETH
* Фактический излишек: 0.5279 ETH - 0.5 ETH (минимальная цена) = 0.0279 ETH
* Комиссия с излишка (50%): 0.0279 ETH × 0.5 = 0.01395 ETH
* Максимальная комиссия (1% от объема): 0.5279 ETH × 0.01 = 0.00528 ETH
* Итоговая комиссия: min(0.01395 ETH, 0.00528 ETH) = 0.00528 ETH (используется меньшее значение)
* Вы получаете: 0.5279 ETH - 0.00528 ETH (комиссия) = 0.52262 ETH

>**Важно:** Комиссия с излишка удерживается в получаемом токене, а компенсация за газ - в продаваемом токене. Solver платит газ из своих средств, но компенсирует его за счёт вычета из суммы, которую пользователь отдаёт. Чем больше intentions в пакете, тем меньше комиссия за газ с каждого пользователя.

**Партнерские комиссии (Partner Fee)**

CoW Protocol позволяет интеграторам (виджеты, dApps, кошельки) взимать дополнительную комиссию до 1% с торгового объема. Эта комиссия вычитается первой с `buyAmount` при покупке, до расчета surplus и комиссий протокола.

Подробные примеры расчетов и механика работы описаны в [официальной документации](https://docs.cow.fi/governance/fees/partner-fee).

### Структура ордера

В CoW Protocol `intents` пользователей формируется в подписанный order со следующими полями:

```solidity
struct Data {
    IERC20 sellToken;        // Токен для продажи
    IERC20 buyToken;         // Токен для покупки  
    address receiver;        // Получатель купленных токенов
    uint256 sellAmount;      // Количество токенов для продажи
    uint256 buyAmount;       // Минимальное количество токенов для покупки
    uint32 validTo;          // Время истечения ордера (Unix timestamp)
    bytes32 appData;         // Метаданные (партнерские комиссии, hooks)
    uint256 feeAmount;       // Комиссия за исполнение (в sell токенах)
    bytes32 kind;            // Тип ордера (sell/buy)
    bool partiallyFillable;  // Можно ли исполнять частично
    bytes32 sellTokenBalance;// Источник баланса sell токена
    bytes32 buyTokenBalance; // Назначение баланса buy токена
}
```

**Краткое описание полей:**

- **`sellToken/buyToken`** - адреса токенов для обмена
- **`receiver`** - кто получит купленные токены (обычно сам пользователь)
- **`sellAmount/buyAmount`** - количества токенов (buyAmount = минимум к получению)
- **`validTo`** - когда ордер перестает быть действительным
- **`appData`** - IPFS хеш JSON документа с дополнительной информацией (партнерские комиссии, hooks, referral адреса)
- **`feeAmount`** - сколько из sellAmount пойдет на оплату исполнения
- **`kind`** - SELL (продать точно sellAmount) или BUY (купить точно buyAmount)
- **`partiallyFillable`** - можно ли исполнить ордер по частям в разных батчах
- **`sellTokenBalance/buyTokenBalance`** - откуда брать/куда класть токены (ERC20, внутренний баланс Vault)

#### Что такое appData?

`appData` - это поле типа `bytes32` в структуре ордера, которое содержит IPFS хеш (нужно дополнительно конвертировать в CID) JSON документа с дополнительной информацией. Согласно [официальной документации CoW Protocol](https://docs.cow.fi/cow-protocol/reference/core/intents/app-data), это поле позволяет прикреплять к ордеру различную метаинформацию:

**Основные случаи использования:**
- **Партнерские интеграции** - отслеживание объема, привлеченного партнерами
- **Referral адреса** - для реферальных программ  
- **CoW Hooks** - дополнительные действия до/после свапа

**Структура JSON документа:**

JSON файл следует определенной [JSON схеме](https://docs.cow.fi/cow-protocol/reference/core/intents/app-data#schema).

**Обязательные поля:**
- `version` - версия схемы (например, "1.3.0") 
- `metadata` - объект с дополнительными данными (hooks, referral адреса и т.д.)

**Опциональные поля:**
- `appCode` - идентификатор приложения/UI
- `environment` - информация об источнике ордера

Для облегчения составления appData существуют утилиты:

- [CoW Explorer appData utility](https://explorer.cow.fi/appdata?tab=encode) - веб-интерфейс для создания и парсинга appData
- [app-data SDK](https://docs.cow.fi/cow-protocol/reference/sdks/app-data) - библиотека для работы с appData в коде

> **Важно:** При самостоятельном создании appData обязательно следуйте JSON схеме и загрузите файл в IPFS перед размещением ордера.

### Order types

1. Рыночный ордер (Market Order):
    - Стандартный ордер, исполняемый по текущей рыночной цене
    - Используется для быстрого исполнения по лучшей доступной цене
    - Протокол ищет лучшую цену среди всех доступных источников ликвидности

2. Лимитный ордер (Limit Order):
    - Позволяет установить конкретную цену исполнения
    - Исполняется только когда цена достигает или превышает указанную

3. TWAP-ордер (Time-Weighted Average Price):
    - Разбивает большой ордер на несколько маленьких частей, исполняемых через равные промежутки времени
    - Позволяет минимизировать влияние на рынок и проскальзывание при крупных объемах
    - Хорошо подходит для крупных инвесторов и институциональных трейдеров

4. Программируемый ордер (Programmatic Order):
  Предназначен для смарт-контрактов, реализующих стандарт [ERC-1271](https://eips.ethereum.org/EIPS/eip-1271).

    **ERC-1271** - это стандарт, который позволяет смарт-контрактам валидировать подписи от своего имени. Смарт-контракты не могут создавать подписи (у них нет приватного ключа), но они могут проверить, является ли предоставленная подпись действительной для данного контракта. ERC-1271 решает эту проблему через функцию `isValidSignature()`, которая позволяет контракту самому определить логику валидации подписи.

    Пример реализации с owner:
    ```solidity
    contract SimpleWallet {
        address public owner;
        bytes4 constant MAGIC_VALUE = 0x1626ba7e; // ERC-1271 magic value
        
        function isValidSignature(bytes32 hash, bytes memory signature) 
            external view returns (bytes4) {
            
            // Восстанавливаем адрес подписанта из подписи
            address signer = recoverSigner(hash, signature);
            
            // Проверяем, что подписал именно owner контракта
            if (signer == owner) {
                return MAGIC_VALUE; // Подпись валидна
            } else {
                return 0xffffffff; // Подпись невалидна
            }
        }
    }
    ```
    
    В этом примере контракт считает подпись валидной только если её создал owner. Процесс работает так:
    1. Owner создает подпись off-chain своим приватным ключом
    2. CoW Protocol вызывает `isValidSignature()` на контракте
    3. Контракт восстанавливает адрес из подписи и сравнивает с owner
    4. Если совпадает - возвращает магическое значение (подпись валидна)

     - Позволяет реализовать сложную торговую логику
     - Может использоваться для автоматизированных стратегий и интеграций

5. Milkman-ордер:
    - Механизм размещения ордеров, разработанный [Yearn Finance](https://yearn.fi/) в сотрудничестве с CoW Protocol
    - Позволяет исполнять ордера на основе цен из оракулов
    - Полезен для сценариев с высокой волатильностью цен (например, для автоматического исполнения продажи активов по цене оракула на момент окончания голосования DAO. Если бы это был обычный лимитный ордер, заданный в начале голосования, то при изменении рыночных условий к моменту окончания голосования он мог бы не соответствовать актуальной цене оракула)

### CoW Hooks

CoW Hooks представляют собой функциональность CoW Protocol, которая позволяет пользователям привязывать любые Ethereum действия к их ордеру, используя solvers для выполнения всей последовательности операций в одной транзакции.

Разработчики и продвинутые трейдеры могут использовать код для выражения intentions, которые выполняют какие-либо действия до свапа (pre-hooks) и после свапа (post-hooks).

Возможные примеры использования `pre-hooks`:

- Разблокировка токенов из стейкинг-контрактов
- Клейм аирдропов перед продажей
- Approve токенов для использования в свапе
- Конвертация токенов 

Возможные примеры использования `post-hooks`:

- Бридж на L2 (Arbitrum, Optimism, Polygon)
- Стейкинг токенов в протоколы доходности
- Добавление ликвидности в DEX пулы
- Создание LP-позиций в Uniswap v3, Curve

#### Передача данных о hooks через appData

Структура данных хука выглядит так:

- `target` - адрес контракта для вызова
- `value` - количество ETH (в wei) для отправки вместе с вызовом функции
- `callData` - ABI-encoded данные функции
- `gasLimit` - лимит газа для выполнения hook'а

**Важные особенности:**
- Pre-hooks выполняются **только при первом заполнении** частично исполняемых ордеров
- Post-hooks выполняются **при каждом заполнении** ордера
- Hooks выполняются через `HooksTrampoline` контракт
- **Выполнение не гарантировано** - ордер может быть исполнен даже если hook провалился. Поэтому если вы неправильно выставили `gasLimit`, то хук просто не сработает. Можно прибегнуть к хитрости, и для обеспечения 100% выполнения хука вместе с ордером необходимо, чтобы успешность ордера зависела от самого хука, например давать `approve` на торгуемые токены.

> **Что такое частично исполняемые ордера?**
> 
> Частично исполняемые ордера (partially fillable) могут исполняться частями в нескольких батчах. Например:
> - Вы хотите продать 1000 USDC за ETH
> - В текущем батче есть ликвидность только для 300 USDC
> - Ордер исполнится на 300 USDC, остальные 700 USDC будут ждать следующего батча
> 
> Альтернатива - fill-or-kill ордера, которые исполняются полностью или не исполняются вообще.

#### Разработка Hook dApps

CoW Protocol предоставляет инфраструктуру для создания собственных Hook dApps - веб-приложений, которые интегрируются с CoW Swap через [iframe](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/iframe).

##### Инструменты для разработки

**[@cowprotocol/hook-dapp-lib](https://www.npmjs.com/package/@cowprotocol/hook-dapp-lib)** - основная JavaScript/TypeScript библиотека для создания Hook dApps, предоставляющая:
- EIP-1193 провайдер для взаимодействия с кошельком пользователя
- HookDappContext с параметрами окружения и текущими параметрами ордера
- Callback функции для добавления и редактирования hooks

**[CoW Shed](https://github.com/cowprotocol/cow-shed)** - продвинутая система для создания комплексных hooks с поддержкой сложных DeFi сценариев.

CoW Hooks значительно упрощают сложные DeFi операции, предоставляя обычным пользователям возможность выполнять простые действия, такие как "swap и stake", в один клик, разработчикам - создавать комплексные торговые стратегии, а протоколам - интегрироваться с CoW Swap для улучшения пользовательского опыта (UX).

### Flash loans

Flash loans - это возможность взять кредит и вернуть его в рамках одной транзакции без залога. Если кредит + комиссия не возвращается до завершения транзакции, вся операция откатывается.

**Как это работает в CoW Swap:**

**1. Pre-hook: Берем flash loan**
```javascript
// В pre-hook указываем вызов к провайдеру flash loan
const preHook = {
  target: "0x...FlashLoanProvider",
  value: 0,
  callData: "0x...flashLoan(token, amount)", // запрос займа
  gasLimit: "200000"
};
```

**2. Swap: Используем полученные токены**
- Flash loan провайдер передает токены в Settlement контракт
- CoW Swap выполняет обмен полученных токенов на нужные
- Результат swap остается в Settlement контракте

**3. Post-hook: Возвращаем займ + комиссию**
```javascript
// В post-hook возвращаем займ
const postHook = {
  target: "0x...FlashLoanProvider",
  value: 0,
  callData: "0x...repayFlashLoan(token, amount + fee)", // возврат с комиссией
  gasLimit: "200000"
};
```

**4. Кодирование в appData:**
```javascript
const appData = {
  metadata: {
    flashloan: {
      lender: "0x...FlashLoanProvider",
      token: "0x...TokenAddress",
      amount: "1000000000" // сумма займа
    },
    hooks: {
      pre: [preHook],
      post: [postHook]
    }
  }
};
```

**5. Создание ордера:**
Для упрощения создания ордеров с flash loans используется **[@cowprotocol/cow-sdk](https://www.npmjs.com/package/@cowprotocol/cow-sdk)** - позволяет легко создавать ордера, подписывать их, отслеживать статус и работать с appData метаданными.

**6. Установка pre-signature:**
После создания ордера необходимо установить pre-signature, вызвав функцию `setPreSignature(orderUid, true)` на Settlement контракте. Это делает ордер исполнимым для solvers. Без этого шага ордер останется неактивным.

**Практический пример - арбитраж без залога:**
- Заметили разницу цен: 1 ETH = 3000 USDC на CoW Swap, 1 ETH = 3050 USDC на Uniswap
- **Pre-hook**: берете flash loan 3000 USDC у провайдера
- **Swap**: покупаете 1 ETH за 3000 USDC на CoW Swap
- **Post-hook**: продаете 1 ETH за 3050 USDC на Uniswap, возвращаете 3000 USDC + комиссию
- **Прибыль**: ~50 USDC за операцию без собственных средств

**Техническая реализация для solvers:**
Solvers CoW Protocol используют [flash-loan-router](https://github.com/cowprotocol/flash-loan-router) - специализированный смарт-контракт, который позволяет выполнять функцию `settle` через контракт flash loan. Контракт поддерживает различных провайдеров (Aave, ERC-3156 совместимые).

Flash loans особенно полезны для арбитража, рефинансирования долгов и сложных DeFi стратегий.

Получается, что мы программируем appData а дальше solver сам будет вызывать через специальный контракт flash loan, который в свою очередь будет запускать `settle`.

## CoW AMM

Это продукт который solvers используют в качестве дополнительной ликвидности при своей работе.

AMM (Автоматизированный маркет-мейкер) - это тип децентрализованной биржи, который вместо книги ордеров использует формулу для расчёта цены. Торговля происходит через пулы ликвидности, куда пользователи вносят активы и зарабатывают на комиссиях.

**Проблема традиционных AMM:**

Самые базовые AMM - это так называемые CF-AMM (Constant Function AMM).
Они используют формулу x × y = k для расчёта цены между двумя токенами в пуле.

Когда одного токена становится меньше - его цена растёт, и наоборот.
Все сделки происходят вдоль этой кривой, и не выходят за её пределы.

Соответственно в таких AMM (Например, Uniswap) арбитражники эксплуатируют Liquidity Providers (LP) через **LVR (Loss-versus-Rebalancing)** - покупают активы по устаревшей цене до ребалансировки пула, получая прибыль за счет поставщиков ликвидности.

**Решение CoW AMM:**

FM-AMM (Function-Maximizing AMM) - это новая модель AMM, которая решает главные проблемы классических CF-AMM и устраняет LVR (Loss Versus Rebalancing).

В отличие от Uniswap-подобных AMM, где трейды исполняются по очереди,
FM-AMM собирает все заявки в batch и исполняет их одновременно по одной справедливой цене - clearing price.

Эта цена подбирается так, чтобы AMM переходил в новое состояние, которое максимизирует общую ценность пула - вместо того чтобы отдавать её арбитражёрам.

По сути, это означает, что ликвидити-провайдеры (LP) не теряют, а получают долю прибыли, что выражается в росте стоимости их LP токенов.

Подробная [математика](https://arxiv.org/pdf/2307.02074) и [пояснения](https://medium.com/taipei-ethereum-meetup/eli5-what-is-fm-amm-the-theory-behind-cow-amm-and-how-is-it-mev-resistant-53d1960324c0) можно посмотреть для большего понимания.

**Архитектура:**

Смарт-контракт пула [cow-amm](https://github.com/balancer/cow-amm/blob/main/src/contracts/BCoWPool.sol) построен на базе [Balancer pool](https://github.com/balancer/cow-amm/blob/main/src/contracts/BPool.sol).

Но, при деплое через [фабрику](https://github.com/balancer/cow-amm/blob/main/src/contracts/BCoWFactory.sol), по причине того, что контракт наследуется от balancer pool, для полной защиты от MEV требуется установить fee в размере 99,9%. Эта комиссия не даст возможности желающим напрямую трейдить через пул.

Это сделано для того, чтобы все трейды проходили строго через контракт `GPv2Settlement` в функции `settle`, которую могут вызывать только доверенные solvers.

Сам контракт пула cow amm содержит главные методы:

- `commit()` - фиксирует параметры order в виде hash на cow amm pool, с которым планирует сделку.
- `isValidSignature()` (ERC-1271 function) - проверяет подпись.
- `verify()` - проверяет возможность сделки: делает калькуляцию на обмен в зависимости от резервов пула и swapFee = 0 `calcOutGivenIn()` и рассчитывает, чтобы кол-во получаемого токена `tokenAmountOut` было не меньше чем заказано `order.sellAmount`.

Получается, что CoW AMM - это источник ликвидности с swapFee = 0 для solvers CoW Protocol. Он использует партнерство с `Balancer` для получения ликвидности.

Схему флоу такого трейдинга можно посмотреть ниже:

```mermaid
sequenceDiagram
    participant Users as 👥 Users
    participant OrderBook as 📚 OrderBook
    participant Solvers as 🔧 Solvers
    participant Winner as 🏆 Winner Solver
    participant CoWAMM as 🐄 CoW AMM Pool
    participant LP as 💰 LP

    Note over Users, LP: CoW AMM Trading Flow
    
    Users->>OrderBook: Submit trading intents<br/>"Sell ETH for USDC"
    
    OrderBook->>OrderBook: Create batch auction<br/>Group intents together
    OrderBook->>Solvers: Send batch to all solvers<br/>Find best execution
    
    Solvers->>CoWAMM: Check prices & liquidity<br/>Calculate optimal solution
    CoWAMM-->>Solvers: Return pricing info
    
    Solvers->>OrderBook: Submit solutions<br/>Best execution proposals
    OrderBook->>OrderBook: Select winning solution<br/>Best price for users
    
    OrderBook->>Winner: You won! Execute this solution
    
    Winner->>CoWAMM: commit(orderHash)
    Winner->>CoWAMM: verify(order)
    Winner->>CoWAMM: isValidSignature(hash, signature)
    Winner->>CoWAMM: Execute trades
    
    CoWAMM->>LP: Increase LP token value<br/>
    CoWAMM->>Winner: Provide liquidity at 0% fee
    
    Winner->>Users: Deliver tokens<br/>✅ Best execution achieved
    
    Note over Users, LP: Result: Users get best prices,<br/>LP earns from efficient execution
```

Помимо того, что solvers могут использовать эти пулы для своих решений, есть еще дополнительный механизм ребалансировки пулов, на случай если будет найдена возможность арбитража в cow amm пуле.

Off-chain инфраструктура регулярно мониторит цены на токены через oracle (chainlink, uniswap pools, balancer pools) и как только цена одного из токенов в cow amm pool будет отличаться от других источников ликвидности, то протокол сам создает order для ребалансировки пула, т. е. то что раньше делали арбитражеры, теперь будет делать solver, через книгу ордеров к которой они имеют доступ.

Схему примерной работы можно посмотреть ниже:

```mermaid
sequenceDiagram
    participant Monitor as  Off-chain Monitor
    participant ExternalSources as 📊 External Sources<br/>(Chainlink, Uniswap, Balancer)
    participant CoWAMM as 🐄 CoW AMM Pool
    participant OrderBook as 📚 OrderBook
    participant Solvers as 🔧 Solvers
    participant Winner as 🏆 Winner Solver
    participant LP as 💰 LP

    Note over Monitor, LP: Auto-Rebalancing Mechanism
    
    loop Continuous Monitoring
        Monitor->>ExternalSources: Query token prices<br/>Chainlink, Uniswap pools, Balancer
        ExternalSources-->>Monitor: Return current market prices<br/>ETH: $3000, USDC: $1
        
        Monitor->>CoWAMM: Check pool token prices<br/>Compare with external sources
        CoWAMM-->>Monitor: Return pool prices<br/>ETH: $2950 (underpriced!)
        
        Monitor->>Monitor: Calculate price deviation<br/>ETH price gap: $50 ($3000 vs $2950)
    end
    
    alt Price Deviation Detected
        Monitor->>Monitor: Arbitrage opportunity found!<br/>ETH underpriced in CoW AMM
        
        Monitor->>OrderBook: Generate rebalance order<br/>
        
        OrderBook->>Solvers: Send rebalance opportunity<br/>
        
        Solvers->>OrderBook: Submit arbitrage solutions<br/>Compete for execution
        OrderBook->>Winner: You won! Execute arbitrage
        
        Winner->>CoWAMM: commit(rebalanceOrderHash)
        Winner->>CoWAMM: verify(rebalanceOrder)
        Winner->>CoWAMM: isValidSignature(hash, signature)
        Winner->>CoWAMM: Execute arbitrage trade<br/>Buy underpriced ETH
        
        Winner->>ExternalSources: Sell ETH at market price<br/>Capture price difference
        
        CoWAMM->>LP: 💰 Arbitrage profit → LP<br/>Pool rebalanced
        
        Note over Monitor, LP: Result: MEV captured by protocol,<br/>not external bots. LP earns profit!
        
    else No Price Deviation
        Note over Monitor, LP: Continue monitoring...<br/>No action needed
    end
```

## Смарт-контракты

В Cow Protocol всего 3 контракта входят в core, т.е без которых он не может работать:

- **GPv2Settlement**
- **GPv2VaultRelayer**
- **GPv2AllowlistAuthentication**

Так же есть periphery контракты, которые не являются обязательными, но обеспечивают дополнительный функционал:
- **Eth-flow** ([GitHub](https://github.com/cowprotocol/ethflowcontract)) - контракт который обеспечивает поддержку торговли в нативном токене ETH. Он работает промежуточный контракт который оборачивает ETH в WETH и создает intent от имени юзера.
- **HooksTrampoline** ([GitHub](https://github.com/cowprotocol/hooks-trampoline)) - контракт для выполнения CoW Hooks. Выполняет произвольные внешние вызовы (pre-hooks и post-hooks) в контексте ордеров, обеспечивая дополнительную функциональность до и после свапов.
- **ComposableCoW** ([GitHub](https://github.com/cowprotocol/composable-cow)) - framework для создания программируемых смарт-ордеров с условной логикой. Позволяет создавать автономные торговые стратегии (например, TWAP ордера, лимитные ордера с условиями, ребалансировка портфеля).
- **CoWUidGenerator** - вспомогательный контракт для расчета того же хеша подписи EIP-712 для заданного заказа пользователя, который ожидает `GPv2SettlementContract` контракт.
- **Flash loans** ([GitHub](https://github.com/cowprotocol/flash-loan-router)) - специализированный роутер для выполнения flash loans в рамках CoW Protocol. Позволяет solvers брать flash loans от различных провайдеров (поддерживающих ERC-3156) для выполнения арбитража и сложных DeFi стратегий без залога.

Рассмотрим только core контракты:

**GPv2Settlement** ([Github](https://github.com/cowprotocol/contracts/blob/main/src/contracts/GPv2Settlement.sol)) - Самый главный контракт, который принимает от solver данные intentions и действий с ними для выполнения в транзакции.

**Главные функции контракта:**

- **`settle()`** - основная функция для исполнения пакета ордеров (только для авторизованных solvers)
  - Валидирует подписи пользователей и проверяет сроки действия ордеров
  - Контролирует лимитные цены и статус заполнения ордеров  
  - Выполняет взаимодействия с внешней ликвидностью через массив interactions
  - Переводит токены через GPv2VaultRelayer и отправляет результаты пользователям

- **`swap()`** - прямой обмен токенов через пулы Balancer
- **`setPreSignature()`** - активирует/деактивирует ордер on-chain
- **`invalidateOrder()`** - отменяет ордер on-chain



Для чего это нужно?

Все на самом деле очень просто:

- `setPreSignature` Необходима для смарт-контрактов, не реализующих интерфейс ERC-1271. Так как смарт-контракт не имеет приватного ключа, чтобы подписать ордер. Этот метод требует on-chain транзакции и оплаты газа, его можно использовать как для EOA, так и для смарт-контрактных кошельков.

- `invalidateOrder`: Помечает ордер как недействительный, т. к. off-chain отмена может не успеть сработать до его выполнения из-за задержек в off-chain архитектуре.

Пример использования `setPreSignature`:

1. EOA:

Возможен сценарий, когда трейдер захочет вначале внести ордер офф-чейн, а потом, имея торговую стратегию, которая была дала профит, активировал данный ордер on-chain через какого-то бота.

2. Смарт аккаунт:

Представим DAO с мультисиг-кошельком Gnosis Safe, которому необходимо обменять 100000 USDT на ETH.

Администратор DAO создает ордер через API CoW Protocol (получает взамен ID ордера) и размещает его в виде предложения к голосованию. После прохождения голосования, выполняется транзакция c `setPreSignature(orderId, true)`, которая активирует ордер. Таким образом ордер считается подписанным и попадает в пакет аукционов.

**GPv2VaultRelayer** ([Github](https://github.com/cowprotocol/contracts/blob/main/src/contracts/GPv2VaultRelayer.sol)) - Контракт-посредник для безопасного доступа к средствам пользователей и интеграции с Balancer Vaults. Обеспечивает три способа доступа к токенам: прямые ERC-20 переводы с внешних кошельков юзера, внешние балансы Balancer и внутренние балансы Balancer.

Через функцию `transferFromAccounts` происходит трансфер токенов в через один из способов: напрямую с кошелька, с внешнего баланса в balancer vault, с внутреннего баланса balancer vault.

Разберем эти способы:

- **Прямые ERC-20 одобрения**: Стандартные одобрения (approve) напрямую на адрес GPv2VaultRelayer
- **Внешние балансы Balancer**: Использует существующие ERC-20 одобрения пользователя для Balancer Vault
- **Внутренние балансы Balancer**: Использует внутренние балансы в Balancer для газово-эффективных переводов

С первым пунктом все понятно, как и в обычном DEX нужно дать апрув на токен который списывают, а вот два последних пункта разберем чуть позже.

**GPv2AllowlistAuthentication** ([Github](https://github.com/cowprotocol/contracts/blob/main/src/contracts/GPv2AllowListAuthentication.sol)) - контракт авторизации, который проверяет, является ли solver авторизованным при вызове метода `settle` на контракте **GPv2Settlement**.

Управляется через CoW DAO, что обеспечивает децентрализованный контроль.

Таким образом, процесс выполнения пакета intentions выглядит так:

**Процесс выполнения пакета intentions**:
1. Solver вызывает функцию `settle()` в GPv2Settlement, предоставляя:
   - Список токенов
   - Рассчитанные единые цены для каждого токена
   - Массив ордеров для исполнения
   - Набор взаимодействий с внешней ликвидностью
   
2. GPv2Settlement выполняет проверки:
   - GPv2AllowlistAuthentication подтверждает авторизацию solver
   - Проверяется каждый ордер (срок действия, подпись, статус заполнения)
   - Проверяется соблюдение лимитных цен для каждого ордера
   
3. Если все проверки прошли успешно:
   - Выполняются предварительные взаимодействия (pre-hooks)
   - GPv2VaultRelayer переводит токены от пользователей
   - Выполняются основные взаимодействия с внешней ликвидностью
   - Пользователи получают купленные токены
   - Выполняются завершающие взаимодействия (post-hooks)
   - Обновляется статус заполнения ордеров

Получается, что solver отвечает за нахождение оптимального решения, а смарт-контракты обеспечивают строгий контроль исполнения ордеров.

## Интеграции с другими протоколами

Важно понимать, что CoW Protocol может использоваться и другими приложениями.

Например, [Balancer](https://balancer.gitbook.io/balancer-v2/products/balancer-cow-protocol) в 2021 году интегрировал протокол в свой интерфейс, создав Balancer-CoW-Protocol (BCP).

**Интеграция с Balancer: архитектура безопасности**

CoW Protocol работает в сотрудничестве с [Balancer](https://balancer.fi/) для достижения максимальной прибыли для пользователей и обеспечения дополнительной безопасности.

Следует напомнить, что ключевой элемент этого партнерства - контракт **GPv2VaultRelayer**, который служит критическим компонентом безопасности. Его главная гарантия: **GPv2VaultRelayer может передавать токены ERC-20 ТОЛЬКО контракту GPv2Settlement**.

Это архитектурное решение защищает средства пользователей от потенциально злонамеренных solvers. Если бы пользователи давали разрешения напрямую контракту GPv2Settlement, злонамеренный solver мог бы через механизм "взаимодействий" получить доступ к средствам пользователей. В коде GPv2Settlement есть явный запрет на вызов VaultRelayer через interactions `(require(interaction.target != address(vaultRelayer), "GPv2: forbidden interaction"))`, который дополнительно гарантирует, что даже злонамеренный solver не сможет напрямую взаимодействовать с контрактом, хранящим разрешения пользователей.

Механизм "взаимодействий" (interactions) - это конкретный параметр функции `settle()` контракта GPv2Settlement, который позволяет solvers передавать произвольные вызовы к внешним смарт-контрактам. Технически это массив байт-кода (`bytes[] calldata interactions`), который solver может заполнить любыми вызовами к другим протоколам

Эти взаимодействия нужны для маршрутизации средств через различные DEX (Uniswap, Curve, Balancer) или агрегаторы (1inch, Paraswap) с целью получения лучших цен.

Критически важно понимать, что:

1. Взаимодействия **не являются частью** подписанных пользователем данных ордера
2. Они полностью контролируются solver в момент исполнения транзакции
3. В них могут содержаться любые вызовы к любым контрактам в блокчейне

Здесь и возникает уязвимость: если бы пользователь давал approve напрямую контракту GPv2Settlement, а solver был злонамеренным, он мог бы добавить в массив interactions вызовы, которые переводят токены куда угодно. Архитектура с GPv2VaultRelayer решает эту проблему, ограничивая поток средств:

1. Токены могут быть переведены **только** на контракт GPv2Settlement
2. GPv2Settlement может использовать токены только в рамках текущей транзакции
3. Даже при взломе GPv2Settlement, злоумышленник не сможет вывести средства за границы существующих контрактов

Таким образом система сохраняет гибкость маршрутизации, но исключает возможность кражи средств через вредоносные взаимодействия.

**Пример движения средств:**

Допустим, пользователь хочет продать 100 USDC за минимум 0.05 ETH:

1. **С архитектурой VaultRelayer (безопасно):**
   - Пользователь даёт approve на 1000 USDC контракту VaultRelayer
   - VaultRelayer переводит только 100 USDC на Settlement (только то, что указано в ордере)
   - Settlement обменивает 100 USDC на 0.053 ETH через взаимодействия с DEX
   - Пользователь получает 0.053 ETH минус комиссия
   - Оставшиеся 900 USDC остаются недоступными для Settlement и безопасными

2. **Без VaultRelayer (небезопасно):**
   - Если бы пользователь дал approve напрямую Settlement
   - Злонамеренный solver мог бы вообще не исполнять ордер через DEX, а вместо этого:
     - Добавить в массив interactions вызов `USDC.transferFrom(пользователь, злоумышленник, 100)` для кражи самой обменной суммы
     - Никогда не отправлять пользователю обещанные ETH
     - Плюс мог бы добавить `USDC.transferFrom(пользователь, злоумышленник, 900)` для кражи оставшихся средств
   - Все это возможно, потому что solver полностью контролирует содержимое массива interactions

Этот пример демонстрирует, почему архитектура с VaultRelayer является критически важным элементом безопасности в CoW Protocol. VaultRelayer не только ограничивает сумму, доступную для ордера, но и гарантирует, что даже эта сумма может быть переведена только на контракт Settlement, где действуют строгие проверки правильного исполнения ордера.

Давайте все же перейдем к вопросу выгоды интеграции с Balancer.

**Преимущества для Balancer**: Balancer получает дополнительный торговый интерфейс без необходимости разрабатывать собственный. Его пользователи получают защиту от MEV, доступ к улучшенным ценам и газово-эффективную торговлю без необходимости взаимодействовать с новым протоколом. Это увеличивает объем торгов в пулах Balancer и, соответственно, комиссии для поставщиков ликвидности, сохраняя при этом пользователей в экосистеме Balancer.

**Преимущества для CoW Protocol**: CoW Protocol получает привилегированный доступ к ликвидности Balancer, оптимизацию газа через внутренние балансы Vault, и возможность переиспользовать уже выданные пользователями апрувы на Balancer Vault. Это значительно снижает барьер входа для миллионов пользователей Balancer и расширяет пользовательскую базу протокола. Дополнительно, упрощается пользовательский путь и повышается безопасность, так как пользователи могут управлять всеми разрешениями через единый интерфейс Balancer.

Важно понимать принципы работы балансов в Balancer:

> **Внешние балансы Balancer** - это стандартные ERC-20 токены, которые находятся на адресах пользователей. Для работы с ними пользователь дает разрешение (approve) контракту Balancer Vault на использование этих токенов. Это классический способ управления токенами в большинстве DeFi протоколов.

>**Внутренние балансы Balancer** - это учетная система внутри контракта Balancer Vault, которая отслеживает количество токенов, принадлежащих каждому пользователю, без необходимости выполнять последующие реальные ERC-20 переводы. Пользователь должен заранее "депонировать" токены во внутренние балансы Vault, после чего их можно использовать с минимальными затратами газа.

**Доступ к средствам пользователей** осуществляется тремя способами:

- **Прямые ERC-20 одобрения**: Стандартные одобрения (approve) напрямую на адрес GPv2VaultRelayer (ранее о нем рассказывали)
- **Внешние балансы Balancer**: Использует существующие ERC-20 одобрения пользователя для Balancer Vault
- **Внутренние балансы Balancer**: Использует внутренние балансы в Balancer для газово-эффективных переводов

**Использование внешних балансов Balancer:**

Требуется две независимые формы авторизации:

1. **Протокольный уровень**: GPv2VaultRelayer авторизован в Balancer как официальный релейер через голосование Balancer DAO (уже реализовано на уровне протокола).
![alt text](./img/authorize.png)

2. **Пользовательский уровень**: Для использования этого механизма требуется:
   - Пользователь уже имеет стандартное ERC-20 одобрение (approve) для контракта Balancer Vault
   - Пользователь дополнительно одобряет GPv2VaultRelayer как доверенный релейер через специальную функцию `setRelayerApproval` в Balancer Vault

![alt text](./img/external.png)

При исполнении ордера с использованием внешних балансов Balancer процесс происходит так:
1. GPv2Settlement вызывает GPv2VaultRelayer
2. GPv2VaultRelayer запрашивает у Balancer Vault перевод токенов от пользователя
3. [Balancer Vault](https://github.com/balancer/balancer-v2-monorepo/blob/master/pkg/vault/contracts/Vault.sol) проверяет:
   - Что GPv2VaultRelayer авторизован на протокольном уровне
   - Что пользователь дал релейеру специальное разрешение через setRelayerApproval
4. После проверок Balancer Vault использует свое существующее ERC-20 одобрение для перевода токенов

**Использование внутренних балансов Balancer:**

Третий механизм доступа к средствам пользователя:

1. **Требования для использования:**
   - Пользователь должен иметь внутренние балансы токенов в Balancer Vault
   - Пользователь должен одобрить GPv2VaultRelayer как релейер так же, как и для внешних балансов
   - В ордере флаг `sellTokenBalance` должен быть установлен в значение `internal`

![alt text](./img/internal.png)

2. **Преимущества:**
   - Значительная экономия газа при исполнении ордеров
   - Возможность получить торговые результаты тоже во внутренних балансах, установив флаг `buyTokenBalance` в значение `internal`
   - Свободный обмен между внутренними балансами и стандартными ERC-20 токенами в любой момент

Пользователь может в любой момент вывести внутренние балансы из Balancer Vault в виде обычных ERC-20 токенов.

Это обеспечивает три ключевых преимущества:
- Переиспользование существующих ERC-20 одобрений Balancer Vault (не нужны новые одобрения специально для CoW Protocol)
- Вместо того чтобы раздавать approve каждому контракту на каждый токен, вы один раз даете разрешение GPv2VaultRelayer через `setRelayerApproval`, и если захотите - можете одной транзакцией его отозвать. Это удобнее, безопаснее и контролируемо
- Approve GPv2VaultRelayer можно отозвать одной транзакцией в Balancer Vault, вместо того чтобы отзывать approve отдельно у каждого ERC-20 токена

Получается, что даже при компрометации контракта Settlement, VaultRelayer не позволит выполнить произвольные действия со средствами благодаря архитектуре с двойной авторизацией и ограниченной функциональностью.

Если говорить простыми словами, партнерство между CoW Protocol и Balancer - это как дружба между двумя соседями, где каждый получает свою выгоду. Balancer не нужно создавать собственную торговую систему с нуля - он просто использует инфраструктуру CoW Protocol, предлагая своим пользователям защиту от фронтраннеров и лучшие цены. А CoW Protocol в свою очередь получает доступ к огромной базе пользователей Balancer и их ликвидности.

Главная фишка этой интеграции - безопасность. Представьте, что VaultRelayer - это надежный охранник, который стоит между вашими средствами и протоколом. Он проверяет все запросы дважды и переводит только те токены, которые вы реально хотите обменять. Даже если главный контракт будет взломан, ваши оставшиеся средства в безопасности - ведь охранник не позволит перевести больше, чем нужно для конкретной сделки.

Для пользователей это еще и удобно: вместо того чтобы давать десятки отдельных разрешений на каждый токен, вы даете одно общее разрешение через Balancer, и можете в любой момент отозвать его одной транзакцией. Это как иметь один мастер-ключ вместо связки из десятков ключей.

## Ограничения и вызовы протокола

CoW Protocol - хороший протокол, но у него есть свои ограничения:

**Задержки при исполнении**
В отличие от обычных DEX, где сделки проходят мгновенно, в CoW Swap процесс занимает от нескольких секунд до 30 секунд из-за формирования пакета, поиска оптимального решения и проведения аукциона между solvers.

**Зависимость от внешней инфраструктуры**
Система опирается на работу off-chain стороны, solvers и API-сервисов. Если какой-то из этих компонентов откажет, создать новые ордера будет невозможно.

**Высокий порог входа для solvers**
Хотя теоретически стать solver может любой, на практике для этого требуется внушительный залог и серьезные технические навыки. Это создает риск централизации - в системе может остаться всего несколько крупных solvers.

**Неравномерная эффективность**
Протокол наиболее эффективен при высокой активности и ликвидности. Для редких токенов или в периоды низкой торговой активности преимущества системы могут быть не так заметны.

## Инциденты безопасности

В феврале 2023 года был небольшой инцидент - хакер украл около $166K из контракта расчетов. Но есть две хорошие новости:

1. **Деньги пользователей были в полной безопасности.** CoW Swap устроен так, что ваши средства никогда не хранятся в протоколе - все сделки выполняются мгновенно и напрямую.

2. **Украденные деньги удалось вернуть** благодаря залогу, который вносят solvers.

Что случилось? Если коротко:
- Один из solvers создал контракт с уязвимостью
- Хакер нашел эту уязвимость и воспользовался ею для кражи токенов DAI
- Команда быстро отреагировала и закрыла уязвимость

Что сделали с проблемой:
- Отключили проблемный контракт
- Solver обновил свой код
- Solver был временно отключен от системы и оштрафован

Система сработала именно так, как и была задумана - залоги solvers выступили в роли страховки и позволили компенсировать потери.

Если вам интересны детали, их можно прочитать в [официальном разборе инцидента](https://cow.fi/learn/cow-swap-solver-exploit-post-mortem).

## Заключение

CoW Protocol представляет собой огромный вклад в децентрализованную торговлю, объединяя лучшее от централизованных и децентрализованных бирж через intentions, пакетные аукционы и solvers.

Протокол обеспечивает **экономическую эффективность** через прямые обмены между пользователями (CoW), которые экономят комиссии и газ, а конкуренция solvers с агрегацией ликвидности гарантирует лучшие цены. Пользователи могут оплачивать комиссию за газ в своих токенах продажи без необходимости держать нативный токен блокчейна в кошельке, а неудавшиеся транзакции не требуют оплаты газа.

**Безопасность** достигается через пакетные аукционы и единые цены, защищающие от фронтраннинга и сэндвич-атак. К тому же, многие solvers используют MEV Blocker, что дополнительно улучшает защиту а также добавляет surplus для пользователей.

**Удобство использования** включает гибкую архитектуру с поддержкой различных типов ордеров, возможность размещать несколько заказов одновременно и intent-based торговлю - достаточно указать желаемый результат, и solver найдет оптимальный путь.

CoW Protocol не просто решает проблемы существующих DEX, но создает принципиально новую парадигму торговли, где пользователи получают лучшие цены, полную защиту от MEV и максимальное удобство использования.

CoW Protocol показывает, что децентрализованная торговля может быть эффективной и безопасной. Система создаёт правильные стимулы - чем больше выгода для пользователя, тем больше для solver. А CoW Swap, в свою очередь, делает эту сложную технологию доступной через удобный и понятный интерфейс.

## Ссылки

- [CoW Protocol (официальный сайт)](https://cow.fi/)
- [CoW Swap (интерфейс протокола)](https://cow.fi/cow-swap)
- [Документация CoW Protocol](https://docs.cow.fi/)
- [GitHub: CoW Protocol](https://github.com/cowprotocol)
- [Форум CoW DAO](https://forum.cow.fi/)
- [Discord](https://discord.gg/cowprotocol)
- [Smart-contracts repo](https://github.com/cowprotocol/contracts/tree/main)
- [Cow AMM](https://medium.com/taipei-ethereum-meetup/understanding-cow-amm-a-zero-swap-fee-mev-mitigating-liquidity-source-for-cowswap-25f8cb1e8b78)
- [FM-AMM formula](https://medium.com/taipei-ethereum-meetup/eli5-what-is-fm-amm-the-theory-behind-cow-amm-and-how-is-it-mev-resistant-53d1960324c0)