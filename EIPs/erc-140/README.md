# EIP-140: REVERT instruction

**Автор:** [Павел Найданов](https://github.com/PavelNaydanov) 🕵️‍♂️

Стандарт EIP-140 предлагает добавить инструкцию `REVERT` которая нашла широкое применение в смарт-контрактах на языке solidity. Использование этой инструкции позволяет **остановить** выполнение, **отменить** изменение состояния блокчейна и **вернуть** причину остановки.

_Знаете ли вы!?_ Инструкция `REVERT` была предложена только 6 февраля 2017 года. До этого момента подобной инструкции не существовало.

До внедрения стандарта разработчики использовали `assert()` для того, чтобы откатить выполнение транзакции при наступление некоторого условия. В отличие от `REVERT`, использование `assert()` потребляло весь оставшийся газ, независимо от места вызова в коде.

Инструкция `REVERT` представлена кодом операции [`0xfd`](https://www.evm.codes/#fd?fork=shanghai). Этот код операции принимает два параметра, которые находятся последними в стеке:
- **offset**. Смещение в памяти, указывающее на возвращаемые данные
- **size**. размер возвращаемых данных

_Важно!_ Семантически использование `REVERT` относительно памяти и стоимости памяти идентично инструкции `RETURN` и принимает одинаковые параметры.

### Варианты использования revert в коде solidity

Возврат транзакции без информации об ошибке:

```solidity
function withdraw(uint256 amount) external {
    if (_balance < amount) {
      revert();
    }
    ...
}
```

Возврат транзакции с указанием текстовой ошибки:

```solidity
function withdraw(uint256 amount) external {
    if (_balance < amount) {
      revert("Insufficient amount");
    }
    ...
}
```

Возврат транзакции с использованием [кастомной ошибки](https://soliditylang.org/blog/2021/04/21/custom-errors/):

```solidity
error InsufficientAmount();

function withdraw(uint256 amount) external {
    if (_balance < amount) {
      revert InsufficientAmount();
    }
    ...
}
```

## Links

1. [EIP-140: REVERT instruction](https://eips.ethereum.org/EIPS/eip-140)
2. [Документация](https://docs.soliditylang.org/en/v0.8.23/control-structures.html#revert) solidity по инструкции revert()
3. Для тех кому интересна [история](https://github.com/ethereum/EIPs/pull/206/commits) обсуждения внедрения EIP