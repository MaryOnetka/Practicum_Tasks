* Название: Анализ активности клиентов и эффективности тарифных планов «Мегасеть».

* Цель проекта: проанализировать использование услуг связи клиентами компании «Мегасеть»
* по тарифным планам Smart и Ultra, оценить долю клиентов с перерасходом лимитов
* и подготовить данные для обновления линейки тарифов и разработки спецпредложений.
 
* Задачи аналитика:
* выгрузить данные об активности клиентов за календарный месяц:
** суммарная длительность звонков (с округлением вверх), объём интернет‑трафика, количество сообщений.
* рассчитать текущие траты клиентов с учётом тарифных лимитов и стоимости услуг сверх плана.
* для каждого тарифа рассчитать средние траты клиентов (учитывая только действующих пользователей).
* среди активных клиентов выделить тех, кто пользуется услугами сверх тарифного плана, и посчитать:
** средние расходы для каждого тарифа;
** среднее значение переплаты для каждого тарифа.
/
* Часть 1
/
  
- 1.1. Выгрузить первые 20 строк с информацией о пользователях и проверьте, что данные соответствуют описанию.

SELECT *
FROM telecom.users
LIMIT 20;

- 1.2. Проверить, что в данных для каждого пользователя нет пропусков.
- В результат запроса должны войти строки, которые содержат хотя бы один пропуск в любом поле таблицы.
- При этом не учитывать только поле user_id — это первичный ключ таблицы, и в нём не может быть пропусков.
- Выгрузить первые 10 строк итоговой таблицы.

SELECT *
FROM telecom.users
WHERE age IS NULL
        OR churn_date IS NULL
        OR city IS NULL
        OR first_name IS NULL
        OR last_name IS NULL
        OR reg_date IS NULL
        OR tariff IS NULL
LIMIT 10;

- 1.3. Посчитать долю активных клиентов. active_users_share, преобразовать результат к типу данных real.

SELECT 1-CAST(COUNT(churn_date)AS real)/COUNT(*) AS active_users_share
FROM telecom.users;

- 1.4. При расчётах важно, чтобы один клиент использовал только один тарифный план.
- Проверить, что за весь период у каждого активного клиента был только один тарифный план.
- В запросе отфильтровать данные и оставить только активных пользователей — тех,
- у кого в поле churn_date стоит пропуск.
- Вывести ID клиентов, у которых больше одного тарифного плана и количество тарифных планов у клиентов.

SELECT user_id,
        COUNT(tariff) AS all
FROM telecom.users
WHERE churn_date IS NULL
GROUP BY user_id
HAVING COUNT(tariff)>1;

- 1.5. Проверить, встречаются ли в этих данных пропуски, — вывести все строки таблицы calls,
- в которых встречаются пропуски в любом из полей, то есть в duration или call_date.

SELECT *
FROM telecom.calls
WHERE duration IS NULL
        OR call_date IS NULL;

- 1.6. Проверить возможные аномалии в данных о длительности разговора — определить минимальное и максимальное значения.
- Назвать столбцы min_duration и max_duration соответственно.

SELECT MIN(duration) AS min_duration,
        MAX(duration) AS max_duration
FROM telecom.calls;

- 1.7. Изучить долю пропущенных звонков. Посчитать долю звонков длительностью 0 минут от общего количества звонков
- и преобразовать результат к типу данных real.

WITH
nol AS (
    SELECT id,
            duration AS durat
    FROM telecom.calls
    WHERE duration=0
)
SELECT 
        COUNT(n.durat)::real/COUNT(*)
FROM telecom.calls AS c
LEFT JOIN nol AS n ON c.id=n.id;

- 1.8. Изучить общую длительность разговоров каждого пользователя в день — встречаются ли случаи,
- когда суммарная длительность превышала 24 часа. Эта проверка поможет оценить корректность данных. 
- Для каждого клиента посчитать длительность всех звонков за день, перевести это значение в часы
- и вывести топ-10 клиентов с высокими значениями общей длительности разговоров.
- Результат запроса должен включать такие поля:
-- user_id — идентификатор клиента;
-- call_date — дата звонка (данные уже приведены к нужному типу, менять тип данных не надо);
-- total_day_duration — суммарная длительность всех звонков клиента за день в часах.

SELECT u.user_id,
        c.call_date,
        SUM(duration)/60 AS total_day_duration
FROM telecom.users AS u
LEFT JOIN telecom.calls AS c ON u.user_id=c.user_id
WHERE duration IS NOT NULL
GROUP BY u.user_id, c.call_date
ORDER BY total_day_duration DESC
LIMIT 10;

/
* Часть 2
/
- monthly_duration: посчитать длительность звонков за месяц (округление вверх). Поля: user_id, dt_month, month_duration.
- monthly_internet: посчитать объём интернет‑трафика за месяц (без округления). Поля: user_id, dt_month, month_mb_traffic.
- monthly_sms: посчитать количество SMS за месяц. Поля: user_id, dt_month, month_sms.
- user_activity_months: объединить уникальные пары user_id + dt_month из трёх предыдущих CTE.
- users_stat: собрать все данные об активности в одну таблицу. Поля: user_id, dt_month, month_duration, month_mb_traffic, month_sms.
- user_over_limits: рассчитать перерасход по тарифам (Smart/Ultra) с полями duration_over, gb_traffic_over (МБ → ГБ / 1024),
- sms_over (0 при отсутствии перерасхода), вывести 10 отсортированных строк.

-- Суммарная длительность разговоров клиента в месяц:
WITH monthly_duration AS (
    SELECT user_id,
           -- Выделяем месяц из даты звонка: 
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
-- Суммарное количество потраченного интернет-трафика в месяц:
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
-- Суммарное количество сообщений в месяц:
monthly_sms AS (
    SELECT user_id,
           DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,  
           COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),
-- Формирование уникальной пары значений user_id и dt_month:
user_activity_months AS (
    -- Первое множество значений user_id и dt_month с учётом разговорной активности клиента:
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    -- Второе множество значений user_id и dt_month с учётом интернет-активности клиента:
    SELECT user_id, dt_month
    FROM monthly_internet   
    UNION
    -- Третье множество значений user_id и dt_month с учётом активности клиента по сообщениям:
    SELECT user_id, dt_month
    FROM monthly_sms
),
-- Соединение посчитанных значений активности клиента в одну таблицу:
users_stat AS (
    SELECT 
        u.user_id,
        u.dt_month,
        month_duration,
        month_mb_traffic,
        month_sms
    -- В качестве основной таблицы используем данные из CTE user_activity_months:
    FROM user_activity_months AS u
    -- Последовательно присоединяем данные по звонкам, интернет-трафику и сообщениям.
    -- При объединении данных используем пары значений user_id и dt_month:
    LEFT JOIN monthly_duration AS md ON u.user_id = md.user_id AND u.dt_month= md.dt_month
    LEFT JOIN monthly_internet AS mi ON u.user_id = mi.user_id AND u.dt_month= mi.dt_month
    LEFT JOIN monthly_sms AS mm ON u.user_id = mm.user_id AND u.dt_month= mm.dt_month
),
user_over_limits AS (
    SELECT us.user_id,
            us.dt_month,
            tariff,
            us.month_duration,
            us.month_mb_traffic,
            us.month_sms,
            CASE 
                WHEN us.month_duration>=t.minutes_included 
                THEN (us.month_duration-t.minutes_included)
                ELSE 0
                END AS duration_over,
            CASE 
                WHEN us.month_mb_traffic>=t.mb_per_month_included
                THEN (us.month_mb_traffic-t.mb_per_month_included)/1024
                ELSE 0
                END AS gb_traffic_over,
            CASE 
                WHEN us.month_sms>=t.messages_included
                THEN (us.month_sms-t.messages_included)
                ELSE 0
                END AS sms_over
    FROM users_stat AS us
    LEFT JOIN telecom.users AS u ON us.user_id=u.user_id
    JOIN telecom.tariffs AS t ON u.tariff=t.tariff_name

)
SELECT *
FROM user_over_limits
ORDER BY user_id, dt_month
LIMIT 10;

/
* Часть 3
/
- users_costs: рассчитать месячные траты клиентов (абонплата + перерасход) с использованием user_over_limits и tariffs.
- Поля: user_id, dt_month, tariff, month_duration, month_mb_traffic, month_sms, rub_monthly_fee, total_cost.
- Средние траты по тарифам: на основе users_costs посчитать для каждого тарифа:
-- tariff — название;
-- total_users — число клиентов;
-- avg_total_cost — средние траты (округление до 2 знаков).
- Клиенты с перерасходом: для каждого тарифа вывести:
-- tariff — название;
-- total_users — число клиентов с тратами > абонплаты;
-- avg_total_cost — средние траты (округление до 2 знаков);
-- overcost — средняя переплата относительно абонплаты (округление до 2 знаков).

-- Суммарная длительность разговоров клиента в месяц:
WITH monthly_duration AS (
    SELECT user_id,
           -- Выделяем месяц из даты звонка: 
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
-- Суммарное количество потраченного интернет-трафика в месяц:
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
-- Суммарное количество сообщений в месяц:
monthly_sms AS (
    SELECT user_id,
           DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,  
           COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),
-- Формирование уникальной пары значений user_id и dt_month:
user_activity_months AS (
    -- Первое множество значений user_id и dt_month с учётом разговорной активности клиента:
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    -- Второе множество значений user_id и dt_month с учётом интернет-активности клиента:
    SELECT user_id, dt_month
    FROM monthly_internet   
    UNION
    -- Третье множество значений user_id и dt_month с учётом активности клиента по сообщениям:
    SELECT user_id, dt_month
    FROM monthly_sms
),
-- Соединение подсчитанных значений по активности клиента в одну таблицу:
users_stat AS (
    SELECT u.user_id,
           u.dt_month,
           month_duration,
           month_mb_traffic,
           month_sms
    -- В качестве основной таблицы используем данные из CTE user_activity_months:
    FROM user_activity_months AS u
    -- Последовательно присоединяем данные по звонкам, интернет-трафику и сообщениям.
    -- При объединении данных используем пару значений user_id и dt_month:
    LEFT JOIN monthly_duration AS md ON u.user_id = md.user_id AND u.dt_month= md.dt_month
    LEFT JOIN monthly_internet AS mi ON u.user_id = mi.user_id AND u.dt_month= mi.dt_month
    LEFT JOIN monthly_sms AS mm ON u.user_id = mm.user_id AND u.dt_month= mm.dt_month
),
-- Превышение установленного лимита по каждому виду связи:
user_over_limits AS (
    SELECT us.user_id,
           us.dt_month,
           u.tariff,
           us.month_duration,
           us.month_mb_traffic,
           us.month_sms,
        -- Условие, если длительность разговоров клиента превышает установленный тарифом лимит:        
        CASE 
            WHEN us.month_duration >= t.minutes_included 
            THEN (us.month_duration - t.minutes_included)
            ELSE 0
        END AS duration_over,
        -- Условие, если количество интернет-трафика в месяц превышает установленный тарифом лимит:        
        CASE 
            WHEN us.month_mb_traffic >= t.mb_per_month_included 
            THEN (us.month_mb_traffic - t.mb_per_month_included) / 1024::real
            ELSE 0
        END AS gb_traffic_over,
        -- Условие, если количество сообщений в месяц превышает установленный тарифом лимит:        
        CASE 
            WHEN us.month_sms >= t.messages_included 
            THEN (us.month_sms - t.messages_included)
            ELSE 0
        END AS sms_over
    FROM users_stat AS us
    LEFT JOIN (SELECT tariff, user_id FROM telecom.users) AS u ON us.user_id = u.user_id
    LEFT JOIN telecom.tariffs AS t ON u.tariff = t.tariff_name
),
-- Траты клиента за каждый месяц:
users_costs AS (
    SELECT uol.user_id,
           uol.dt_month,
           uol.tariff,
           uol.month_duration,
           uol.month_mb_traffic,
           uol.month_sms,
           t.rub_monthly_fee, 
           t.rub_monthly_fee + uol.duration_over * t.rub_per_minute
           + uol.gb_traffic_over * t.rub_per_gb + uol.sms_over * t.rub_per_message AS total_cost 
    FROM user_over_limits AS uol
    LEFT JOIN telecom.tariffs AS t ON uol.tariff = t.tariff_name
)
SELECT uc.tariff,
        COUNT(DISTINCT(uc.user_id)) AS total_users,
        ROUND(AVG(uc.total_cost)::numeric,2) AS avg_total_cost,
        ROUND(AVG(uc.total_cost::numeric-uc.rub_monthly_fee::numeric),2) AS overcost
FROM users_costs AS uc
LEFT JOIN telecom.users AS u ON uc.user_id=u.user_id
WHERE u.churn_date IS NULL AND uc.total_cost::numeric>uc.rub_monthly_fee::numeric
GROUP BY uc.tariff;
