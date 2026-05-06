--1. Упрощенный список продаж
CREATE VIEW table_view_tasks.sales_summary_fomin_p_a AS
SELECT 
    transaction_id,
    transaction_date,
    product_id,
    quantity,
    unit_price
FROM coffe_shop.sales_reciepts;
	
--2. VIEW с перформансом сотрудников за апрель 2019 года
CREATE VIEW table_view_tasks.staff_performance_fomin_p_a AS
WITH experienced_staff AS (
    SELECT staff_id
    FROM coffe_shop.staff
    WHERE EXTRACT(YEAR FROM AGE(CURRENT_DATE, start_date::date)) > 1
)
SELECT 
    sr.staff_id,
    s.first_name || ' ' || s.last_name AS staff_name,
    SUM(sr.quantity) AS total_quantity_sold,
    AVG(sr.quantity * sr.unit_price) AS avg_check
FROM coffe_shop.sales_reciepts sr
	JOIN coffe_shop.staff s 
		ON sr.staff_id = s.staff_id
	JOIN experienced_staff es 
		ON sr.staff_id = es.staff_id
WHERE 1=1
	AND sr.transaction_date >= '2019-04-01' 
	AND sr.transaction_date < '2019-05-01'
GROUP BY 1,2;

--3. Многослойный анализ производительности кофеен
--Основная информация по продажам
CREATE VIEW table_view_tasks.sales_summary_bystore_fomin_p_a AS
SELECT 
    sr.sales_outlet_id,
    SUM(sr.quantity * sr.unit_price) AS total_sales,
    AVG(sr.quantity * sr.unit_price) AS avg_check,
    COUNT(sr.transaction_id) AS total_transactions
FROM coffe_shop.sales_reciepts sr
GROUP BY 1;

--Детализированная информация по продажам с промо-акциями
CREATE VIEW table_view_tasks.promo_sales_summary_fomin_p_a AS
SELECT 
    sr.sales_outlet_id,
    SUM(sr.quantity * sr.unit_price) AS total_promo_sales,
    AVG(sr.quantity * sr.unit_price) AS avg_promo_check,
    COUNT(sr.transaction_id) AS total_promo_transactions
FROM coffe_shop.sales_reciepts sr
WHERE sr.promo_item_yn = 'Y'
GROUP BY 1;
   
--Итоговое VIEW с сортировкой по наибольшей выручке
CREATE VIEW table_view_tasks.full_store_performance_fomin_p_a AS
SELECT 
    ss.sales_outlet_id,
    ss.total_sales,
    ss.avg_check,
    ss.total_transactions,
    ps.total_promo_sales,
    ps.avg_promo_check,
    ps.total_promo_transactions,
    (ps.total_promo_sales / ss.total_sales) * 100 AS promo_sales_percentage
FROM table_view_tasks.sales_summary_bystore_fomin_p_a ss
	LEFT JOIN table_view_tasks.promo_sales_summary_fomin_p_a ps 
		ON ss.sales_outlet_id = ps.sales_outlet_id
ORDER BY 1 DESC;
    