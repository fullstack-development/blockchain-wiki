# BigQuery. Примеры простых SQL-запросов.

Данные блокчейна Ethereum доступны для изучения благодаря сервису Google. Все исторические данные находятся в специальном публичном dataset, который обновляется ежедневно. Для сбора аналитики, агрегации данных используется инструмент BigQuery.

BigQuery это инструмент, который является частью [Google Cloud Console](https://console.cloud.google.com/welcome?project=thermal-elixir-376710). Это полностью бессерверное корпоративное хранилище данных. Оно имеет встроенные функции машинного обучения и бизнес-аналитики, которые работают в облаках и масштабируются вместе с вашими данными. Запросы к данным делаются при помощи SQL запросов.

## Getting started

1. Открыть [Google Cloud Console](https://console.cloud.google.com/welcome?project=thermal-elixir-376710)
2. В левом боковом меню найти инструмент BigQuery
3. Создать проект
4. После этого можно вставлять код из примеров ниже в специльный редактор Sql запросов и запускать к исполнению. В ответ sql запросы будут делать определенную выборку и возвращать данные.

## Examples

1. Получение балансов аккаунтов с сортировкой по убыванию(Топ самых богатых аккаунтов в сети Ethereum)

``` sql
SELECT
  address AS Account,
  CAST(eth_balance as NUMERIC) / 1000000000000000000 as Balance
FROM `bigquery-public-data.crypto_ethereum.balances`
ORDER BY eth_balance DESC
LIMIT 50
```

2. Получить 50 первых токенов отсортированных по totalSupply в порядке убывания

``` sql
SELECT
  name,
  symbol,
  address,
  CAST(total_supply as  FLOAT64) as TotalSupply
FROM `bigquery-public-data.crypto_ethereum.tokens`
ORDER BY total_supply DESC
LIMIT 50
```

3. Получить количество транзакций за год в сети Ethereum

``` sql
WITH daily_transactions AS (
  SELECT
    date(block_timestamp) AS Date,
    count(*) AS Count
  FROM `bigquery-public-data.crypto_ethereum.transactions`
  GROUP BY Date
)

SELECT
  EXTRACT(YEAR FROM date_trunc(Date, YEAR)) AS Year,
  CAST(SUM(Count) AS INT64) AS Count
FROM daily_transactions
GROUP BY Year
ORDER BY Year ASC
```

