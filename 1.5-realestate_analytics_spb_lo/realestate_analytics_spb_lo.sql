/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Сереженко Елена
 * Дата: 23.10.2025
 * 		(25.10.2025 - правки)
*/


-- Данная часть кода носит исследовательский характер для себя

-- Разброс периода объявлений

SELECT MIN(first_day_exposition) AS first_day ,
		MAX(first_day_exposition) AS last_day
FROM real_estate.advertisement;

-- Типы населённых пунктов, количество их упоминаний в объявлениях и
-- само количество населённых пунктов по типам

SELECT type, -- тип населённого пункта
		type_id, --  код населённого пункта
		COUNT(id) AS qyantity_type, -- количество упоминаний
		COUNT(DISTINCT city_id) AS uniq_type -- количество населённых пунктов по типу
FROM real_estate.flats AS f
JOIN real_estate.type AS t USING (type_id)
GROUP BY type, type_id
ORDER BY qyantity_type DESC;

-- Статистика активности объявлений

SELECT MIN(days_exposition) AS min_days, -- min количество дней
		MAX(days_exposition) AS max_days, -- max количество дней
		ROUND(AVG(days_exposition::NUMERIC),2) AS avg_days, -- среднее значение активности объявления 
		PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY days_exposition) AS mediana_days -- медиана
FROM real_estate.advertisement;  

-- Процент проданных недвижемости

SELECT ROUND(COUNT(days_exposition)::NUMERIC*100/COUNT(id),2) AS sale_flats
FROM real_estate.advertisement;

-- Процент объявлений из Санкт-Петербурга

SELECT ROUND(COUNT
		(CASE 
			WHEN c.city = 'Санкт-Петербург'
    		THEN 1 
    	END) *100.0/COUNT(*),2) AS ad_spb
FROM real_estate.flats AS f
JOIN real_estate.city AS c USING (city_id);

-- Стоимость квадратного метра

SELECT ROUND(MIN(last_price/total_area)::NUMERIC,2) AS min_price, -- min стоимость метра
		MAX(last_price/total_area) AS max_price, -- max стоимость метра
		ROUND(AVG(last_price/total_area)::NUMERIC,2) AS avg_price, -- средняя цена метра 
		PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY last_price/total_area) AS mediana_price -- медиана
FROM real_estate.flats AS f
JOIN real_estate.advertisement AS a USING (id);

-- Статистические показатели по разным параметрам

SELECT MIN(total_area) AS min_area, -- по площади(min, max, среднее, медиана и 99 перцентиль)
		MAX(total_area) AS max_area,
		ROUND(AVG(total_area::NUMERIC),2) AS avg_area,
		PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY total_area) AS mediana_area,
		PERCENTILE_DISC(0.99) WITHIN GROUP(ORDER BY total_area) AS perc99_area,
		MIN(rooms) AS min_rooms, -- по количеству комнат(min, max, среднее, медиана и 99 перцентиль)
		MAX(rooms) AS max_rooms,
		ROUND(AVG(rooms),2) AS avg_rooms,
		PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY rooms) AS mediana_rooms,
		PERCENTILE_DISC(0.99) WITHIN GROUP(ORDER BY rooms) AS perc99_rooms,
		MIN(balcony) AS min_balcony, -- по количеству балконов(min, max, среднее, медиана и 99 перцентиль)
		MAX(balcony) AS max_balcony,
		ROUND(AVG(balcony::NUMERIC),2) AS avg_balcony,
		PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY balcony) AS mediana_balcony,
		PERCENTILE_DISC(0.99) WITHIN GROUP(ORDER BY balcony) AS perc99_balcony,
		MIN(ceiling_height) AS min_height, -- по высоте потолока(min, max, среднее, медиана и 99 перцентиль)
		MAX(ceiling_height) AS max_height,
		ROUND(AVG(ceiling_height::NUMERIC),2) AS avg_height,
		PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY ceiling_height) AS mediana_height,
		PERCENTILE_DISC(0.99) WITHIN GROUP(ORDER BY ceiling_height) AS perc99_height,
		MIN(floor) AS min_floor, -- этажность(min, max, среднее, медиана и 99 перцентиль)
		MAX(floor) AS max_floor,
		ROUND(AVG(floor),2) AS avg_floor,
		PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY floor) AS mediana_floor,
		PERCENTILE_DISC(0.99) WITHIN GROUP(ORDER BY floor) AS perc99_floor
FROM real_estate.flats;



-- ad hoc задачи
-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
sorting_cat AS (
	SELECT *,
		CASE 
			WHEN city='Санкт-Петербург' THEN 'Санкт-Петербург'
			ELSE 'Ленинградская обл'
		END AS region,
		CASE 
        	WHEN days_exposition<=30 THEN 'около месяца'
			WHEN days_exposition<=90 THEN 'от 1 до 3 мес'
        	WHEN days_exposition<=180 THEN 'от 3 мес до полугода'
        	WHEN days_exposition> 180 THEN 'более полугода'
        	ELSE 'non category'
		END AS act_days,
		last_price/total_area AS metr_price
    FROM real_estate.advertisement AS a 
    JOIN real_estate.flats AS f USING (id)
    JOIN real_estate.city AS c USING (city_id)
    WHERE f.id IN (SELECT id 
    			FROM filtered_id)
    AND type_id='F8EM' -- выборка по типу 'город'
    AND first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31') -- выборка за полные годы с 2015 по 2018
    SELECT region,
           act_days,
           COUNT(*) AS total_ads,
           ROUND(AVG(metr_price)::NUMERIC,2) AS avg_price,
           ROUND(AVG(total_area)::NUMERIC,2) AS avg_area,
           PERCENTILE_DISC (0.5) WITHIN GROUP (ORDER BY rooms) AS mediana_rooms,
           PERCENTILE_DISC (0.5) WITHIN GROUP (ORDER BY balcony) AS mediana_balcony,
           PERCENTILE_DISC (0.5) WITHIN GROUP (ORDER BY floor) AS mediana_floors,
           ROUND(COUNT(*)::NUMERIC/SUM(COUNT(*)) OVER(PARTITION BY region),3)*100 AS ratio_ads, -- доля объвлений в %
           ROUND(AVG(ceiling_height::NUMERIC),2) AS avg_height, -- средняя высота потолка
           ROUND(COUNT(*) FILTER (WHERE rooms=0)::NUMERIC/COUNT(*),3)*100 AS ratio_studio, -- доля студий в %
           ROUND(COUNT(*) FILTER (WHERE is_apartment=1)::NUMERIC/COUNT(*),3)*100 AS ratio_apartment, -- доля апартаментов в %
           ROUND(COUNT(*) FILTER (WHERE open_plan=1)::NUMERIC/COUNT(*),3)*100 AS ratio_open_plan, -- доля с открытой планировкой в %
           ROUND(AVG(airports_nearest::NUMERIC)/1000,2)  AS avg_airports, -- среднее расстояние до аэропорта в км
           PERCENTILE_DISC (0.5) WITHIN GROUP (ORDER BY parks_around3000) AS mediana_parks, -- медиана парков в радиусе 3 км
           PERCENTILE_DISC (0.5) WITHIN GROUP (ORDER BY ponds_around3000) AS mediana_ponds -- медиана водоёмов в радиусе 3 км
    FROM sorting_cat
    GROUP BY region, act_days
    ORDER BY region, total_ads DESC;



-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
set lc_time = 'ru_RU';
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats f 
    JOIN real_estate.type t ON  f.type_id = t.type_id
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
        AND type = 'город'
    ),
ad_nedv AS( -- Опубликованные по месяцам
	SELECT TO_CHAR(first_day_exposition, 'TMmon') AS month_ad,
			COUNT(id) AS ad_flats,
			ROUND(COUNT(id)/SUM(COUNT(id)) OVER()*100,2) AS ratio_ad, -- доля среди опубликованных в %
			ROUND(AVG(last_price/total_area)::NUMERIC,2) AS avg_price_metr_ad,
			ROUND(AVG(total_area)::NUMERIC,2) AS avg_square_ad
	FROM real_estate.advertisement a
	JOIN real_estate.flats f USING(id)
	WHERE a.id IN (SELECT *
					FROM filtered_id)
		AND first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
	GROUP BY month_ad
),
sales_ad AS ( -- Проданные по месяцам
	SELECT TO_CHAR(first_day_exposition+INTERVAL '1 day'*days_exposition, 'TMmon') AS month_end,
			COUNT(id) AS sale_flats,
			ROUND(COUNT(id)/SUM(COUNT(id)) OVER()*100,2) AS ratio_sale, --доля среди снятых в %
			ROUND(AVG(last_price/total_area)::NUMERIC,2) AS avg_price_metr_sale,
			ROUND(AVG(total_area)::NUMERIC,2) AS avg_square_sale
	FROM real_estate.advertisement
	JOIN real_estate.flats f USING(id)
	WHERE days_exposition IS NOT NULL
			AND id IN (SELECT *
						FROM filtered_id)
			AND first_day_exposition+INTERVAL '1 day'*days_exposition BETWEEN '2015-01-01' AND '2018-12-31'
	GROUP BY month_end
)
SELECT month_ad,
		ad_flats,
		ratio_ad,
		avg_price_metr_ad,
		avg_square_ad,
		DENSE_RANK() OVER(ORDER BY ad_flats DESC) AS rank_new, -- ранк по месяцам внутри опубликованных объявлений
		sale_flats,
		ratio_sale,
		avg_price_metr_sale,
		avg_square_sale,
		DENSE_RANK() OVER(ORDER BY sale_flats DESC) AS rank_sale -- ранк по месяцам внутри снятых с публикации
FROM ad_nedv AS a
JOIN sales_ad AS s ON a.month_ad=s.month_end
ORDER BY month_ad;