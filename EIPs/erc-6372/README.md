# ERC-6372: Contract clock

**Автор:** [Найданов Павел](https://github.com/PavelNaydanov) 🕵️‍♂️

_Важно!_ На момент написания статьи, стандарт находился на стадии "**Review**".

Этот EIP предлагает стандартный интерфейс для контрактов, чтобы реализовать "**часы**" внутри смарт-контракта. **Под часами** понимается любая бизнес логика смарт-контракта, завязанная на хранение или проверку времени.

Обычно, внутри смарт-контракта, для работы со временем, в коде используются [свойства блока](https://docs.soliditylang.org/en/latest/units-and-global-variables.html#block-and-transaction-properties): `block.timestamp`- время текущего блока в секундах или `block.number` - номер текущего блока. Стандарт предлагает унифицировать этот опыт.

## Реализация стандарта

Для использования стандарта достаточно реализовать в своем контракте интерфейс, который будет содержать всего две функции: `clock()` и `CLOCK_MODE()`.

```solidity
interface IERC6372 {
  function clock() external view returns (uint48);
  function CLOCK_MODE() external view returns (string);
}
```

### CLOCK_MODE()

Функция `CLOCK_MODE()` должна возвращать **режим**. Режим определяет механизм для  использования времени на контракте. Логика смарт-контракта может быть завязана на `block.timestamp`, `block.number` или другой вариант собственной реализации привязки ко времени.

**Примеры, возвращаемого значения:**

- Контракт использует номер блока
  > Если используется номер блока на базе кода операции EVM "NUMBER" ([0x43](https://www.evm.codes/#43?fork=shanghai)) => **mode=blocknumber&from=default**
  > Если используется номер блока на базе другого блокчейна => **mode=blocknumber&from=[CAIP-2-ID]**, где [CAIP-2-ID] — идентификатор блокчейна [CAIP-2](https://github.com/ChainAgnostic/CAIPs/blob/main/CAIPs/caip-2.md), например eip155:1
- Контракт использует timestamp
  > **mode=timestamp**
- Контракт использует другой режим
  > **mode=[Любое название режима]**

### clock()

Функция `clock()` должна возвращать значение текущего времени на смарт-контракте для установленного **режима** (CLOCK_MODE). Это может быть любое целочисленное значение, которое может определять номер блока, timestamp и тому подобное.

_Важно!_ Функция `clock` возвращает `uint48`.

Авторы стандарта считают, что для возвращаемого значения достаточно типа `uint48`. Они приводят расчеты для режима **timestamp**. При скорости создания 10 000 блоков в секунду, размера возвращаемого значения будет достаточно до 2861 года. Использование типа меньше, чем `uint256` значительно сокращает стоимость записи и чтения из хранилища, что позволяет экономить на газе.

## Применение

Авторами стандарта являются разработчики, которые трудятся над библиотекой [OpenZeppelin](https://www.openzeppelin.com/). Поэтому и применяется стандарт, в первую очередь, для контрактов библиотеки.

Например, для **governance** стандарт реализован начиная с версии 4.9.0. Найти можно в расширение [GovernorVotes](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/governance/extensions/GovernorVotes.sol) для контракта Governor.

```solidity
function clock() public view virtual override returns (uint48) {
    try token.clock() returns (uint48 timepoint) {
        return timepoint;
    } catch {
        return SafeCast.toUint48(block.number);
    }
}
```
Этот кусочек кода завязан на вызов функции `clock()` контракта токена голосования. Для того, чтобы понять что из себя представляет возвращаемое значение `timepoint`, необходимо посмотреть расширение [ERC20Votes](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/token/ERC20/extensions/ERC20Votes.sol) контракта ERC-20.Этот расширение делает из обычного токена - токен для голосования и реализует интерфейс ERC-6372. То, ради чего мы тут и собрались. 😅

```solidity
/**
  * @dev Clock used for flagging checkpoints.
  * Can be overridden to implement timestamp based checkpoints (and voting).
  */
function clock() public view virtual override returns (uint48) {
    /// Возвращает текущий номер блока
    return SafeCast.toUint48(block.number);
}

/**
  * @dev Description of the clock
  */
function CLOCK_MODE() public view virtual override returns (string memory) {
    /// Проверяет, что стандарт не переопределен и работает, как ожидалось
    require(clock() == block.number, "ERC20Votes: broken clock mode");

    /// Возвращает установленный режим для часов, который указывает на работу с номером блока
    return "mode=blocknumber&from=default";
}
```

В глобальном концепте **governance**, функции "часов" участвует в реализации механизма **snapshot**. Механизм запоминает количество доступных голосов пользователей с привязкой к текущему номеру блока. Это позволяет пользователю голосовать за новые предложения в системе **governance**, где сначала будет проверено, что на момент старта голосования у пользователя достаточно токенов для голосования.


## Links

1. [ERC-6372: Contract clock](https://eips.ethereum.org/EIPS/eip-6372)
2. [ERC20 Votes: ERC5805 and ERC6372](https://www.rareskills.io/post/erc20-votes-erc5805-and-erc6372)