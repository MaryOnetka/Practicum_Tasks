/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Сереженко Елена
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь

-- 1 способ:
	
WITH all_stat AS(
	SELECT COUNT(id) OVER() AS count_users, -- общее количество игроков
			ROUND(AVG(payer::numeric) OVER(),6) AS ratio_buyers, -- доля платящих игроков
			id,
			payer
	FROM fantasy.users
)
SELECT count_users,
		SUM(payer) AS count_buyers, -- общее число платящих игроков
		ratio_buyers 
FROM all_stat
WHERE payer=1 -- показатель покупки
GROUP BY count_users, ratio_buyers;

-- 2 способ:

SELECT COUNT(id) AS count_users,
		SUM(payer) AS count_buyers,
		ROUND(AVG(payer::numeric),6) AS ratio_buyers
FROM fantasy.users;

		

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь

-- 1 способ

WITH all_race AS(
	SELECT COUNT(race_id) OVER(PARTITION BY race_id) AS count_race, -- общее количество игроков по расам
			race_id,
			payer
	FROM fantasy.users
)
SELECT DISTINCT r.race,
		COUNT(ar.payer) AS count_race_buyers, -- количество платящих по расам
		ar.count_race,
		ROUND(COUNT(ar.payer)::numeric/ar.count_race,6) AS ratio_race -- доля платящих к общим по каждым расам
FROM all_race AS ar
LEFT JOIN fantasy.race AS r ON ar.race_id=r.race_id
WHERE payer=1
GROUP BY r.race, ar.count_race
ORDER BY ratio_race DESC; -- сортировка по количетсву игроков по расам

-- 2 способ

SELECT DISTINCT r.race,
		SUM(u.payer) AS count_race_buyers,
		COUNT(u.race_id) AS count_race,
		ROUND(SUM(u.payer)::NUMERIC/COUNT(u.race_id),6) AS ratio_race
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r ON u.race_id=r.race_id
GROUP BY r.race
ORDER BY ratio_race DESC;
		

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь

-- 1 способ

SELECT COUNT(amount) AS count_amounts, -- общее количество покупок
		SUM(amount) AS sum_amounts, -- общая сумма покупок
		MIN(amount) AS min_amount, -- минимальное значение суммы
		MAX(amount) AS max_amount, -- максимальное значение суммы
		ROUND(AVG(amount::numeric),6) AS avg_amounts, -- среднее сумм
		PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY amount) AS med_amount, -- медиана 
		ROUND(STDDEV(amount::numeric),6) AS stand_dev_amount -- стандартное отклонение по суммам
FROM fantasy.events;

-- 2 способ с дополнительным вычислением min значения без учёта нулевых покупок

SELECT COUNT(amount) AS count_amounts, -- общее количество покупок
		SUM(amount) AS sum_amounts, -- общая сумма покупок
		MIN(amount) AS min_amount, -- минимальное значение суммы
		(SELECT MIN(amount)
		FROM fantasy.events
		WHERE amount<>0) AS min_amount_without_null, -- минимальное значение без учёта нулевых покупок
		MAX(amount) AS max_amount, -- максимальное значение суммы
		ROUND(AVG(amount::numeric),6) AS avg_amounts, -- среднее сумм
		PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY amount) AS med_amount, -- медиана 
		ROUND(STDDEV(amount::numeric),6) AS stand_dev_amount -- стандартное отклонение по суммам
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь

-- 1 способ

WITH all_events AS (
	SELECT COUNT(*) OVER() AS all_events_am, -- общее число записей 
			amount
FROM fantasy.events
)
SELECT all_events_am,
		COUNT(*) AS null_amounts, -- число с нулевыми показателями
		ROUND(COUNT(*)::numeric/all_events_am, 6) AS ratio_null_am -- доля нулевых покупок к общему
FROM all_events 
WHERE amount=0
GROUP BY all_events_am;

-- 2 способ

SELECT COUNT(amount) AS all_events_am,
		COUNT(amount) FILTER (WHERE amount=0) AS null_amounts,
		ROUND(COUNT(amount) FILTER (WHERE amount=0)::NUMERIC/COUNT(amount),6) AS ratio_null_am
FROM fantasy.events;

-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь

SELECT i.game_items,
		e.item_code,
		COUNT(e.amount) AS count_amount, -- абсолютное значение продаж каждого
		ROUND(COUNT(e.amount)::NUMERIC/SUM(COUNT(e.amount)) OVER(),6) AS ratio_game, -- относительное значение продаж каждого
		ROUND(COUNT(DISTINCT id)::NUMERIC/
					(SELECT COUNT(DISTINCT id)
					FROM fantasy.events
					WHERE amount<>0)
				,6) AS ratio_us -- доля уникальных игроков, которые хотя бы раз купили этот предмет
FROM fantasy.events AS e
JOIN fantasy.items AS i ON e.item_code = i.item_code
WHERE e.amount <>0
GROUP BY e.item_code, i.game_items
ORDER BY count_amount DESC;

-- Доп.запрос: предметы, которые не покупали

SELECT	game_items AS do_not_buyed
FROM fantasy.events AS e
JOIN fantasy.items i ON e.item_code = i.item_code
GROUP BY game_items
HAVING COUNT(transaction_id) = 0;


-- Часть 2. Решение ad hoc-задачbи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH all_race AS(
  	SELECT COUNT(race_id) AS count_race, -- общее количество игроков по расам
			race_id
	FROM fantasy.users
	GROUP BY race_id
),

buyers AS(
	SELECT  race_id,
      		COUNT(id) AS count_buyers -- количество игроков, которые совершают внутриигровые покупки по расам
  FROM fantasy.users
  WHERE id IN (
  			SELECT id
  			FROM fantasy.events
  			WHERE amount <> 0)
  GROUP BY race_id
 ),
 
 ratio_race AS(
  	SELECT u.race_id,
			ROUND(COUNT(id)/b.count_buyers::NUMERIC,6) AS ratio_buyers -- доля платящих игроков по расам
FROM fantasy.users AS u
JOIN buyers AS b ON u.race_id=b.race_id
WHERE payer = 1 AND 
  		id IN (
  			SELECT id 
  			FROM fantasy.events 
  			WHERE amount <> 0) -- фильтрация
GROUP BY u.race_id,count_buyers
),

about_amount AS (
SELECT DISTINCT u.id,
		r.race_id,
		COUNT(transaction_id) OVER (PARTITION BY e.id, r.race_id) AS user_transac, -- количество транзакций на каждого пользователя
		SUM(amount) OVER (PARTITION BY e.id, r.race_id) AS sum_amount -- общая сумма затрат на каждого пользователя
FROM fantasy.events AS e 
JOIN fantasy.users AS u ON e.id=u.id
JOIN fantasy.race AS r ON u.race_id=r.race_id
WHERE amount<>0
)
SELECT race, -- Раса
    count_race, -- Количество игроков
    count_buyers, -- Покупающие игроки
    ROUND(count_buyers/count_race::numeric,6) AS count_buyers_not_null, -- Доля покупающих
    ratio_buyers, -- Доля платящих
    ROUND(AVG(user_transac::numeric),0) AS avg_amounts_user, -- СРД количесвто покупок
	ROUND(AVG(sum_amount::numeric)/AVG(user_transac),6) AS avg_amount_user, -- СРД стоимость одной покупки
	ROUND(AVG(sum_amount::numeric),6) AS avg_sum_amounts -- СРД стоимость всех покупок
FROM all_race AS ar
JOIN buyers AS b ON ar.race_id=b.race_id
JOIN ratio_race rr ON ar.race_id=rr.race_id
JOIN about_amount AS a ON ar.race_id = a.race_id
JOIN fantasy.race AS r ON ar.race_id = r.race_id 
GROUP BY race,
		count_race,
		count_buyers,
		ratio_buyers
ORDER BY count_race DESC;
