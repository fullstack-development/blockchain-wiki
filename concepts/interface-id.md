# Interface ID in solidity (EIP-165)

Иногда при вызове внешнего контракта, например для некоторых «стандартных интерфейсов», таких как интерфейс токена ERC-721, бывает полезно узнать, поддерживает ли смарт-контракт этот интерфейс и если поддерживает, то какую версию интерфейса. Для этого существует EIP-165: Standard Interface Detection, который определяет как выполнить такую проверку.

**EIP-165** - это стандарт для смарт-контрактов на блокчейне Ethereum, который позволяет определить поддерживаемые интерфейсы смарт-контрактов. Это работает благодаря тому, что смарт-контракт реализует специальную функцию `supportsInterface(bytes4 interfaceID)`, которая принимает на вход  идентификатор интерфейса и возвращает булево значение, указывающее, реализует ли смарт-контракт соответствующий интерфейс. Такой подход позволяет упростить взаимодействие со смарт-контрактом, поскольку пользователь может проверить, поддерживает ли смарт-контракт определенную функцию или возможность, прежде чем вызвать ее.  

**Идентификатор интерфейса (ID)** для ERC-165 - это четырехбайтовое значение, которое вычисляется как хэш keccak-256 подписи функции интерфейса. Подпись функции - это строка, состоящая из имени функции и типов ее параметров в определенном формате.  
  
Например, сигнатура функции supportsInterface в ERC-165 имеет вид `"supportsInterface(bytes4)"`. Затем эта строка проходит через хэш-функцию keccak-256, которая создает 32-байтовое хэш-значение. Первые четыре байта этого хэш-значения принимаются за идентификатор интерфейса.  
  
Подпись функции должна быть в формате `"functionName(type1, type2, ...)"`. Типы указываются в их каноническом представлении солидити, например, `address` вместо `address payable` и `bytes32[]` вместо `array`.  
  
Также важно помнить, что идентификатор интерфейса одинаков для селектора одной и той же функции, это означает, что он уникален для всех смарт-контрактов, что помогает предотвратить конфликты именования. 

**Рассмотрим на примере interfaceId для ERC-721:**

Чтобы вычислить идентификатор интерфейса для ERC-721, нужно взять хэш keccak-256 селектора каждой функции, затем взять первые 4 байта результата. Каждая функция имеет свой собственный идентификатор интерфейса.

Для объединения всех хэшей использует операцию `XOR` (исключающее ИЛИ) - это позволяет получать один и тот же хэш `interfaceId` независимо от того в каком порядке были переданы селекторы функций.

Таким образом, чтобы вычислить идентификатор интерфейса с помощью EIP-165, нужно сначала получить селектор для каждой функции в интерфейсе смарт-контракта, а затем использовать операцию `XOR` для их объединения.

```js
    bytes4(keccak256('balanceOf(address)')) == 0x70a08231
    bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
    bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
    bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
    bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
    bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
    bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
    bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
    bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde
     
    => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^ 0xa22cb465 ^ 0xe985e9c ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd

    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
```

В языке solidity существует встроенная возможность вычислять `interfaceId` - использовать `type(T).interfaceId`, рассмотрим на примере вышеупомянутого интерфейса.

```js
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC721 {	  
	function balanceOf(address _owner) external view returns (uint256);
	function ownerOf(uint256 _tokenId) external view returns (address);
	function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) external payable;
	function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
	function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
	function approve(address _approved, uint256 _tokenId) external payable;
	function setApprovalForAll(address _operator, bool _approved) external;
	function getApproved(uint256 _tokenId) external view returns (address);
	function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

contract Selector {
	function getInterfaceId() external pure returns (bytes4) {
		return type(IERC721).interfaceId; // 0x80ac58cd
	}
}
```

Так как `interfaceId` должен включать только стандартные сигнатуры функций - туда не включаются опциональные методы, либо для них определяется отдельный интерфейс, например для метаданных ERC721 это будет выглядеть следующим образом:

```js
    bytes4(keccak256('name()')) == 0x06fdde03
    bytes4(keccak256('symbol()')) == 0x95d89b41
    bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     
    => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd == 0x5b5e139f
     
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;
```

Итоговый вариант в смарт-контракте токена ERC721 будет выглядеть так:

```js
	function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
	return
		interfaceId == type(IERC721).interfaceId ||
		interfaceId == type(IERC721Metadata).interfaceId ||
		super.supportsInterface(interfaceId);
}
```

В проверяющем смарт-контракте зачастую указывают константу для проверки вызываемых смарт-контрактов, это позволяет существенно сэкономить газ на вычислениях.

```js
	bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
```

#### Ссылки:
- [EIP-165: Standard Interface Detection](https://eips.ethereum.org/EIPS/eip-165) 
- [Пример с ERC721](https://ethereum.stackexchange.com/questions/82822/obtaining-erc721-interface-ids) 
- [Для чего нужен interfaceId](https://ethereum.stackexchange.com/questions/71560/erc721-interface-id-registration)
- [Документация openzeppelin](https://docs.openzeppelin.com/contracts/4.x/api/utils#introspection)
- [Объяснение EIP165](https://medium.com/@chiqing/ethereum-standard-erc165-explained-63b54ca0d273) - открывать в режиме инкогнито