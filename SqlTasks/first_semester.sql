select count(*) from coffe_shop.product;

select unit_price from coffe_shop.sales where transaction_id = 110;
select 
	count(distinct transaction_id)
from coffe_shop.sales 
where 1=1
	and quantity>3;
	
select 
	count(*)
from coffe_shop.sales 
where 1=1
	and product_category = 'Coffee'
	and store_address = '100 Church Street';
	
select 
	beverage_goal + food_goal
from coffe_shop.sales_targets 
where 1=1
	and sales_outlet_id = 8;

--1) Раздел 2. Извлечение, фильтрация и преобразование данных:  ПЗ "Попарная сортировка"
select
	customer_id
	, case when mod(customer_id, 2) = 0 then customer_id - 1
		else customer_id + 1
	end as customer_id_new
	, customer_name
from coffe_shop.customer
where 1=1
	and customer_id <= 100
order by customer_id;

--2) Раздел 3. Агрегация: ПЗ DataQuality (будет самым последним в теме)
select * from coffe_shop.customer_corrupted limit 5;

select 
	customer_name
	, case when regexp_like(customer_name, '^[A-Z][a-z]*\s[A-Z][a-z]*$')
	then 1 else 0 end as name_check
from coffe_shop.customer_corrupted;

select 
	email
	, case when regexp_like(email, '^[^\s@]+@[^\s@A-Z]+\.[a-z]{2,3}$')
	then 1 else 0 end as email_check
from coffe_shop.customer_corrupted;

select 
	birth_year
	, case when extract(year from current_date) - birth_year <= 100
	then 1 else 0 end as year_check
from coffe_shop.customer_corrupted;

select distinct gender from coffe_shop.customer_corrupted;

with raw_table as (
	select 
		customer_id
		, case 
			when (customer_name is not null
				and email is not null
				and gender is not null
				and birthdate is not null)
			then 1 else 0 end as completeness
		, case 
			--customer_name состоит из двух слов, каждое начинается с большой буквы и состоит только из латиницы
			when regexp_like(customer_name, '^[A-Z][a-z]*\s[A-Z][a-z]*$')
				--email содержит @ и оканчивается на домен верхнего уровня (длиной 2-3 символа после точки), доменная часть не содержит больших букв
				and regexp_like(email, '^[^\s@]+@[^\s@A-Z]+\.[a-z]{2,3}$')
				--проверяем возраст, используем birthdate, так как заполненность birthdate и birth_year не совпадает
				and extract(year from current_date) - CAST(SUBSTRING(birthdate, 1, 4) AS INTEGER) <= 100
			then 1 else 0 end as conformity
	from coffe_shop.customer_corrupted
)
select
	--по логике условия conformity нельзя проверить полностью без выполнения всех условий completeness, поэтому дана доля строк с completeness и conformity и отдельно с completeness
	round(sum(completeness) / COUNT(customer_id)::decimal, 2) as completeness
	, round(sum(conformity) / sum(completeness)::decimal, 2) as conformity
	, round(sum(conformity) / COUNT(customer_id)::decimal, 2) as conformity_and_completeness
from raw_table;

--3) Раздел 4. Объединение таблиц и подзапросы: задачи с 3 по 7 
--(Собираем витрину, Используем витрину, Доля покупающих, RFM, Metric - value)
with raw_table as (
	select
		customer_id
		, max(transaction_date) as last_purchase
		, count(distinct transaction_id) as num_purchases
		, sum(unit_price) * sum(quantity) as revenue
	from coffe_shop.sales
	group by customer_id
)
select
	case 
		when current_date - last_purchase > 15 then 1
		when current_date - last_purchase < 7 then 3
		else 2
	end as recency
	, case 
		when num_purchases < 10 then 1
		when num_purchases >= 23 then 3
		else 2
	end as frequency
	, case 
		when revenue < 50 then 1
		when num_purchases >= 110 then 3
		else 2
	end as monetary
	, sum(revenue) as revenue
from raw_table
group by 1,2,3;


/*
Сегменты, начинающиеся на 2 и 3 отсутствуют, так как максимальная дата в таблице - 2019-04-29

Либо нужны более актуальные данные,
либо нужно взять дату, от которой мы считаем сегменты (если мы хотим оценить ситуацию в прошлом),
либо покупатели забросили нашу кофейню
*/
select * from coffe_shop.sales limit 5;

--Сегмент 122 нужно попытаться реактивировать, чтобы пользователи снова зашли в кофейню, так как они активно делали покупки

/*
1. Фильтрация нужных сессий
Создайте временную таблицу, которая будет содержать данные о сессиях пользователей из таблицы mobile_game.sessions за апрель 2023 года. Временная таблица должна содержать:
user_id
session_start_time
После создания временной таблицы выполните SELECT для вывода данных о сессиях пользователей.
*/

CREATE TEMPORARY TABLE sessions_april AS (
SELECT
	user_id,
	session_start_time
FROM mobile_game.sessions
WHERE 1=1
	AND session_start_time >= '2023-04-01'
	AND session_start_time<'2023-05-01'
);

SELECT
	table_schema,
	table_name
FROM information_schema.tables
WHERE table_name = 'revenue_march_june'

SELECT * FROM pg_temp_95.sessions_april;

/*
2. Анализ поведения пользователей с использованием временных таблиц
Работая с данными из схемы mobile_game БД project, создайте 3 временные таблицы:
Первая временная таблица должна содержать информацию о пользователях и их общей выручке из таблицы transactions за период с марта 2023 года по июнь 2023 года.
Вторая временная таблица должна содержать информацию о количестве сессий пользователей из таблицы sessions за тот же период.
Объедините эти две временные таблицы в третьей с помощью JOIN по полю user_id, чтобы получить информацию о выручке и количестве сессий для каждого платящего пользователя за этот период.
Выведите пользователей, у которых общая выручка превышает 100, и количество сессий больше 5.
Напишите аналогичный запрос без использования временных таблиц и сравните скорость выполнения.
*/

CREATE TEMPORARY TABLE revenue_march_june AS (
    SELECT 
        user_id, 
        SUM(revenue * quantity) AS total_revenue
    FROM mobile_game.transactions
    WHERE 1=1 
    	AND event_date >= '2023-03-01' 
        AND event_date < '2023-07-01'
    GROUP BY 1
);

CREATE TEMPORARY TABLE sessions_march_june AS (
    SELECT 
        user_id, 
        COUNT(*) AS session_count
    FROM mobile_game.sessions
    WHERE 1=1 
        AND session_start_time >= '2023-03-01' 
        AND session_start_time < '2023-07-01'
    GROUP BY 1
);

CREATE TEMPORARY TABLE revenue_sessions_march_june AS (
    SELECT 
        r.user_id, 
        r.total_revenue, 
        s.session_count
    FROM pg_temp_9.revenue_march_june r
    	JOIN pg_temp_9.sessions_march_june s
    		ON r.user_id = s.user_id
);

SELECT 
    user_id, 
    total_revenue, 
    session_count
FROM pg_temp_9.revenue_sessions_march_june
WHERE 1=1
    and total_revenue > 100 
    AND session_count > 5;
    
SELECT 
    r.user_id, 
    r.total_revenue, 
    s.session_count
FROM 
    (SELECT 
        user_id, 
        SUM(revenue * quantity) AS total_revenue
     FROM mobile_game.transactions
     WHERE 1=1
        AND event_date >= '2023-03-01' 
        AND event_date < '2023-07-01'
     GROUP BY 1) r
	JOIN 
	    (SELECT 
	        user_id, 
	        COUNT(*) AS session_count
	     FROM 
	        mobile_game.sessions
	     WHERE 1=1
	        AND session_start_time >= '2023-03-01' 
	        AND session_start_time < '2023-07-01'
	     GROUP BY 1) s
		ON r.user_id = s.user_id
WHERE 1=1
    and r.total_revenue > 100 
    AND s.session_count > 5;
    
/*
3. Когортный анализ активных в марте игроков
Напишите код, который создаст временную таблицу, которая поможет провести когортный анализ для пользователей, которые были активны в марте 2023 года, с учетом их часовых поясов. Анализ должен показать, сколько пользователей возвращалось в приложение (имели сессии) в последующие месяцы.
Создайте временную таблицу, которая будет отображать когортный анализ по месяцам: сколько пользователей из когорты марта 2023 возвращалось в следующие месяцы (апрель, май и т.д.) до декабря 2023 года.
Учитывайте временные зоны пользователей при вычислении дат начала сессий.
С использование созданной временной таблицы напишите запрос, который выведет:
Месяц когорты (март, апрель и т.д.).
Количество пользователей, которые вернулись в этом месяце.
Процент возврата относительно числа пользователей, начавших взаимодействие в марте.
Работаем с БД project и схемой mobile_game
*/
   
CREATE TEMPORARY TABLE cohort_analysis AS (
    WITH march_users AS (
        SELECT 
            user_id, 
            session_start_time AT TIME ZONE user_info.timezone AS local_session_start_time
        FROM mobile_game.sessions 
        	LEFT JOIN mobile_game.user_info
        		USING(user_id)
        WHERE 1=1
            and session_start_time >= '2023-03-01' 
            AND session_start_time < '2023-04-01'
    ), subsequent_sessions AS (
        SELECT 
            user_id, 
            session_start_time AT TIME ZONE user_info.timezone AS local_session_start_time
        FROM mobile_game.sessions
            LEFT JOIN mobile_game.user_info
        		USING(user_id)
        WHERE 1=1
            and session_start_time >= '2023-04-01' 
            AND session_start_time < '2023-12-01'
    ), cohort_data AS (
        SELECT 
            mu.user_id,
            DATE_TRUNC('month', mu.local_session_start_time) AS cohort_month,
            DATE_TRUNC('month', ss.local_session_start_time) AS return_month
        FROM march_users mu
        	LEFT JOIN subsequent_sessions ss
        		ON mu.user_id = ss.user_id
    )
    SELECT 
        cohort_month,
        return_month,
        COUNT(DISTINCT user_id) AS returning_users
    FROM cohort_data
    GROUP BY 1,2
);

SELECT
	table_schema,
	table_name
FROM information_schema.tables
WHERE table_name = 'cohort_analysis'

SELECT 1 FROM pg_temp_38.cohort_analysis;

WITH total_users_per_cohort AS (
    SELECT 
        DATE_TRUNC('month', local_session_start_time) AS cohort_month,
        COUNT(DISTINCT user_id) AS total_users
    FROM 
        (SELECT 
            s.user_id, 
            s.session_start_time AT TIME ZONE u.timezone AS local_session_start_time
        FROM mobile_game.sessions s
        	JOIN mobile_game.user_info u
        		ON s.user_id = u.user_id
        WHERE 1=1
            and s.session_start_time >= '2023-03-01' 
            AND s.session_start_time < '2023-04-01') AS march_users
    	GROUP BY 1
)
SELECT 
    ca.cohort_month,
    ca.returning_users,
    ROUND(100.0 * ca.returning_users / tu.total_users, 2) AS return_percentage
FROM pg_temp_38.cohort_analysis ca
	JOIN total_users_per_cohort tu
		ON ca.cohort_month = tu.cohort_month
ORDER BY 1;