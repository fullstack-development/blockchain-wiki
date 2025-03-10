# Uniswap v4

**Автор:** [Павел Найданов](https://github.com/PavelNaydanov) 🕵️‍♂️

// TODO: вводная про Uni

## Полезные фичи

**Хуки**

Разработчики могут добавлять собственную логику к работе Uniswap. Логика выполняется до и после операций Uniswap. Под операциями можно понимать привычные нам процессы: создание пула, добавление или удаление ликвидности, свапы.

Хук - это внешний смарт-контракт, который прикрепляется к пулу.

> Один пул - один прикрепленный хук, но хук может быть завязан на работу с неограниченным количеством пулов. Это означает, что действие в привязанном пуле тригерит хук, а дальше он под капотом использует другие пулы.

Initialize Hooks:
- beforeInitialize: Called before a new pool is initialized.
- afterInitialize: Called after a new pool is initialized.
These hooks allow developers to perform custom actions or validations during pool initialization, but these hooks can only be invoked once.

Liquidity Modification Hooks:
The liquidity modification hooks are extremely granular for security purposes.

- beforeAddLiquidity: Called before liquidity is added to a pool.
- afterAddLiquidity: Called after liquidity is added to a pool.
- beforeRemoveLiquidity: Called before liquidity is removed from a pool.
- afterRemoveLiquidity: Called after liquidity is removed from a pool.

Swap Hooks:
- beforeSwap: Called before a swap is executed in a pool.
- afterSwap: Called after a swap is executed in a pool.

Donate Hooks:
- beforeDonate: Called before a donation is made to a pool.
- afterDonate: Called after a donation is made to a pool.
Donate hooks provide a way to customize the behavior of token donations to liquidity providers.


// TODO: Хуки являются контрактами?
Что-то я не понимаю, это один хук контракт на пул или нет
// TODO: пахнет схемой

**Singleton Design"**

Вводится новая архитектура под названием "Singleton Design", которая подразумевает всю реализацию на одном смарт-контракте [PoolManager.sol](https://github.com/Uniswap/v4-core/blob/main/src/PoolManager.sol). Этот смарт-контракт описывает логику по управлению пулами и операциями. Такой подход позволяет экономить на газе при создании пулов.

*Создание всех пулов на одном смарт-контракте обходится дешевле чем создание отдельных смарт-контрактов под каждый пул (так было в Uniswap v2, Uniswap v3).*

**Flash Accounting**

Использование EIP-1153 Transient Storage позволяет более эффективного проводить операции. происходит это за счет того, что **Transient Storage** используется, как хранилище для промежуточных операций, а состояние блокчейна меняется только по результатам проведения всех операций. Таким образом пользователь платит за финализацию цепочки своих операций.

**Нативный эфир**

Поддерживается нативный эфир без необходимости использовать обертки по типу WETH. // TODO: ссылка на WETH.

**Dynamic fees**

Динамические комиссии теперь могут изменяться на пулах: увеличиваться или уменьшаться. Обновление комиссии может происходить каждые свап, блок или по расписанию раз в неделю, месяц и так далее.

// TODO: https://docs.uniswap.org/contracts/v4/concepts/dynamic-fees

**Custom Accounting**

Гибкость принесенная Uniswap v4 при помощи хуков открывает новое пространство для настройки свапов и модификаций ликвидности. Речь идет, как о динамических комиссиях, так и использования собственной кривой для ценообразования.

**Subscribers**

Позволяет поставщикам ликвидности подписываться на смарт-контракт, который получает нотификации.

// TODO: пока не понимаю, как это работает
Доступны нотификации:
- The position is initially subscribed
- The position increases or decreases its liquidity
- The position is transferred
- The position is unsubscribed

## Архитектура

// TODO: У нас все равно есть core, perephiry, universal router и есть нюанс, что теперь в разных сетях жто могут быть разные адреса контрактов

При помощи инкапсуляции логики в `PoolManager.sol` достигаются следующие цели:
- эффективное управление ликвидностью
- обмен токенов
- уменьшение затрат на газ
- улучшение расширяемости за счет хуков

// TODO:

Для управления ликвидностью функция.
`modifyLiquidity()`

// TODO: Locking механизм для flash Accounting

// TODO: Три библиотеки:
- Pool: Contains core pool functionality, such as swaps and liquidity management
- Hooks: Handles the execution of hook functions
- Position: Manages liquidity positions within a pool


## ERC-6909

// TODO: Закончить

Этот стандарт токена, который является альтернативным для ERC-1155.

Преимущества
- Simplified interface: ERC-6909 removes unnecessary safe transfer callbacks and batching constraints presented in ERC-1155.
- Improved transfer delegation: ERC-6909 provides a more efficient system for transfer delegation.
- Gas efficiency: ERC-6909 reduces gas costs for deployment, transfers, and burning operations.
- Reduced code size: Implementing ERC-6909 results in smaller contract sizes compared to ERC-1155.

However, it's worth noting that ERC-6909 does introduce a totalSupply variable, which leads to an additional disk write on mint and burn operations.

## Вывод

Uniswap V4 - это следующая стадия в эволюции AMM. Новая архитектура устраняет многие ограничения предыдущих версий и предоставляет новый уровень масштабирования. Теперь Uniswap не просто dex, а полноценная кодовая база для построения децентрализованных финансовых приложений.

## Links

1. [Официальная документация](https://docs.uniswap.org/contracts/v4/overview)