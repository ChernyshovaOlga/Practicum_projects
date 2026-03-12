/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Чернышова О.В.
 * Дата: 20.09.2025
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
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
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
regions as (
SELECT *,
CASE--категоризация по региональному признаку
WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
ELSE 'ЛенОбл'
END AS region,
CASE--Категоризация по времени активности
WHEN a.days_exposition <= 30 THEN 'до месяца'
WHEN a.days_exposition >= 31 AND a.days_exposition <= 90 THEN 'от одного до трёх месяцев'
WHEN a.days_exposition >= 91 AND a.days_exposition <= 180 THEN 'от трёх месяцев до полугода'
WHEN a.days_exposition >= 181 THEN 'более полугода'
ELSE 'non category'
END AS day_category
FROM real_estate.flats as f
left join real_estate.city as c USING (city_id)
left JOIN real_estate.advertisement AS a USING (id)
left join real_estate.type as t USING (type_id)
INNER join filtered_id as fi USING (id)
WHERE a.first_day_exposition::timestamp BETWEEN '2015-01-01 00:00:00' AND '2018-12-31 23:59:59' 
and t.type = 'город')
select region, day_category, 
COUNT(days_exposition::numeric) as number_of_ads,--Количество объявлений в каждом сегменте
COUNT(days_exposition) / SUM(COUNT(days_exposition)) OVER () AS  share_of_ads,--долю объявлений в разрезе каждого региона
ROUND(AVG(last_price::numeric/total_area::numeric), 2) as avg_a_price,--средняя стоимость за кв.м
ROUND(AVG(total_area::numeric), 2) AS avg_total_area,-- средняя плошадь
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) as percentile_romms,--медиана количества комнат
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) as percentile_balcony,--медиана количества балконов
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floors_total) as percentile_floors_total,--медиана этажности
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) as percentile_floor--медиана этажа
from regions
group by region, day_category
order by number_of_ads DESC;
-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
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
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
publication_stats AS (
SELECT 
TO_CHAR(a.first_day_exposition, 'Month') AS publication_month_name, -- месяц публикации объявления
COUNT(a.days_exposition::numeric) AS number_of_ads,--количество опубликованных объявлений 
ROUND(SUM(last_price::numeric)/SUM(total_area::numeric), 2) AS avg_a_price,-- среднюю стоимость квадратного метра
ROUND(AVG(total_area::numeric), 2) AS avg_total_area--среднюю площадь недвижимости.
FROM real_estate.flats AS f
left join real_estate.city as c USING (city_id)
left JOIN real_estate.advertisement AS a USING (id)
left join real_estate.type as t USING (type_id)
INNER join filtered_id as fi USING (id)
WHERE a.first_day_exposition::timestamp BETWEEN '2015-01-01 00:00:00' AND '2018-12-31 23:59:59'
AND t.type = 'город'
GROUP BY publication_month_name),
removal_stats AS (
SELECT 
TO_CHAR((a.first_day_exposition + (a.days_exposition || ' days')::INTERVAL), 'Month') AS removal_month_name, -- месяц снятия объявления
COUNT(a.days_exposition::numeric) number_of_ads_removal,----количество снятых объявлений
ROUND(SUM(last_price::numeric)/SUM(total_area::numeric), 2) AS avg_a_price_removal,-- среднюю стоимость квадратного метра
ROUND(AVG(total_area::numeric), 2) AS avg_total_area_removal--среднюю площадь недвижимости.
FROM real_estate.flats AS f
left join real_estate.city as c USING (city_id)
left JOIN real_estate.advertisement AS a USING (id)
left join real_estate.type as t USING (type_id)
INNER join filtered_id as fi USING (id)
WHERE a.first_day_exposition::timestamp BETWEEN '2015-01-01 00:00:00' AND '2018-12-31 23:59:59'
AND t.type = 'город' and days_exposition IS NOT NULL
GROUP BY removal_month_name)
SELECT 
publication_month_name,
number_of_ads,
number_of_ads / SUM(number_of_ads) OVER () AS share_of_published_ads, -- доля опубликованных объвлений от всех объявлений
RANK() OVER (ORDER BY number_of_ads DESC) AS rank_published,-- ранг по количеству опубликованных объявлений
avg_a_price,
avg_total_area,
removal_month_name,
number_of_ads_removal,
number_of_ads_removal / SUM(number_of_ads_removal) OVER () AS share_of_removed_ads, -- доля снятых объвлений от всех объявлений
RANK() OVER (ORDER BY number_of_ads_removal DESC) AS rank_removed, -- ранг по количеству снятых объявлений
avg_a_price_removal,
avg_total_area_removal
FROM publication_stats
FULL JOIN removal_stats ON publication_month_name = removal_month_name
order by avg_a_price DESC;