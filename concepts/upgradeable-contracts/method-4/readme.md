# Strategy pattern

На этот подход напрямую влияет классический паттерн стратегии. Основная идея которого заключается в выборе поведения или алгоритма действий в зависимости от условий во время выполнения.

Простым примером может быть класс, который выполняет проверку входных данных. Для проверки разных типов данных используется шаблон стратегии, который применяет разные алгоритмы валидации входных данных. Подробнее можно узнать про шаблон стратегии [тут](https://en.wikipedia.org/wiki/Strategy_pattern).

Применение шаблона стратегии к разработке Ethereum будет означать создание смарт-контракта, который вызывает функции из других контрактов. Основной контракт в этом случае содержит основную бизнес-логику, но взаимодействует с другими смарт-контрактами («вспомогательными контрактами») для выполнения определенных функций. Этот основной контракт также хранит адрес для каждого вспомогательного контракта и может переключаться между различными реализациями спутникового контракта.

Всегда можно создать новый вспомогательный контракт и настроить основной контракт на новый адрес. Это позволяет менять стратегии (внедрять новую логику или другими словами обновлять код) для смарт-контракта.

_Важно!_ Главный недостаток заключается в том, что этот шаблон в основном полезен для развертывания незначительных обновлений. Кроме того, если основной контракт скомпрометирован (был взлом), то этот метод обновления уже не подойдет.

## Examples

1. Хорошим примером простого паттерна стратегии является Compound, который имеет разные реализации [RateModel](https://github.com/compound-finance/compound-protocol/blob/v2.3/contracts/InterestRateModel.sol) для расчета процентной ставки, и его контракт CToken [может переключаться между ними](https://github.com/compound-finance/compound-protocol/blob/bcf0bc7b00e289f9b661a0ae934626e018188040/contracts/CToken.sol#L1358-L1366).

2. Чуть более сложной реализацией паттерна стратегия является "Pluggable Modules" или подключаемые модули. В этом подходе основной контракт предоставляет набор основных неизменяемых функций и позволяет регистрировать новые модули. Эти модули добавляют новые функции для вызова в основной контракт. Этот паттерн встречается в кошельке [Gnosis Safe](https://github.com/safe-global/safe-contracts/blob/v1.1.1/contracts/base/ModuleManager.sol#L35-L46). Пользователи могут добавить новые модули в свои собственные кошельки, а затем каждый вызов контракта кошелька будет запрашивать выполнение определенной функции из определенного модуля.

_Важно !_ Нужно иметь в виду, что Pluggable Modules также требует, чтобы основной контракт не содержал ошибок. Любые ошибки в самом управлении модулями не могут быть исправлены путем добавления новых модулей в эту схему.

## Links
1. [Strategy pattern](https://en.wikipedia.org/wiki/Strategy_pattern)