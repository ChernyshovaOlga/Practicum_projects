/* Проект «Секреты Тёмнолесья»
 * Цель проекта: оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Чернышова Ольга Владимировна
 * Дата: 30.08.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
WITH count_all AS(
SELECT 
COUNT(u.tech_nickname) AS count_id,
SUM(CASE WHEN u.payer = '1' THEN 1 ELSE 0 END) AS count_payer_id
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id)
select 
count_id, --общее количество игроков, зарегистрированных в игре,
count_payer_id,-- количество платящих игроков 
count_payer_id::numeric/count_id as proportion_payer --доля платящих игроков от общего количества пользователей, зарегистрированных в игре
from count_all;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
WITH count_all as (
SELECT r.race,
COUNT(u.tech_nickname) AS count_id,
SUM(CASE WHEN u.payer = '1' THEN 1 ELSE 0 END) AS count_payer_id
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
GROUP BY r.race)
SELECT 
race,
count_id, 
count_payer_id,
count_payer_id::numeric / count_id as proportion_payer
FROM count_all
ORDER BY proportion_payer;
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
WITH amount_all AS(
SELECT
COUNT(e.amount) as count_amount,--общее количество покупок, 
SUM(e.amount) as sum_amount, --суммарную стоимость всех покупок
MIN(e.amount) as min_amount, --минимальную стоимость покупки
MAX(e.amount) as max_amount, --максимальную стоимость покупки
AVG(e.amount) as avg_amount, --среднее значение стоимости покупки.
STDDEV(e.amount) AS stand_dev,-- стандартное отклонение стоимости покупки. 
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.amount) as mediana_amount
FROM fantasy.events as e
LEFT JOIN fantasy.users AS u ON e.id = u.id),
cte_1 as (select 
count_amount,--общее количество покупок, 
sum_amount, --суммарную стоимость всех покупок
min_amount, --минимальную стоимость покупки
max_amount, --максимальную стоимость покупки
avg_amount, --среднее значение стоимости покупки.
stand_dev,-- стандартное отклонение стоимости покупки. 
mediana_amount --медиана стоимости покупки,
from amount_all),
amount_all_2 AS(
SELECT
COUNT(e.amount) as count_amount,--общее количество покупок, 
SUM(e.amount) as sum_amount, --суммарную стоимость всех покупок
MIN(e.amount) as min_amount, --минимальную стоимость покупки
MAX(e.amount) as max_amount, --максимальную стоимость покупки
AVG(e.amount) as avg_amount, --среднее значение стоимости покупки.
STDDEV(e.amount) AS stand_dev,-- стандартное отклонение стоимости покупки. 
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.amount) as mediana_amount
FROM fantasy.events as e
LEFT JOIN fantasy.users AS u ON e.id = u.id
where (e.amount) > 0),
cte_2 AS(select 
count_amount,--общее количество покупок, 
sum_amount, --суммарную стоимость всех покупок
min_amount, --минимальную стоимость покупки
max_amount, --максимальную стоимость покупки
avg_amount, --среднее значение стоимости покупки.
stand_dev,-- стандартное отклонение стоимости покупки. 
mediana_amount --медиана стоимости покупки,
from amount_all_2)
SELECT * FROM cte_1
UNION
SELECT * FROM cte_2;
-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
SELECT 
COUNT(*) FILTER (WHERE amount = 0) AS zero_amounts, -- количество нулевых покупок
COUNT(*) AS total_amounts, -- общее количество покупок
COUNT(*) FILTER (WHERE amount = 0)::REAL / COUNT(*) AS zero_share -- доля нулевых покупок
FROM fantasy.events;  
-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь
SELECT
i.game_items,
COUNT(e.amount) AS count_amount,-- количество продаж для каждого предмета
COUNT(e.amount) / SUM(COUNT(e.amount)) OVER () AS sales_share,-- доля продаж каждого предмета от всех продаж по количеству
(COUNT(DISTINCT u.id)::numeric / (SELECT COUNT(DISTINCT u.id) FROM fantasy.users AS u 
LEFT join fantasy.events AS e ON u.id = e.id WHERE e.amount > 0)) AS player_share-- доля игроков, которые хотя бы раз покупали этот предмет, от общего числа внутриигровых покупателей
FROM fantasy.users AS u 
LEFT join fantasy.events AS e ON u.id = e.id
LEFT JOIN fantasy.items AS i ON e.item_code = i.item_code
WHERE e.amount > 0
GROUP by i.game_items
ORDER BY count_amount DESC;
-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH count_all as(
SELECT race_id,
COUNT(id) AS count_id_all--общее количество зарегистрированных игроков
FROM fantasy.users 
GROUP BY race_id),
buyers_pliers AS(
SELECT
race_id, 
COUNT(id) AS num_buyers,-- количество игроков, которые совершают внутриигровые покупки
AVG(payer) AS part_payers-- доля платящих
FROM fantasy.users  
WHERE id IN (SELECT id FROM fantasy.events e WHERE e.amount > 0)
GROUP BY race_id)
SELECT
r.race, 
c.count_id_all,--общее количество зарегистрированных игроков
b.num_buyers,--количество игроков, которые совершают внутриигровые покупки
(b.num_buyers/c.count_id_all::numeric) AS share_pay_players,--доля игроков, которые совершают внутриигровые покупки от общего количества
b.part_payers,-- доля платящих от количества игроков, которые совершили покупки
(COUNT(e.amount)::numeric/b.num_buyers) AS avg_purchases_per_player,----среднее количество покупок на одного игрока
(SUM(e.amount)::numeric/COUNT(e.amount)) AS avg_cost_per_purchase,--средняя стоимость одной покупки на одного игрока
(SUM(e.amount)::numeric/b.num_buyers) AS avg_sum_per_player--средняя суммарная стоимость всех покупок на одного игрока
FROM buyers_pliers as b
JOIN count_all as c ON b.race_id = c.race_id
LEFT JOIN fantasy.race as r ON b.race_id = r.race_id
JOIN fantasy.events AS e ON r.race_id = (SELECT race_id FROM fantasy.users WHERE id = e.id and e.amount > 0)
GROUP BY r.race, c.count_id_all, b.num_buyers, b.part_payers;




