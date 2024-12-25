# EIP-712: Typed structured data hashing and signing

**Автор:** [Павел Найданов](https://github.com/PavelNaydanov) 🕵️‍♂️

EIP-712 - это стандарт для хеширования и подписи типизированных данных, который, по совместительству, описывает спецификацию одной из версий подписи согласно [EIP-191](https://eips.ethereum.org/EIPS/eip-191)

Согласно EIP-191 подпись формируется следующим образом:
```js
0x19 <1 byte version> <version specific data> <data to sign>.
```

Для того, чтобы указать в подписи, что будет использоваться стандарт EIP-712 необходимо за место `<1 byte version>` указать `0x01`.

// TODO: по сути это то, от чего подпись должна защищать и что дает стандарт EIP-712
### Подпись не защищена от повторного использования
### Подпись не защищена от использования в разных сетях
### Подпись не защищена от использования в разных функциях смарт-контракта
### Подпись не защищена от использования в разных протоколах сети

## Как можно реализовать отмену подписи

// TODO: можно просто увеличить nonce.
https://solodit.cyfrin.io/issues/l-05-permit-signatures-cannot-be-canceled-before-deadlines-pashov-audit-group-none-titanx-markdown

## Топ ошибок на смарт-контрактах

### Использование abi.encode вместо abi.encodePacked для генерации TYPEHASH
// TODO
https://solodit.cyfrin.io/issues/m-11-protocol-does-not-implement-eip712-correctly-on-multiple-occasions-code4rena-renft-renft-git

### Пропуск полей описанных в TYPEHASH при кодировании
// TODO
https://solodit.cyfrin.io/issues/m-11-protocol-does-not-implement-eip712-correctly-on-multiple-occasions-code4rena-renft-renft-git
https://solodit.cyfrin.io/?i=HIGH%2CMEDIUM&t=Signature+Malleability%2CEIP-712&f=&pc=&ff=&fc=gte&fn=1&b=false&r=all

### Ошибка кодирования динамических типов
// TODO: bytes
// TODO: string
https://solodit.cyfrin.io/issues/m-11-protocol-does-not-implement-eip712-correctly-on-multiple-occasions-code4rena-renft-renft-git

### Ошибка кодирования reference types
Неправильное кодирование вложенной структуры
https://solodit.cyfrin.io/?i=HIGH%2CMEDIUM&t=Signature+Malleability%2CEIP-712&f=&pc=&ff=&fc=gte&fn=1&b=false&r=all

### Пропуск TYPEHASH
https://solodit.cyfrin.io/issues/m-11-protocol-does-not-implement-eip712-correctly-on-multiple-occasions-code4rena-renft-renft-git

// TODO
1. OpenZeppelin has a vulnerability in versions lower than 4.7.3, which can be exploited by an attacker. The project uses a vulnerable version
  https://github.com/OpenZeppelin/openzeppelin-contracts/security/advisories/GHSA-4h98-2769-gh6h
2.

### Подпись не защищена от повторного использования
// TODO: две ссылки было
https://solodit.cyfrin.io/issues/reuse-of-guardian-signatures-for-pausing-deposits-mixbytes-none-lido-markdown
https://solodit.cyfrin.io/issues/l-05-signatures-do-not-expire-and-cannot-be-canceled-pashov-audit-group-none-groupcoin-markdown

### Подпись может быть перехвачена и использована другим адресом
https://solodit.cyfrin.io/issues/h-01-signatures-can-be-replayed-using-different-addresses-pashov-audit-group-none-sofamon-august-markdown