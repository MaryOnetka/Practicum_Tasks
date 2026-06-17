/* Название: Анализ данных Яндекс Книг для BitMotion Kit.
Задачи:
- рассчитать ключевые метрики( MAU авторов, MAU произведений, Retention Rate, LTV, среднюю выручку за прослушанный час (аналог среднего чека));
- подготовить данные для проверки гипотезы (отфильтровать пользователей из Москвы и СПб, рассчитать суммарное время активности). */

-- Задача 1. Расчёт MAU авторов
-- Рассчитать MAU (количество уникальных пользователей в месяц, читавших/слушавших конкретного автора) для ноября.
-- Вывести имена топ‑3 авторов с наибольшим MAU и значения MAU (main_author_name, mau).
-- Отсортировать результат по MAU в порядке убывания.

WITH november_activity AS (
    SELECT 
        DISTINCT a.main_author_name,
        au.puid,
        DATE_TRUNC('month', au.msk_business_dt_str::date) AS activity_month
    FROM bookmate.audition au
    JOIN bookmate.content c ON au.main_content_id = c.main_content_id
    JOIN bookmate.author a ON c.main_author_id = a.main_author_id
    WHERE au.msk_business_dt_str::date >= '2024-11-01'
      AND au.msk_business_dt_str::date < '2024-12-01'
)
SELECT 
    main_author_name,
    COUNT(DISTINCT puid) AS mau
FROM november_activity
GROUP BY main_author_name
ORDER BY mau DESC
LIMIT 3;

-- Задача 2. Расчёт MAU произведений
-- Рассчитать MAU произведений для ноября. Вывести имена топ‑3 произведений с наибольшим MAU, списки жанров,
-- имена авторов и значения MAU (main_content_name, published_topic_title_list, main_author_name, mau).
-- Отсортировать по MAU в порядке убывания.

WITH november_activ AS (
    SELECT 
        DISTINCT 
        c.main_content_name,
        c.published_topic_title_list,
        a.main_author_name,
        au.puid,
        DATE_TRUNC('month', au.msk_business_dt_str::date) AS activ_month
    FROM bookmate.audition au
    JOIN bookmate.content c ON au.main_content_id = c.main_content_id
    JOIN bookmate.author a ON c.main_author_id = a.main_author_id
    WHERE au.msk_business_dt_str::date >= '2024-11-01'
      AND au.msk_business_dt_str::date < '2024-12-01'
)
SELECT 
    main_content_name,
    published_topic_title_list,
    main_author_name,
    COUNT(DISTINCT puid) AS mau
FROM november_activ
GROUP BY 
    main_content_name,
    published_topic_title_list,
    main_author_name
ORDER BY mau DESC
LIMIT 3;

-- Задача 3. Расчёт Retention Rate
-- Рассчитать ежедневный Retention Rate для пользователей, активных 2 декабря, до конца периода представленных данных. Вывести:
-- day_since_install — срок жизни пользователя в днях;
-- retained_users — количество пользователей, вернувшихся в приложение в конкретный день;
-- retention_rate — коэффициент удержания (округлённый до двух знаков после запятой), рассчитанный как отношение вернувшихся пользователей к общему числу пользователей в когорте (с использованием MAX() в оконной функции).
-- Отсортировать результат по day_since_install в порядке возрастания.

WITH cohort AS (
    SELECT DISTINCT puid AS user_id
    FROM bookmate.audition
    WHERE CAST(msk_business_dt_str AS date) = DATE '2024-12-02'
),
cohort_size AS (
    SELECT COUNT(*) AS cohort_users_count FROM cohort
),
activity AS (
    SELECT DISTINCT puid AS user_id,
           CAST(msk_business_dt_str AS date) AS log_date
    FROM bookmate.audition
    WHERE puid IS NOT NULL
),
daily_retention AS (
    SELECT c.user_id,
           (a.log_date - DATE '2024-12-02') AS day_since_install
    FROM cohort c
    JOIN activity a USING (user_id)
),
agg AS (
    SELECT
        dr.day_since_install,
        COUNT(DISTINCT dr.user_id) AS retained_users,
        cs.cohort_users_count
    FROM daily_retention dr
    CROSS JOIN cohort_size cs
    WHERE dr.day_since_install >= 0
    GROUP BY dr.day_since_install, cs.cohort_users_count
)
SELECT
    day_since_install,
    retained_users,
    ROUND(1.0 * retained_users / MAX(cohort_users_count) OVER (), 2)::numeric AS retention_rate
FROM agg
ORDER BY day_since_install;

-- Задача 4. Расчёт LTV
-- Рассчитать средний LTV для пользователей в Москве и Санкт‑Петербурге за всё время.
-- При расчёте считать, что каждый активный пользователь приносит 399 руб. в месяц (стоимость подписки Яндекс Плюс). Вывести:
-- city — название города/региона;
-- total_users — суммарное количество пользователей в городе/регионе;
-- ltv — средний LTV (округлённый до двух знаков после запятой).
-- Формула расчёта: общий доход / количество пользователей.

WITH activ AS (
    SELECT a.puid,
            g.usage_geo_id_name AS city,
            DATE_TRUNC('month', CAST(a.msk_business_dt_str AS date))::date AS start_month 
    FROM bookmate.audition a
    JOIN bookmate.geo g ON a.usage_geo_id=g.usage_geo_id
    WHERE a.puid IS NOT NULL AND CAST(a.msk_business_dt_str AS date) BETWEEN DATE '2024-09-01' AND DATE '2024-12-11'
    AND g.usage_geo_id_name IN ('Москва', 'Санкт-Петербург')
),
user_month_city AS (
    SELECT DISTINCT puid AS user_id, 
            city, 
            start_month
    FROM activ
),
city_agg AS (
    SELECT city,
            COUNT(DISTINCT user_id) AS total_users,
            COUNT(*) AS paid_months
    FROM user_month_city
    GROUP BY city
)
SELECT city,
        total_users::numeric,
        ROUND((paid_months * 399)::numeric / NULLIF(total_users, 0), 2)::numeric AS ltv
FROM city_agg
ORDER BY city;

-- Задача 5. Расчёт средней выручки прослушанного часа (аналог среднего чека)
-- Рассчитать ежемесячную среднюю выручку от часа чтения/прослушивания (с сентября по ноябрь) по формуле:
-- выручка (MAU × 399 руб.) / сумма прослушанных часов. Вывести:
-- month — месяц активности (первое число месяца в формате YYYY‑MM‑DD);
-- mau — значение MAU;
-- hours — общее количество прослушанных часов (округлённое до двух знаков после запятой);
-- avg_hour_rev — средняя выручка от часа чтения/прослушивания (округлённая до двух знаков после запятой).

WITH monthly AS(
    SELECT DATE_TRUNC('month', CAST(msk_business_dt_str AS date))::date AS month,
            puid,
            COALESCE(hours, 0)::numeric AS hours
    FROM bookmate.audition
    WHERE CAST(msk_business_dt_str AS date) BETWEEN DATE '2024-09-01' AND DATE '2024-11-30'
)
SELECT month,
        COUNT(DISTINCT puid) AS mau,
        ROUND(SUM(hours)::numeric, 2)::numeric AS hours,
        ROUND((COUNT(DISTINCT puid) * 399.0) / NULLIF(SUM(hours), 0), 2)::numeric AS avg_hour_rev
FROM monthly
GROUP BY month
ORDER BY month;

/*Подготовка данных для проверки гипотезы
С помощью SQL привести исходные данные из таблиц к виду, пригодному для проверки гипотезы в Python.
Отфильтровать пользователей — оставить только из Москвы и Санкт‑Петербурга.
Рассчитать для каждого пользователя суммарное количество часов активности.
Вывести следующие поля:
city — город пользователя;
puid — идентификатор пользователя;
hours — общее количество часов активности (вычисляется по полю hours).*/

WITH info AS (
    SELECT a.puid,
            COALESCE(a.hours,0)::numeric AS hours,
            g.usage_geo_id_name AS city
    FROM bookmate.audition a
    LEFT JOIN bookmate.geo g ON a.usage_geo_id=g.usage_geo_id
)
SELECT city,
        puid,
        SUM(hours)::numeric AS hours
FROM info
WHERE city IS NOT NULL AND city IN('Москва','Санкт-Петербург','Moscow','Saint Peterburg')
GROUP BY city, puid
ORDER BY city, hours DESC;
