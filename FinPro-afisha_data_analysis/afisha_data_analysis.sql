/* Название: Анализ данных Яндекс Афиши. Часть 1: Анализ данных с помощью SQL.

Цель: вычисление ключевых метрик продукта.

Ключевые метрики для дашборда:
- итоговая выручка за период;
- общее количество заказов;
- средняя выручка с одного заказа;
- число уникальных покупателей;
- недельная динамика выручки, количества заказов и средней выручки с заказа;
- структура выручки по типам устройств и мероприятий;
- топ‑сегменты по выручке: регионы, события, площадки
(с расчётом выручки, количества заказов, среднего числа билетов в заказе, средней выручки с билета).*/

-- Задача 1. Получение общих данных
-- Вычислить ключевые показатели сервиса в разрезе валюты (currency_code):
-- total_revenue — общая выручка с заказов;
-- total_orders — количество заказов;
-- avg_revenue_per_order — средняя выручка заказа;
-- total_users — общее число уникальных клиентов.
-- Отсортировать результат по total_revenue в порядке убывания.
  
SELECT currency_code,
        SUM(revenue) AS total_revenue,
        COUNT(order_id) AS total_orders,
        AVG(revenue) AS avg_revenue_per_order,
        COUNT(DISTINCT user_id) AS total_users
FROM afisha.purchases
GROUP BY currency_code
ORDER BY total_revenue DESC;

/*
currency_code|total_revenue|total_orders|avg_revenue_per_order|total_users|
-------------+-------------+------------+---------------------+-----------+
rub          |    157130432|      286961|     547.570922412914|      21422|
kzt          |     25340978|        5073|    4995.309819793927|       1362|
*/

-- Задача 2. Распределение выручки по устройствам
-- Для заказов в рублях рассчитать распределение выручки и количества заказов по типу устройства (device_type_canonical). Вывести:
-- device_type_canonical — тип устройства;
-- total_revenue — общая выручка с заказов;
-- total_orders — количество заказов;
-- avg_revenue_per_order — средняя стоимость заказа;
-- revenue_share — доля выручки для устройства от общего значения (округлённая до трёх знаков после точки).
-- Отсортировать по revenue_share в порядке убывания.

-- Настройка параметра synchronize_seqscans важна для проверки
WITH set_config_precode AS (
  SELECT set_config('synchronize_seqscans', 'off', true)
)
-- Напишите ваш запрос ниже
SELECT DISTINCT device_type_canonical,
        SUM(revenue) AS total_revenue,
        COUNT(order_id) AS total_orders,
        AVG(revenue) AS avg_revenue_per_order,
        ROUND(SUM(revenue)::NUMERIC/
            (SELECT SUM(revenue)::NUMERIC
            FROM afisha.purchases
            WHERE currency_code='rub'),
        3) AS revenue_share
FROM afisha.purchases
WHERE currency_code='rub'
GROUP BY device_type_canonical
ORDER BY revenue_share DESC;

/*
device_type_canonical|total_revenue|total_orders|avg_revenue_per_order|revenue_share|
---------------------+-------------+------------+---------------------+-------------+
mobile               |    124633528|      229021|    544.1976894989267|        0.793|
desktop              |     31851612|       56759|    561.1687862756498|        0.203|
tablet               |     640988.7|        1176|    545.0581287524733|        0.004|
other                |    5133.7603|           2|   2566.8800659179688|        0.000|
tv                   |      1299.16|           3|    433.0533447265625|        0.000|
*/

-- Задача 3. Распределение выручки по типу мероприятий
-- Для заказов в рублях рассчитать распределение по типу мероприятия (event_type_main). Вывести:
-- event_type_main — тип мероприятия;
-- total_revenue — общая выручка с заказов;
-- total_orders — количество заказов;
-- avg_revenue_per_order — средняя стоимость заказа;
-- total_event_name — уникальное число событий (по коду event_name_code);
-- avg_tickets — среднее число билетов в заказе;
-- avg_ticket_revenue — средняя выручка с одного билета;
-- revenue_share — доля выручки от общего значения (округлённая до трёх знаков после точки).
-- Отсортировать по total_orders в порядке убывания.

SELECT e.event_type_main,
        SUM(p.revenue) AS total_revenue,
        COUNT(p.order_id) AS total_orders,
        AVG(p.revenue) AS avg_revenue_per_order,
        COUNT(DISTINCT e.event_name_code) AS total_event_name,
        AVG(p.tickets_count) AS avg_tickets,
        SUM(p.revenue)/SUM(tickets_count) AS avg_ticket_revenue,
        ROUND(SUM(revenue)::NUMERIC/
            (SELECT SUM(revenue)::NUMERIC
            FROM afisha.purchases
            WHERE currency_code='rub'),
        3) AS revenue_share
FROM afisha.purchases p
JOIN afisha.events e ON p.event_id=e.event_id
WHERE p.currency_code='rub'
GROUP BY e.event_type_main
ORDER BY total_orders DESC;

/*
event_type_main|total_revenue|total_orders|avg_revenue_per_order|total_event_name|avg_tickets       |avg_ticket_revenue|revenue_share|
---------------+-------------+------------+---------------------+----------------+------------------+------------------+-------------+
концерты       |     88705368|      112418|    789.0850212149544|            6014|2.6570389083598712|296.97243044000817|        0.565|
театр          |     37141692|       67733|    548.3568227249012|            4352|2.7600726381527468|198.67392002054046|        0.236|
другое         |     15579650|       64572|   241.28204110350754|            3807|2.7648361518924611| 87.26579697643547|        0.099|
спорт          |    3466726.8|       21700|   159.75414450427698|             785|3.0534101382488479| 52.32084320620595|        0.022|
стендап        |    9547247.0|       13421|    711.3644202233036|             420|2.9919529096192534|237.75985555970612|        0.061|
выставки       |    1135886.1|        4873|   233.10002582614584|             279|2.5581777139339216| 91.11873295363388|        0.007|
ёлки           |    1549355.5|        2006|    772.3603511403351|             173|3.3424725822532403|231.07464578672634|        0.010|
фильм          |    3084.8103|         238|   12.961386680603027|              19|2.6554621848739496|4.8810289600227454|        0.000|
*/

-- Задача 4. Динамика изменения значений (недельная)
-- Для заказов в рублях вычислить недельную динамику метрик. Вывести:
-- week — неделя;
-- total_revenue — суммарная выручка;
-- total_orders — число заказов;
-- total_users — уникальное число клиентов;
-- revenue_per_order — средняя стоимость одного заказа (суммарная выручка / число заказов).
-- Отсортировать по week в порядке возрастания.

SELECT DATE_TRUNC('week', created_dt_msk)::date AS week,
        SUM(revenue) AS total_revenue,
        COUNT(order_id) AS total_orders,
        COUNT(DISTINCT user_id) AS total_users,
        SUM(revenue)/COUNT(order_id) AS revenue_per_order
FROM afisha.purchases
WHERE currency_code='rub'
GROUP BY DATE_TRUNC('week', created_dt_msk)::date
ORDER BY week;

/*
week      |total_revenue|total_orders|total_users|revenue_per_order |
----------+-------------+------------+-----------+------------------+
2024-05-27|     911625.7|        2024|        805| 450.4079483695652|
2024-06-03|    3989499.0|        7589|       2238| 525.6949532217684|
2024-06-10|    4160552.8|        7431|       2153| 559.8913672453236|
2024-06-17|    4612188.5|        8043|       2143| 573.4413154295661|
2024-06-24|    4243699.5|        7362|       2032|  576.432966585167|
2024-07-01|    5159818.0|        8995|       2296| 573.6317954419121|
2024-07-08|    5511003.5|        8980|       2310| 613.6974944320713|
2024-07-15|    5580839.5|        8836|       2406| 631.6024784970575|
2024-07-22|    5457105.0|        9347|       2421| 583.8349202952819|
2024-07-29|    5846354.0|       10536|       2492| 554.8931283219438|
2024-08-05|    6235618.0|        9642|       2546| 646.7141671852313|
2024-08-12|    6081583.5|        9719|       2596| 625.7416915320506|
2024-08-19|    5823034.0|       10488|       2654| 555.2091914569031|
2024-08-26|    5701595.5|       10157|       2527| 561.3464113419317|
2024-09-02|    6926397.0|       15642|       3075|442.80763329497506|
2024-09-09|    8349239.5|       15706|       3431| 531.5955367375525|
2024-09-16|    9044700.0|       16599|       3509| 544.8942707392011|
2024-09-23|    9865479.0|       17554|       3768| 562.0074626865671|
2024-09-30|     11440865|       23031|       4071| 496.7593678086058|
2024-10-07|     10978249|       19420|       4118|  565.306333676622|
2024-10-14|     12096955|       22438|       4420| 539.1280417149478|
2024-10-21|     12207041|       22810|       4475|  535.161814993424|
2024-10-28|    6907851.0|       14612|       3019|  472.751916233233|
*/

-- Задача 5. Топ‑7 регионов по выручке
-- Вывести топ‑7 регионов (для заказов в рублях) по общей выручке. Вывести:
-- region_name — название региона;
-- total_revenue — суммарная выручка;
-- total_orders — число заказов;
-- total_users — уникальное число клиентов;
-- total_tickets — количество проданных билетов;
-- one_ticket_cost — средняя выручка одного билета.
-- Отсортировать по total_revenue в порядке убывания.

SELECT DISTINCT r.region_name,
        SUM(p.revenue) AS total_revenue,
        COUNT(p.order_id) AS total_orders,
        COUNT(DISTINCT p.user_id) AS total_users,
        SUM(p.tickets_count) AS total_tickets,
        SUM(p.revenue)/SUM(p.tickets_count) AS one_ticket_cost
FROM afisha.purchases p
JOIN afisha.events e ON p.event_id=e.event_id
JOIN afisha.city c ON e.city_id=c.city_id
JOIN afisha.regions r ON c.region_id=r.region_id
WHERE currency_code='rub'
GROUP BY r.region_name
ORDER BY total_revenue DESC
LIMIT 7;

/*
region_name         |total_revenue|total_orders|total_users|total_tickets|one_ticket_cost   |
--------------------+-------------+------------+-----------+-------------+------------------+
Каменевский регион  |     61555204|       91634|      10646|       253393|242.92385346082963|
Североярская область|     25453390|       44282|       6735|       125204|  203.295342001853|
Озернинский край    |    9793663.0|       10502|       2488|        29621| 330.6324229431822|
Широковская область |    9543778.0|       16538|       3278|        46977|203.15852438427316|
Малиновоярский округ|    5955931.0|        6634|       1902|        17465| 341.0209561981105|
Яблоневская область |    3692395.8|        6197|       1431|        16589|222.58097233106275|
Светополянский округ|    3425867.5|        7632|       1683|        20434|167.65525594597239|
*/
