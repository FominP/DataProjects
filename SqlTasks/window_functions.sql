/*
1. Топ-10 продаваемых товаров
Напишите запрос, который выводит топ 10 самых продаваемых товаров каждый день
и проранжируйте их по дням и кол-ву проданных штук.
*/

WITH daily_sales AS (
    SELECT 
        sr.transaction_date::date AS transaction_date,
        p.product_name,
        SUM(sr.quantity) AS quantity_sold_per_day
    FROM coffe_shop.sales_reciepts sr
    	JOIN coffe_shop.product p 
    		ON sr.product_id = p.product_id
    GROUP BY 1,2
), ranked_sales AS (
    SELECT 
        transaction_date,
        product_name,
        quantity_sold_per_day,
        ROW_NUMBER() OVER (PARTITION BY transaction_date ORDER BY quantity_sold_per_day DESC) AS rating
    FROM daily_sales
)
SELECT 
    transaction_date,
    product_name,
    quantity_sold_per_day,
    rating
FROM ranked_sales
WHERE rating <= 10
ORDER BY 1,2;

/*
2. Кумулятивные продажи по дням
Напишите запрос, которые рассчитает кумулятивное число проданных продуктов по транзакциям.
*/

WITH cumulative_sales AS (
    SELECT 
        sr.transaction_date::date AS transaction_date,
        transaction_id,
        sr.quantity
    FROM coffe_shop.sales_reciepts sr
)
SELECT 
    transaction_date,
    quantity,
    SUM(quantity) OVER (ORDER BY transaction_date, transaction_id) AS com_quantity
FROM cumulative_sales
ORDER BY 1;

/*
3. Отклонение от максимальной продажи в дне
Напишите запрос, который по каждому менеджеру магазина и по каждому дню
выведет выручку кофешопа и отклонение этой выручки от максимальной выручки лучшего в этот день магазина. 
*/

WITH daily_revenue AS (
    SELECT 
        sr.transaction_date::date AS transaction_date,
        so.manager,
        SUM(sr.quantity * REPLACE(REPLACE(p.current_retail_price, '$', ''), ' ', '')::float) AS revenue
    FROM coffe_shop.sales_reciepts sr
    	JOIN coffe_shop.product p 
    		ON sr.product_id = p.product_id
    	JOIN coffe_shop.sales_outlet so 
    		ON sr.sales_outlet_id = so.sales_outlet_id
    GROUP BY 1,2
), max_daily_revenue AS (
    SELECT 
        transaction_date,
        MAX(revenue) AS max_revenue
    FROM daily_revenue
    GROUP BY transaction_date
), manager_names AS (
    SELECT 
        s.staff_id,
        CONCAT(s.last_name, ' ', s.first_name) AS manager_full_name
    FROM coffe_shop.staff s
)
SELECT 
    dr.transaction_date,
    mn.manager_full_name AS manager,
    dr.revenue,
    (m.max_revenue - dr.revenue) AS max_revenue_diff
FROM daily_revenue dr
	JOIN max_daily_revenue m 
		ON dr.transaction_date = m.transaction_date
	JOIN manager_names mn 
		ON dr.manager = mn.staff_id
ORDER BY 1,2;

/*
1. Среднее количество потерянных продуктов по кофешопам
Напишите запрос, который на 2019-04-07 выведет количество потерянных продуктов
в каждом отдельном кофешопе и среднее количество потерянных продуктов
по каждому из product_id среди всех кофешопов. 
*/

WITH waste_data AS (
    SELECT 
        pi.product_id,
        pi.sales_outlet_id,
        SUM(pi.waste) AS waste
    FROM coffe_shop.pastry_inventory pi
    WHERE pi.transaction_date = '04/07/2019'
    GROUP BY 1,2
)
SELECT 
    wd.product_id,
    wd.sales_outlet_id,
    wd.waste,
    AVG(wd.waste) OVER (PARTITION BY wd.product_id) AS avg_waste
FROM waste_data wd
ORDER BY 1,2;

/*
2. Сотрудники выше среднего
Напишите запрос, который посчитает количество сотрудников по магазинам, у которых выручка от продаж выше, чем в средняя выручка на сотрудника по магазину.
В запросе должны использоваться оконные функции.
*/

WITH sales_data AS (
    SELECT 
        sr.sales_outlet_id,
        sr.staff_id,
        SUM(sr.quantity * REPLACE(REPLACE(p.current_retail_price, '$', ''), ' ', '')::float) AS sales_amount
    FROM coffe_shop.sales_reciepts sr
    	JOIN coffe_shop.product p 
    		ON sr.product_id = p.product_id
    GROUP BY 1,2
), avg_sales_per_staff AS (
    SELECT 
        sales_outlet_id,
        AVG(sales_amount) AS avg_sales_per_staff
    FROM sales_data
    GROUP BY 1
)
SELECT 
    sd.sales_outlet_id,
    COUNT(sd.staff_id) AS staff_qty
FROM sales_data sd
	JOIN avg_sales_per_staff aps 
		ON sd.sales_outlet_id = aps.sales_outlet_id
WHERE sd.sales_amount > aps.avg_sales_per_staff
GROUP BY 1
ORDER BY 1;

/*
1. Разница выручки между текущим и предыдущим днями
Напишите запрос, который рассчитывает разницу между выручкой в текущий и предыдущий день по данным таблицы coffe_shop.sales
*/
WITH daily_revenue AS (
    SELECT 
        sr.transaction_date::date AS transaction_date,
        SUM(sr.quantity * REPLACE(REPLACE(p.current_retail_price, '$', ''), ' ', '')::float) AS sales_amount
    FROM coffe_shop.sales_reciepts sr
    	JOIN coffe_shop.product p 
    		ON sr.product_id = p.product_id
    GROUP BY sr.transaction_date::date
)
SELECT 
    transaction_date,
    sales_amount,
    LAG(sales_amount) OVER (ORDER BY transaction_date) AS prev_sales_amount,
    sales_amount - LAG(sales_amount) OVER (ORDER BY transaction_date) AS difference_sales_amount,
    (sales_amount - LAG(sales_amount) OVER (ORDER BY transaction_date)) / 
        NULLIF(LAG(sales_amount) OVER (ORDER BY transaction_date), 0) * 100 AS percent_difference
FROM daily_revenue
ORDER BY transaction_date;
 
/*
2. Скользящее среднее
Посчитайте 3-дневное скользящее среднее выручки каждого из кофешопов по дням.
*/
WITH daily_revenue AS (
    SELECT 
        sr.sales_outlet_id,
        sr.transaction_date::date AS transaction_date,
        SUM(sr.quantity * REPLACE(REPLACE(p.current_retail_price, '$', ''), ' ', '')::float) AS revenue
    FROM coffe_shop.sales_reciepts sr
    	JOIN coffe_shop.product p 
    		ON sr.product_id = p.product_id
    GROUP BY 1,2
)
SELECT 
    sales_outlet_id,
    transaction_date,
    revenue,
    AVG(revenue) OVER (
        PARTITION BY sales_outlet_id 
        ORDER BY transaction_date 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3_days
FROM daily_revenue
ORDER BY 1,2;
    
/*
3. Изменения в процентах от среднего
Определить процентные изменения продаж между текущей продажей и средними продажами за последние 5 дней.
*/
WITH daily_sales AS (
    SELECT 
        sr.sales_outlet_id,
        sr.transaction_date::date AS transaction_date,
        SUM(sr.quantity) AS quantity
    FROM 
        coffe_shop.sales_reciepts sr
    GROUP BY 
        1,2
)
SELECT 
    sales_outlet_id,
    transaction_date,
    quantity,
	(quantity - AVG(quantity) OVER (
        PARTITION BY sales_outlet_id 
        ORDER BY transaction_date 
        ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
    )) / NULLIF(AVG(quantity) OVER (
        PARTITION BY sales_outlet_id 
        ORDER BY transaction_date 
        ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
    ), 0) * 100 AS percent_change_sales
FROM daily_sales
ORDER BY 1,2;