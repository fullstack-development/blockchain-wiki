# ERC-6909: Minimal Multi-Token Interface

**Автор:** [Павел Найданов](https://github.com/PavelNaydanov) 🕵️‍♂️

Стандарт [ERC-6909](https://eips.ethereum.org/EIPS/eip-6909) является альтернативой стандарту [ERC-1155: Multi Token Standard](https://eips.ethereum.org/EIPS/eip-1155) для управления множеством токенов из одного смарт-контракта.

Основные отличия от ERC-1155:
- Интерфейс не требует реализации callback механизма для получателя токена.
- Нет возможности делать batch вызовы, когда в одной транзакции происходит несколько операций с токенами.
- Переработана система выдачи разрешений на использование токенов третьими лицами (апрувов).

Интерфейс ERC-6909 представляет собой минимальную функциональность, что позволяет сократить издержки в размере кода смарт-контракта и исполнении вызова транзакций.

_Важно!_ Любой смарт-контракт, который будет реализовывать ERC-6909, должен поддерживать [ERC-165: Standard Interface Detection](https://eips.ethereum.org/EIPS/eip-165) по умолчанию.

_Интересно!_ В разработке стандарта принял участие [Vectorized](https://github.com/Vectorized), разработчик таких проектов, как [solady](https://github.com/Vectorized/solady), [ERC721A](https://github.com/chiru-labs/ERC721A), [multicaller](https://github.com/Vectorized/multicaller).

## Референсная имплементация

[Референсная имплементация](https://eips.ethereum.org/EIPS/eip-6909#reference-implementation) взята из спецификации ERC-6909 и упрощена мной для быстрого ознакомления разработчикам. Рекомендую изучить сначала референс, а потом читать статью дальше.

```solidity
contract ERC6909 {
    /// @notice Баланс владельцев
    mapping(address owner => mapping(uint256 id => uint256 amount)) public balanceOf;

    /// @notice Выданные разрешения на использование токена третьими лицами
    mapping(address owner => mapping(address spender => mapping(uint256 id => uint256 amount))) public allowance;

    /// @notice Разрешения для операторов
    mapping(address owner => mapping(address spender => bool)) public isOperator;

    /// @notice Трансфер токена от имени владельца
    function transfer(address receiver, uint256 id, uint256 amount) public returns (bool) {
        if (balanceOf[msg.sender][id] < amount) revert InsufficientBalance(msg.sender, id);

        balanceOf[msg.sender][id] -= amount;
        balanceOf[receiver][id] += amount;

        emit Transfer(msg.sender, msg.sender, receiver, id, amount);
        return true;
    }

    /// @notice Трансфер токена третьими лицами, требует выданного разрешения
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) public returns (bool) {
        if (sender != msg.sender && !isOperator[sender][msg.sender]) {
            uint256 senderAllowance = allowance[sender][msg.sender][id];

            if (senderAllowance < amount) revert InsufficientPermission(msg.sender, id);
            if (senderAllowance != type(uint256).max) {
                allowance[sender][msg.sender][id] = senderAllowance - amount;
            }
        }

        if (balanceOf[sender][id] < amount) revert InsufficientBalance(sender, id);

        balanceOf[sender][id] -= amount;
        balanceOf[receiver][id] += amount;

        emit Transfer(msg.sender, sender, receiver, id, amount);
        return true;
    }

    /// @notice Выдача разрешения на передачу токена третьими лицами с ограничением количества токена
    function approve(address spender, uint256 id, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender][id] = amount;
        emit Approval(msg.sender, spender, id, amount);
        return true;
    }

    /// @notice Выдача разрешения на передачу токена оператором без ограничения на количество токена
    function setOperator(address spender, bool approved) public returns (bool) {
        isOperator[msg.sender][spender] = approved;
        emit OperatorSet(msg.sender, spender, approved);
        return true;
    }

    function _mint(address receiver, uint256 id, uint256 amount) internal {
      balanceOf[receiver][id] += amount;
      emit Transfer(msg.sender, address(0), receiver, id, amount);
    }

    function _burn(address sender, uint256 id, uint256 amount) internal {
      balanceOf[sender][id] -= amount;
      emit Transfer(msg.sender, sender, address(0), id, amount);
    }
}
```

## Изменение структуры хранения балансов

Структура хранения балансов - это первое на что необходимо обратить внимание. В отличие от ERC-1155 есть изменения.

```solidity
// ERC-1155 из OpenZeppelin
mapping(uint256 id => mapping(address account => uint256)) private _balances;

// ERC-6909 из OpenZeppelin
mapping(address owner => mapping(uint256 id => uint256)) private _balances;
```

Маппинг отвечающий за хранение баланса аккаунта начинается не с идентификатора, а с адреса аккаунта владельца.

Принципиально это влияет только на интерфейс взаимодействия. По прежнему, чтобы получить все балансы пользователя необходимо самостоятельно реализовывать дополнительные функции на смарт-контракте или индексировать данные off-chain. Связано это с тем, что нужно знать все идентификаторы токенов, которыми владеет аккаунт, а базовая имплементация не хранит этой информации по дефолту.

## Нет обратного вызова (callback)

Согласно стандарту ERC-1155 смарт-контракт, выступающий получателем токенов должен реализовывать интерфейс `ERC1155TokenReceiver`.

Этот интерфейс диктует обязательную реализацию одной из функции согласно выбранному способу передачи токенов (single или batch):
```solidity
-  function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4);
-  function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external returns(bytes4);
```

В ERC-6909 разработчикам по прежнему можно использовать обратные вызовы, но только реализация остается на их стороне и может быть произвольной.

ERC-6909 не регламентирует механизм обратного вызова. Это позволяет экономить на размере базовой имплементации смарт-контракта и количестве операций в момент исполнения, что является эффективным с точки зрения газа и сложности.

## Изменения в трансфере токенов

Аналогично обратным вызовам, стандарт поступил с batch операциями.

ERC-1155 требует реализации дополнительных функций:
```solidity
- function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external;
- function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view returns (uint256[] memory);
```

ERC-6909 больше не регламентирует batch операции и не требует их реализации только ради того, чтобы быть совместимым стандарту.

Batch операции могут быть добавлены по усмотрению разработчика и адаптированы под конкретные задачи проекта.

**Функции трансфера токена**

Трансфер максимально приближен к реализации стандарта ERC-20 c небольшой модификации.

```solidity
- function transfer(address receiver, uint256 id, uint256 amount) public returns (bool);
- function transferFrom(address sender, address receiver, uint256 id, uint256 amount) public returns (bool);
```

`Sender` и `receiver` - это привычные `from` и `to`. Добавляется `id`, для возможности указать идентификатор токена, который участвует в переводе. Добавление `id` очень напоминает ERC-721 и ERC-1155.

## Гибкая система выдачи апрува

В ERС-1155 выдать апрув можно только оператору через вызов функции:

```solidity
function setApprovalForAll(address _operator, bool _approved) external;
```

В ERC-6909 вводится гибридная система выдачи апрувов. Есть две возможности выдать апрув:
- **Оператору** с указанием неограниченного для использования количества токенов от имени владельца.
- **Произвольному аккаунту** с ограничением количества токенов, которое он сможет использовать от имени владельца.

Таким образом интерфейс ERC-6909 предоставляет две функции для реализации работы с апрувом:

```solidity
- function setOperator(address spender, bool approved) public returns (bool);
- function approve(address spender, uint256 id, uint256 amount) public returns (bool);
```

Подобный механизм достаточно гибок, но есть нюанс для случаев, когда аккаунту выдается апрув через обе функции. В таком случае стандарт реализует проверки в следующей очередности:
1. Проверка на оператора
2. Если не оператор, то проверка `allowance`, выданного через вызов `approve()`.

Проверяется выданный апрув только при использовании функции `transferFrom()`.

```solidity
function transferFrom(address sender, address receiver, uint256 id, uint256 amount) public returns (bool) {
    // Если сендер сам отправляет токены или сендеру выданы права оператора, то тогда сразу отправить токены
    // В противном случае, скорректировать значение суммы, остающейся в распоряжение вызывающего
    if (sender != msg.sender && !isOperator[sender][msg.sender]) {
        uint256 senderAllowance = allowance[sender][msg.sender][id];
        if (senderAllowance < amount) revert InsufficientPermission(msg.sender, id);

        if (senderAllowance != type(uint256).max) {
            allowance[sender][msg.sender][id] = senderAllowance - amount;
        }
    }

    // Изменение балансов, отправка сообщения

    return true;
}
```

Таким образом, для оператора, которому выдан апрув на ограниченную сумму (через функцию `approve()`), не будет изменяться `allowance`.

## Metadata токенов

При помощи стандарта ERC-6909 можно реализовывать и взаимозаменяемые токены и невзаимозаменяемые одновременно. Для этого, согласно стандарту, реализация функций, отвечающих за метаданные,выносится в расширение основного стандарта и является опциональным.

**Почему опциональным?** Ответ прост, для реализации управления LP токенами (или другими видами токенов) может быть не важно их name и symbol или URI. Именно поэтому метаданные опциональны и вынесены из базовой реализации, но использование регламентировано.

При этом, *сейчас именно как расширения*, метаданные реализованы только библиотекой OpenZeppelin. (В solmate нет смарт-контрактов для метаданных, в [solady метаданные зашиты в базовую имплементацию](https://github.com/Vectorized/solady/blob/main/src/tokens/ERC6909.sol#L97C1-L112C79)).

Дальше посмотрим на то, как смарт-контракты метаданных реализованы в OpenZeppelin.

_Важно!_ На момент написания статьи, все, что касается ERC-6909 в OpenZeppelin, помечено, как draft.

**ERC6909Metadata.sol**

```solidity
contract ERC6909Metadata {
    struct TokenMetadata {
        string name;
        string symbol;
        uint8 decimals;
    }

    mapping(uint256 id => TokenMetadata) private _tokenMetadata;

    function name(uint256 id) public view virtual returns (string memory) {
        return _tokenMetadata[id].name;
    }

    function symbol(uint256 id) public view virtual override returns (string memory) {
        return _tokenMetadata[id].symbol;
    }

    function decimals(uint256 id) public view virtual override returns (uint8) {
        return _tokenMetadata[id].decimals;
    }
}
```

Для нас здесь интересно две вещи:
1. Все функции `name()`, `symbol()`, `decimals()` принимают один аргумент `id`. Это означает, что каждый токен будет иметь собственные параметры.
2. OpenZeppelin использует комбинацию `mapping` и `structure` для хранения данных. Классический подход для оптимизации хранения данных.

**ERC6909TokenSupply.sol**

```solidity
contract ERC6909TokenSupply {
    mapping(uint256 id => uint256) private _totalSupplies;

    function totalSupply(uint256 id) public view virtual override returns (uint256) {
        return _totalSupplies[id];
    }

    /// @dev Override the `_update` function to update the total supply of each token id as necessary.
    function _update(address from, address to, uint256 id, uint256 amount) internal virtual override {
      ...
    }
}
```

`Total supply` аналогично name, symbol и так далее индивидуален для каждого токена.

**ERC6909ContentURI.sol**

```solidity
contract ERC6909ContentURI is ERC6909, IERC6909ContentURI {
    string private _contractURI;
    mapping(uint256 id => string) private _tokenURIs;

    function contractURI() public view virtual override returns (string memory) {
        return _contractURI;
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return _tokenURIs[id];
    }
}
```

Этот контракт хранит метаданные необходимые для нфт. `contractURI` для объявления общих данных коллекции. `tokenURI` для объявления индивидуальных метаданных по каждому токену.

**Таким образом, использую комбинации расширений смарт-контрактов метаданных: ERC6909Metadata, ERC6909TokenSupply, ERC6909ContentURI, стандарт может одновременно управлять, как взаимозаменяемыми токенами, так и невзаимозаменяемыми.**

## Удаление safe наименования

Соглашения об именовании `safeTransfer()` и `safeTransferFrom()` вводят в заблуждение, особенно в контексте стандартов ERC-1155 и ERC-721, так как они требуют внешних вызовов на адресе получателей (если получатель смарт-контракт). Таким образом поток выполнения передается произвольному контракту.

Согласно стандарту ERC-6909 считается, что удаление слова "safe" из всех имен функций больше не будет вводить в заблуждение.

## Реальное применение

В отличии от множества предлагаемых стандартов токенов, ERC-6909 был сходу опробован в Uniswap четвертой версии.

ERC-6909 выступает в качестве доказательства наличия активов у пользователя внутри протокола.

Работает достаточно просто, после совершения операции (свап, удаление ликвидности) пользователь может оставить свой актив внутри протокола, а взамен получить ERC-6909. В следующий раз, для использования актива внутри протокола достаточно будет сжечь эквивалент ERC-6909.

Таким образом, ERC-6909 позволяет существенно экономить на газе при перемещение активов (минт ERC-6909 дешевле, чем трансфер ERC-20 актива по количеству газа).

Особенно полезна эта технология для трейдеров, которые делает множество операций за короткий промежуток времени и поставщиков ликвидности, которые занимаются ребалансировкой своей позиции.

Подробнее в [официальной документации Uniswap](https://docs.uniswap.org/contracts/v4/concepts/erc6909).

## Вывод

Стандарт ERC-6909 это тот редкий случай, когда система упрощается, а не усложняется. За счет этого упразднения любая имплементация стандарта проще для понимания, меньше весит и дешевле в использовании множества токенов.

Стандарт ERC-6909 не является обратно совместимым с ERC-1155!

При этом особый акцент я хотел бы сделать на возможности бесшовно комбинировать управление взаимозаменяемыми и невзаимозаменяемыми токенами. Один смарт-контракт ERC-6909 может управлять ERC-20 токенами и нфтишками.

_Важно!_ С оговоркой, что все нфт будут реализованы в рамках одной коллекции, так как `contractURI()` функция не подразумевает поддержку множества коллекций.

## Links

1. [ERC-6909: Minimal Multi-Token Interface](https://eips.ethereum.org/EIPS/eip-6909#reference-implementation)
2. [Имплементация в solady](https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC6909.sol)
3. [Имплементация в solmate](https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC6909.sol)
4. [Имплементация в OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC6909/draft-ERC6909.sol)
5. [ERC-6909 Minimal Multi-Token Standard](https://www.rareskills.io/post/erc-6909) от RareSkills
