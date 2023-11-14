# ERC-1363: Payable Token

**Автор:** [Найданов Павел](https://github.com/PavelNaydanov) 🕵️‍♂️

Стандарт ERC-1363 реализует расширение токена ERC-20 для выполнения кода сразу после вызова ```transfer()```, ```transferFrom()``` или ```approve()``` в рамках одной транзакции. Этот стандарт помогает избежать двойной оплаты за газ, так как дополнительный вызов происходит в рамках одной транзакциям с трансфером токена или апрувом.

_Важно !_ Стандарт ERC-1363 является расширением стандарта ERC-20 и полностью обратно совместимым. То есть он не переопределяет стандартные функции ```transfer()```, ```transferFrom()``` или ```approve()```.

Стандарт ```IERC1363.sol``` расширяет реализацию токена ```ERC-20``` новыми функциями.
```solidity
interface IERC1363 is IERC20, IERC165 {
  function transferAndCall(address to, uint256 amount) external returns (bool);
  function transferAndCall(address to, uint256 amount, bytes calldata data) external returns (bool);
  function transferFromAndCall(address from, address to, uint256 amount) external returns (bool);
  function transferFromAndCall(address from, address to, uint256 amount, bytes calldata data) external returns (bool);
  function approveAndCall(address spender, uint256 amount) external returns (bool);
  function approveAndCall(address spender, uint256 amount, bytes calldata data) external returns (bool);
}
```

|```transferAndCall()```|```transferFromAndCall()```|```approveAndCall()```|
|-|-|-|
|Под капотом делает стандартный вызов функции ```transfer()```, а затем делает дополнительный вызов функции на адресе **получателя токена**.|Под капотом делает стандартный вызов функции ```transferFrom()```, а затем делает дополнительный вызов функции на адресе **получателя токена**.|Под капотом делает стандартный вызов функции ```approve()```, а затем делает дополнительный вызов функции на адресе **кому выдано разрешение** на использование токена.|

>Для выполнения кода после вызова ```transfer()``` или ```transferFrom()``` получатель токена должен быть **контрактом** и реализовывать интерфейс ```IERC1363Receiver.sol```
>```solidity
>interface IERC1363Receiver {
>  function onTransferReceived(address spender, address sender, uint256 amount, bytes ?calldata data) external returns (bytes4);
>}
>```

>Для выполнения кода после вызова ```approve()``` адрес, которому выдается разрешение на распоряжение токеном должен быть **контрактом** и реализовывать интерфейс ```IERC1363Spender.sol```
>```solidity
>interface IERC1363Spender {
>  function onApprovalReceived(address sender, uint256 amount, bytes calldata data)  external returns (bytes4);
>}
>```

## Examples
1. [Репозиторий](https://github.com/vittominacori/erc1363-payable-token) и [документация](https://vittominacori.github.io/erc1363-payable-token/#ierc1363receiver) с примерами реализации стандарта от Vittorio Minacori, который является автором стандарта ERC-1363: Payable Token

2. [LinkToken от Chainlink](https://github.com/smartcontractkit/LinkToken/blob/f307ea6d4c/contracts/v0.4/ERC677Token.sol). Реализован на основе ERC677Token, который вдохновил создание ERC-1363. Идея очень похожа, но к сожалению стандарт не был официально принят.

## Links
1. [ERC-1363: Payable Token](https://eips.ethereum.org/EIPS/eip-1363)
2. [Реализация IERC1363 интерфейса от OpenZeppelin](https://docs.openzeppelin.com/contracts/4.x/api/interfaces#IERC1363)