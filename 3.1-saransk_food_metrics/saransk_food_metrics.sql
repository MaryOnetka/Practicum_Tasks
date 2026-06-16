/*Название: Ключевые бизнес‑метрики в Саранске (май — июнь 2021).

Цель: оценить состояние клиентской базы сервиса доставки еды «Всё.из.кафе» в Саранске за май–июнь 2021 года и подготовить практические выводы для принятия бизнес‑решений на основе визуализации ключевых метрик.

Задачи проекта, часть 1, SQL-запросы в тренажёре:
- DAU (daily active users) — количество активных пользователей за день;
- Conversion Rate — коэффициент конверсии;
- средний чек — средняя сумма покупки на пользователя;
- LTV (lifetime value) — совокупная ценность клиента за период;
- Retention Rate — коэффициент удержания пользователей.*/

-- Задача 1. Расчёт DAU (Daily Active Users)
-- Рассчитать ежедневное количество активных зарегистрированных клиентов (по user_id) в Саранске за май–июнь 2021 года.
-- Активность определяется размещением заказа. Вывести дату (log_date) и количество активных клиентов (DAU),
-- отсортировав по дате в возрастающем порядке. Для проверки ограничить результат первыми 10 строками.

SELECT log_date,
        COUNT(DISTINCT user_id) AS DAU
FROM analytics_events AS e
LEFT JOIN cities AS c ON e.city_id = c.city_id
WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30' AND c.city_name='Саранск' AND event = 'order'
GROUP BY log_date
ORDER BY log_date ASC
LIMIT 10; 

-- Задача 2. Расчёт Conversion Rate (CR)
-- Определить ежедневную конверсию зарегистрированных пользователей в активных клиентов (совершивших заказ) в Саранске
-- за май–июнь 2021 года. Вывести дату (log_date) и значение конверсии (CR), округлённое до двух знаков после запятой.
-- Отсортировать по дате в возрастающем порядке, для проверки ограничить результат первыми 10 строками.

SELECT DISTINCT log_date,
                ROUND((COUNT(DISTINCT user_id) filter (WHERE event = 'order'))/COUNT(DISTINCT user_id)::numeric,2) AS CR
FROM analytics_events AS e
LEFT JOIN cities AS c ON e.city_id = c.city_id
WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30' AND c.city_name='Саранск'
GROUP BY log_date
ORDER BY log_date
LIMIT 10; 

-- Задача 3. Расчёт среднего чека
-- Рассчитать средний чек активных клиентов в Саранске за май и июнь 2021 года как среднюю комиссию сервиса с одного заказа.
-- Вывести: месяц, количество заказов, сумму комиссии (за месяц), средний чек (округлённый до копеек).
-- Отсортировать по месяцу в возрастающем порядке.

-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT *,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск')
-- Напишите ваш код ниже
SELECT
    CAST(DATE_TRUNC('month', log_date) AS DATE) AS "Месяц",
    COUNT(DISTINCT order_id) AS "Количество заказов",
    ROUND(COALESCE(SUM(commission_revenue), 0)::numeric, 2) AS "Сумма комиссии",
    ROUND(COALESCE(SUM(commission_revenue)::numeric, 0) / (COUNT(DISTINCT order_id)),2) AS "Средний чек"
FROM orders
GROUP BY CAST(DATE_TRUNC('month', log_date) AS DATE)
ORDER BY "Месяц";

-- Задача 4. Расчёт LTV ресторанов
-- Выявить три ресторана из Саранска с наибольшим LTV (суммарной комиссией от заказов) за май–июнь 2021 года.
-- Вывести: rest_id, название сети, тип кухни, LTV (округлённый до копеек). Отсортировать по убыванию LTV.

WITH orders AS
    (SELECT analytics_events.rest_id,
            analytics_events.city_id,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск')
SELECT o.rest_id,
       p.chain AS "Название сети",
       p.type AS "Тип кухни",
       ROUND(SUM(o.commission_revenue)::numeric, 2) AS LTV
FROM orders AS o
JOIN partners AS p ON o.rest_id = p.rest_id AND o.city_id = p.city_id
GROUP BY o.rest_id, p.chain, p.type 
ORDER BY LTV DESC
LIMIT 3;

-- Задача 5. Расчёт LTV по самым популярным блюдам
-- Для двух ресторанов с наибольшим LTV («Гурманское Наслаждение» и «Гастрономический Шторм») определить пять самых
-- популярных блюд по вкладу в LTV за май–июнь 2021 года. Вывести: название сети, название блюда, признаки spicy, fish, meat,
-- LTV (округлённый до копеек). Отсортировать по убыванию LTV, ограничить результат первыми 5 строками. Использовать код из задачи 4.

-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT analytics_events.rest_id,
            analytics_events.city_id,
            analytics_events.object_id,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'), 
-- Рассчитываем два ресторана с наибольшим LTV 
top_ltv_restaurants AS
    (SELECT orders.rest_id,
            chain,
            type,
            ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
     FROM orders
     JOIN partners ON orders.rest_id = partners.rest_id AND orders.city_id = partners.city_id
     GROUP BY 1, 2, 3
     ORDER BY LTV DESC
     LIMIT 2)
-- Напишите ваш код ниже
SELECT tr.chain AS "Название сети",
        d.name AS "Название блюда",
        d.spicy,
        d.fish,
        d.meat,
        ROUND(SUM(o.commission_revenue)::numeric, 2) AS ltv
FROM top_ltv_restaurants tr
JOIN dishes d ON tr.rest_id = d.rest_id
JOIN orders o ON tr.rest_id = o.rest_id AND d.object_id = o.object_id
GROUP BY tr.chain, d.name, d.spicy, d.fish, d.meat
ORDER BY ltv DESC
LIMIT 5;

-- Задача 6. Расчёт Retention Rate (коэффициента удержания)
-- Рассчитать недельную возвращаемость пользователей в Саранске: процент тех, кто вернулся в приложение в течение
-- первой недели после регистрации (с 01.05.2021 по 24.06.2021). Активность — любое действие (не только заказ).
-- Вывести: day_since_install (день жизни пользователя), retained_users (количество вернувшихся),
-- retention_rate (процент удержания, округлённый до двух знаков после запятой).
-- Отсортировать по day_since_install в возрастающем порядке.

-- Рассчитываем новых пользователей по дате первого посещения продукта
WITH new_users AS
    (SELECT DISTINCT first_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
         AND city_name = 'Саранск'),
-- Рассчитываем активных пользователей по дате события
active_users AS
    (SELECT DISTINCT log_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'),
-- Напишите ваш код ниже
-- 3. Соединяем новых пользователей с их активностями
    daily_retention AS (
        SELECT
            n.user_id,
            n.first_date,
            a.log_date,
            (a.log_date - n.first_date) AS day_since_install
        FROM new_users n
        JOIN active_users a ON n.user_id = a.user_id
        WHERE a.log_date >= n.first_date          
    )
    
SELECT day_since_install,
       COUNT(DISTINCT user_id) AS retained_users,
       ROUND((1.0 * COUNT(DISTINCT user_id) / MAX(COUNT(DISTINCT user_id)) OVER (ORDER BY day_since_install))::numeric, 2) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8
GROUP BY day_since_install
ORDER BY day_since_install;

-- Задача 7. Сравнение Retention Rate по месяцам
-- Разделить пользователей на две когорты по месяцу первого посещения (май и июнь 2021 года) и сравнить их Retention Rate.
-- Вывести: месяц первого посещения, day_since_install, retained_users, retention_rate (округлённый до двух знаков после запятой).
-- Отсортировать сначала по месяцу, затем по day_since_install в возрастающем порядке. Использовать код из задачи 6.

-- Рассчитываем новых пользователей по дате первого посещения продукта
WITH new_users AS
    (SELECT DISTINCT first_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
         AND city_name = 'Саранск'),
-- Рассчитываем активных пользователей по дате события
active_users AS
    (SELECT DISTINCT log_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'),
-- Соединяем таблицы с новыми и активными пользователями
daily_retention AS
    (SELECT new_users.user_id,
            first_date,
            log_date::date - first_date::date AS day_since_install
     FROM new_users
     JOIN active_users ON new_users.user_id = active_users.user_id
     AND log_date >= first_date)
-- Напишите ваш код ниже
SELECT DISTINCT CAST(DATE_TRUNC('month', first_date) AS date) AS "Месяц",
                day_since_install,
                COUNT(DISTINCT user_id) AS retained_users,
                ROUND((1.0 * COUNT(DISTINCT user_id) / MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY CAST(DATE_TRUNC('month', first_date) AS date) ORDER BY day_since_install))::numeric, 2) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8
GROUP BY "Месяц", day_since_install
ORDER BY "Месяц", day_since_install;
