/*
Задание: 
Вам даны данные по событиям игроков в некоторой мобильной игре. Они представляют собой систему из нескольких таблиц: 
1.	Таблица с транзакциями игроков
2.	Таблица с сессиями игроков
3.	Таблица с характеристиками игроков - страна, платежный сегмент, платформа и т.п. 

На основании дерева метрик, которое мы изучили в видео 5.2, необходимо:
1.	Проанализировать динамику выручки в различных разрезах и понять, есть ли в ней аномалии 
2.	Используя дерево метрик, найти причины наблюдаемой динамики 

Описание таблиц: 
1.	sessions - таблица с сессиями игроков:
	a.	user_id - уникальный идентификатор игрока
	b.	session_start_time - дата/время старта сессии игрока
2.	transactions - таблица с транзакциями игроков:
	a.	transaction_id - уникальный идентификатор транзакции
	b.	user_id - уникальный идентификатор игрока
	c.	event_date - дата транзакции
	d.	product_id - id продукта
	e.	product_name - наименование продукта
	f.	revenue - выручка
	g.	quantity - количество купленного продукта
3.	user_info - таблица с информацией о игроке:
	a.	user_id - уникальный идентификатор игрока
	b.	user_start_date - дата первой игровой сессии
	c.	country - страна игрока
	d.	timezone - таймзона игрока
	e.	payer_segment - платежный сегмент 
	f.	platform - ОС игрока
	g.  channel - канал, к которому мы атрибуциурем игрока
*/




--EDA
--mobile_game.user_info
select * from mobile_game.user_info limit 5; 
--нулевых значений нет
select 
	count(user_id)
	, count(user_start_date)
	, count(country)
	, count(timezone)
	, count(payer_segment)
	, count(platform)
from mobile_game.user_info;

--дублей нет
select 
	count(user_id)
	, count(distinct user_id)
from mobile_game.user_info t;

--больше всего юзеров из США (288к), затем из Индии (82к), затем из Германии (69к)
--всего 7 стран - 'USA', 'India', 'Germany', 'Brazil', 'Japan', 'UK', 'Italy'
select 
	country
	, count(user_id)
from mobile_game.user_info t
group by 1
order by 2 desc;

--всего 8 часовых поясов - America/New_York, America/Los_Angeles, Asia/Calcutta, Europe/Berlin, posix/Brazil/West, posix/Asia/Tokyo, Europe/London, Europe/Rome
select 
	country
	, timezone
	, count(user_id)
from mobile_game.user_info t
group by 1, 2
order by 3 desc;

--всего 4 сегмента (0, 1, 2, 3), каждый следующий сегмент меньше предыдущего
select 
	payer_segment
	, count(user_id)
from mobile_game.user_info t
group by 1
order by 2 desc;

--users_touches
select * from mobile_game.users_touches ut limit 5;

--нулевых значений нет
select 
	count(user_id)
	, count(touch_date)
	, count(channel) 
from mobile_game.users_touches;

--есть дубли, нужно присваивать источник последнего касания по last click
--627182 уникальных значения user_id
select 
	count(distinct user_id)
from mobile_game.users_touches;

--создадим временную локальную таблицу, чтобы использовать её в запросах вместо users_touches (размер таблицы позволяет)
create local temporary table users_touches_last on commit preserve rows as (
select distinct on (user_id) user_id, touch_date, channel
from mobile_game.users_touches
where 1=1
order by user_id, touch_date desc);

/*
--для построения графиков
with users_touches_last as (
	select distinct on (user_id) user_id, touch_date, channel
	from mobile_game.users_touches
	where 1=1
	order by user_id, touch_date desc
)
 */

select * from users_touches_last limit 5;
--627182 значения
select count(*) from users_touches_last;

--всего 3 канала: 'adwords', 'applovin', 'organic'
select distinct channel from mobile_game.users_touches ut; 

--mobile_game.transactions
select * from mobile_game.transactions limit 5; 
--нулевых значений нет
select 
	count(transaction_id)
	, count(user_id)
	, count(event_date)
	, count(product_id)
	, count(product_name)
	, count(revenue)
	, count(quantity) 
from mobile_game.transactions;

--дублей нет
select 
	count(transaction_id)
	, count(distinct transaction_id)
from mobile_game.transactions t;

--есть только quantity = 1
select 
	quantity
	, sum(revenue) as revenue
from mobile_game.transactions t 
group by 1;

--mobile_game.sessions
select * from mobile_game.sessions limit 5; 
--нулевых значений нет
select 
	count(user_id)
	, count(session_start_time)
from mobile_game.sessions;

--все пользователи из таблицы user_info имеют сессии
--для всех сессий у нас есть информация по пользователю
select 
	count(distinct s.user_id)
	, count(distinct ui.user_id)
from mobile_game.user_info ui
	left join mobile_game.sessions s
		using(user_id);

---------------------------------------------------------------------------
--Расчёт выручки
--общая выручка
select 
	event_date
	, sum(revenue) as revenue
from mobile_game.transactions t 
group by 1;

--выручка по продуктам
select 
	event_date
	, product_name
	, sum(revenue) as revenue
from mobile_game.transactions t 
group by 1, 2;
--по какой-то причине последняя продажа продукта sale была сделана 2023-10-23, а у остальных продуктов 2023-12-15

--общая выручка без sale
select 
	event_date
	, sum(revenue) as revenue
from mobile_game.transactions t 
where 1=1
	and product_name != 'sale'
group by 1;

select 
	product_name
	, max(event_date)
from mobile_game.transactions t 
group by 1;

--есть падение в 1 сегменте даже за вычетом продукта sale
select 
	event_date
	, payer_segment
	, sum(revenue) as revenue
from mobile_game.transactions t 
	inner join mobile_game.user_info ui
		on t.user_id = ui.user_id
		and t.product_name != 'sale'
group by 1;

--выручка падает во всех каналах
select 
	event_date
	, utl.channel
	, sum(revenue) as revenue
from mobile_game.transactions t 
	inner join users_touches_last utl
		on t.user_id = utl.user_id
		and t.product_name != 'sale'
group by 1, 2;

--есть падение в 1 сегменте даже за вычетом продукта sale
select 
	event_date
	, platform
	, sum(revenue) as revenue
from mobile_game.transactions t 
	inner join mobile_game.user_info ui
		on t.user_id = ui.user_id
		and t.product_name != 'sale'
group by 1,2;


--в Индии выручка падает с начала декабря
--в США выручка стагнирует с октября
select 
	event_date
	, ui.country
	, sum(revenue) as revenue
from mobile_game.transactions t 
	inner join mobile_game.user_info ui
		on t.user_id = ui.user_id
		and t.product_name != 'sale'
group by 1, 2;

--проблемы с 1 и 2 сегментом есть только в Индии
select 
	event_date
	, ui.payer_segment
	, sum(revenue) as revenue
from mobile_game.transactions t 
	inner join mobile_game.user_info ui
		on t.user_id = ui.user_id
		and t.product_name != 'sale'
		and ui.country != 'India'
group by 1, 2;

--в Индии нет какого-то одного проблемного канала привлечения
select 
	event_date
	, utl.channel
	, sum(revenue) as revenue
from mobile_game.transactions t 
	inner join mobile_game.user_info ui
		on t.user_id = ui.user_id
		and t.product_name != 'sale'
		and ui.country = 'India'
		and ui.payer_segment in (1, 2)
	inner join users_touches_last utl
		on t.user_id = utl.user_id
group by 1, 2;

--в США стагнируют источники неорганического трафика
select 
	event_date
	, utl.channel
	, sum(revenue) as revenue
from mobile_game.transactions t 
	inner join mobile_game.user_info ui
		on t.user_id = ui.user_id
		and t.product_name != 'sale'
		and ui.country = 'USA'
	inner join users_touches_last utl
		on t.user_id = utl.user_id
group by 1, 2;


select 
	event_date
	, channel
	, sum(revenue) as revenue
from mobile_game.transactions t 
	inner join mobile_game.user_info ui
		on t.user_id = ui.user_id
		and t.product_name != 'sale'
        --and ui.country = 'USA'
        and ui.country != 'India'
        and ui.platform = 'ios'
    inner join users_touches_last utl
        on t.user_id = utl.user_id
group by 1,2;

--adwords есть только на андроид
select distinct
	channel
	, ui.platform 
from mobile_game.user_info ui
    inner join users_touches_last utl
        on ui.user_id = utl.user_id
group by 1,2;


select 
	event_date
	, channel
	, sum(revenue) as revenue
from mobile_game.transactions t 
	inner join mobile_game.user_info ui
		on t.user_id = ui.user_id
		and t.product_name != 'sale'
        and ui.country != 'India'
        --and ui.platform != 'ios'
    inner join users_touches_last utl
        on t.user_id = utl.user_id
group by 1,2;

---------------------------------------------------------------------------
--Расчёт dau
select 
	session_start_time::date as event_date
	, count(distinct user_id) as dau
from mobile_game.sessions s 
group by 1;

select 
	session_start_time::date as event_date
	, ui.country 
	, count(distinct s.user_id) as dau
from mobile_game.sessions s 
	left join mobile_game.user_info ui 
		on s.user_id = ui.user_id
group by 1,2;

select 
	session_start_time::date as event_date
	, ui.payer_segment 
	, count(distinct s.user_id) as dau
from mobile_game.sessions s 
	left join mobile_game.user_info ui 
		on s.user_id = ui.user_id
group by 1,2;

select 
	session_start_time::date as event_date
	, ui.platform 
	, count(distinct s.user_id) as dau
from mobile_game.sessions s 
	left join mobile_game.user_info ui 
		on s.user_id = ui.user_id
group by 1,2;

--есть проблема в канале applovin
select 
	session_start_time::date as event_date
	, utl.channel 
	, count(distinct s.user_id) as dau
from mobile_game.sessions s 
	left join users_touches_last utl
        on s.user_id = utl.user_id
group by 1,2;

---------------------------------------------------------------------------
--Расчёт New Installs
with first_session as (
	select 
		user_id
		, min(session_start_time) as first_session_start_time
	from mobile_game.sessions s 
	group by 1
)
select 
	first_session_start_time::date as event_date
	, count(distinct ui.user_id) as new_installs
from first_session fs 
	inner join mobile_game.user_info ui 
		on ui.user_start_date = fs.first_session_start_time::date 
group by 1;

with first_session as (
	select 
		user_id
		, min(session_start_time) as first_session_start_time
	from mobile_game.sessions s 
	group by 1
)
select 
	first_session_start_time::date as event_date
	, ui.country 
	, count(distinct ui.user_id) as new_installs
from first_session fs 
	left join mobile_game.user_info ui 
		on ui.user_start_date = fs.first_session_start_time::date 
group by 1,2;

with first_session as (
	select 
		user_id
		, min(session_start_time) as first_session_start_time
	from mobile_game.sessions s 
	group by 1
)
select 
	first_session_start_time::date as event_date
	, ui.payer_segment 
	, count(distinct ui.user_id) as new_installs
from first_session fs 
	left join mobile_game.user_info ui 
		on ui.user_start_date = fs.first_session_start_time::date 
group by 1,2;

with first_session as (
	select 
		user_id
		, min(session_start_time) as first_session_start_time
	from mobile_game.sessions s 
	group by 1
)
select 
	first_session_start_time::date as event_date
	, ui.platform 
	, count(distinct ui.user_id) as new_installs
from first_session fs 
	left join mobile_game.user_info ui 
		on ui.user_start_date = fs.first_session_start_time::date 
group by 1,2;

--есть проблема в канале applovin
with first_session as (
	select 
		user_id
		, min(session_start_time) as first_session_start_time
	from mobile_game.sessions s 
	group by 1
)
select 
	first_session_start_time::date as event_date
	, utl.channel 
	, count(distinct ui.user_id) as new_installs
from first_session fs 
	left join mobile_game.user_info ui 
		on ui.user_start_date = fs.first_session_start_time::date 
	left join users_touches_last utl
        on fs.user_id = utl.user_id
group by 1,2;

---------------------------------------------------------------------------
--Расчёт Returning Users
--проверим расчёт
with first_session as (
	select 
		user_id
		, min(session_start_time) as first_session_start_time
	from mobile_game.sessions s 
	group by 1
)
select 
	s.session_start_time::date as event_date
	, count(distinct ui.user_id) as dau
	, count(distinct case when ui.user_start_date = fs.first_session_start_time::date then ui.user_id else null end) as new_users
	, count(distinct case when ui.user_start_date != fs.first_session_start_time::date then ui.user_id else null end) as returning_users
from mobile_game.sessions s
	left join mobile_game.user_info ui 
		 on s.user_id = ui.user_id
	left join first_session fs
		on ui.user_id = fs.user_id
group by 1;

with first_session as (
	select 
		user_id
		, min(session_start_time) as first_session_start_time
	from mobile_game.sessions s 
	group by 1
)
select 
	s.session_start_time::date as event_date
	, ui.country
	, count(distinct case when ui.user_start_date != fs.first_session_start_time::date then ui.user_id else null end) as returning_users
from mobile_game.sessions s
	left join mobile_game.user_info ui 
		 on s.user_id = ui.user_id
	left join first_session fs
		on ui.user_id = fs.user_id
group by 1,2;

with first_session as (
	select 
		user_id
		, min(session_start_time) as first_session_start_time
	from mobile_game.sessions s 
	group by 1
)
select 
	s.session_start_time::date as event_date
	, ui.payer_segment 
	, count(distinct case when ui.user_start_date != fs.first_session_start_time::date then ui.user_id else null end) as returning_users
from mobile_game.sessions s
	left join mobile_game.user_info ui 
		 on s.user_id = ui.user_id
	left join first_session fs
		on ui.user_id = fs.user_id
group by 1,2;

with first_session as (
	select 
		user_id
		, min(session_start_time) as first_session_start_time
	from mobile_game.sessions s 
	group by 1
)
select 
	s.session_start_time::date as event_date
	, ui.platform 
	, count(distinct case when ui.user_start_date != fs.first_session_start_time::date then ui.user_id else null end) as returning_users
from mobile_game.sessions s
	left join mobile_game.user_info ui 
		 on s.user_id = ui.user_id
	left join first_session fs
		on ui.user_id = fs.user_id
group by 1,2;

with first_session as (
	select 
		user_id
		, min(session_start_time) as first_session_start_time
	from mobile_game.sessions s 
	group by 1
)
select 
	s.session_start_time::date as event_date
	, utl.channel 
	, count(distinct case when ui.user_start_date != fs.first_session_start_time::date then ui.user_id else null end) as returning_users
from mobile_game.sessions s
	left join mobile_game.user_info ui 
		 on s.user_id = ui.user_id
	left join first_session fs
		on ui.user_id = fs.user_id
	left join users_touches_last utl
		on ui.user_id = utl.user_id
group by 1,2;

---------------------------------------------------------------------------
--Расчёт ARPDAU
select 
	session_start_time::date as event_date
	, sum(t.revenue) / count(distinct s.user_id) as arpdau
from mobile_game.sessions s 
	left join mobile_game.transactions t
		on s.user_id = t.user_id
		and s.session_start_time::date = t.event_date::date
	left join mobile_game.user_info ui 
		on s.user_id = ui.user_id
group by 1;

--есть проблемы в Индии
select 
	session_start_time::date as event_date
	, ui.country
	, sum(t.revenue) / count(distinct s.user_id) as arpdau
from mobile_game.sessions s 
	left join mobile_game.transactions t
		on s.user_id = t.user_id
		and s.session_start_time::date = t.event_date::date
	left join mobile_game.user_info ui 
		on s.user_id = ui.user_id
group by 1,2;

select 
	session_start_time::date as event_date
	, ui.payer_segment 
	, sum(t.revenue) / count(distinct s.user_id) as arpdau
from mobile_game.sessions s 
	left join mobile_game.transactions t
		on s.user_id = t.user_id
		and s.session_start_time::date = t.event_date::date
	left join mobile_game.user_info ui 
		on s.user_id = ui.user_id
group by 1,2;

select 
	session_start_time::date as event_date
	, ui.platform 
	, sum(t.revenue) / count(distinct s.user_id) as arpdau
from mobile_game.sessions s 
	left join mobile_game.transactions t
		on s.user_id = t.user_id
		and s.session_start_time::date = t.event_date::date
	left join mobile_game.user_info ui 
		on s.user_id = ui.user_id
group by 1,2;

select 
	session_start_time::date as event_date
	, t.product_name 
	, sum(t.revenue) / count(distinct s.user_id) as arpdau
from mobile_game.sessions s 
	left join mobile_game.transactions t
		on s.user_id = t.user_id
		and s.session_start_time::date = t.event_date::date
group by 1,2;

select 
	session_start_time::date as event_date
	, utl.channel 
	, sum(t.revenue) / count(distinct s.user_id) as arpdau
from mobile_game.sessions s 
	left join mobile_game.transactions t
		on s.user_id = t.user_id
		and s.session_start_time::date = t.event_date::date
	left join users_touches_last utl
        on s.user_id = utl.user_id
group by 1,2;

---------------------------------------------------------------------------
--Расчёт ARPPU
select 
	t.event_date::date as event_date
	, sum(t.revenue) / count(distinct t.user_id) as arppu
from mobile_game.transactions t
	left join mobile_game.user_info ui 
		on t.user_id = ui.user_id
group by 1;

--есть проблемы в Индии
select 
	t.event_date::date as event_date
	, ui.country
	, sum(t.revenue) / count(distinct t.user_id) as arppu
from mobile_game.transactions t
	left join mobile_game.user_info ui 
		on t.user_id = ui.user_id
group by 1, 2;

select 
	t.event_date::date as event_date
	, ui.payer_segment 
	, sum(t.revenue) / count(distinct t.user_id) as arppu
from mobile_game.transactions t
	left join mobile_game.user_info ui 
		on t.user_id = ui.user_id
group by 1, 2;

select 
	t.event_date::date as event_date
	, ui.platform 
	, sum(t.revenue) / count(distinct t.user_id) as arppu
from mobile_game.transactions t
	left join mobile_game.user_info ui 
		on t.user_id = ui.user_id
group by 1, 2;

select 
	t.event_date::date as event_date
	, t.product_name 
	, sum(t.revenue) / count(distinct t.user_id) as arppu
from mobile_game.transactions t
group by 1, 2;

select 
	t.event_date::date as event_date
	, utl.channel 
	, sum(t.revenue) / count(distinct t.user_id) as arppu
from mobile_game.transactions t
	left join mobile_game.user_info ui 
		on t.user_id = ui.user_id
	left join users_touches_last utl
        on t.user_id = utl.user_id
group by 1,2;

select 
	t.event_date::date as event_date
	, sum(t.revenue) / count(distinct t.user_id) as arppu
from mobile_game.transactions t
	inner join mobile_game.user_info ui 
		on t.user_id = ui.user_id
		and ui.country != 'India'
		and t.product_name != 'sale'
group by 1;

---------------------------------------------------------------------------
--Расчёт CR (Конверсия в платящего пользователя)
select 
	session_start_time::date as event_date
	, count(distinct t.user_id)::float / count(distinct s.user_id) as cr
from mobile_game.sessions s 
	left join mobile_game.transactions t
		on s.user_id = t.user_id
		and s.session_start_time::date = t.event_date::date
group by 1;

--есть проблемы в Индии
select 
	session_start_time::date as event_date
	, ui.country 
	, count(distinct t.user_id)::float / count(distinct s.user_id) as cr
from mobile_game.sessions s 
	left join mobile_game.transactions t
		on s.user_id = t.user_id
		and s.session_start_time::date = t.event_date::date
	left join mobile_game.user_info ui 
		on s.user_id = ui.user_id
group by 1,2;

select 
	session_start_time::date as event_date
	, ui.payer_segment 
	, sum(t.revenue) / count(distinct s.user_id) as arpdau
from mobile_game.sessions s 
	left join mobile_game.transactions t
		on s.user_id = t.user_id
		and s.session_start_time::date = t.event_date::date
	left join mobile_game.user_info ui 
		on s.user_id = ui.user_id
group by 1,2;

select 
	session_start_time::date as event_date
	, ui.platform 
	, sum(t.revenue) / count(distinct s.user_id) as arpdau
from mobile_game.sessions s 
	left join mobile_game.transactions t
		on s.user_id = t.user_id
		and s.session_start_time::date = t.event_date::date
	left join mobile_game.user_info ui 
		on s.user_id = ui.user_id
group by 1,2;

select 
	session_start_time::date as event_date
	, t.product_name 
	, sum(t.revenue) / count(distinct s.user_id) as arpdau
from mobile_game.sessions s 
	left join mobile_game.transactions t
		on s.user_id = t.user_id
		and s.session_start_time::date = t.event_date::date
group by 1,2;

select 
	session_start_time::date as event_date
	, utl.channel 
	, sum(t.revenue) / count(distinct s.user_id) as arpdau
from mobile_game.sessions s 
	left join mobile_game.transactions t
		on s.user_id = t.user_id
		and s.session_start_time::date = t.event_date::date
	left join users_touches_last utl
        on s.user_id = utl.user_id
group by 1,2;

--Расчёт среднего чека и среднего количества транзакций для анализа по странам
select 
	event_date::date as event_date
	, ui.country
	, avg(t.revenue) as avg_check
	, count(t.transaction_id)::float / count(distinct t.user_id) as tr_per_user
from mobile_game.transactions t
	left join mobile_game.user_info ui 
		on t.user_id = ui.user_id
group by 1,2;

--средний чек одинаков по странам и не меняется во времени для каждого из продуктов
--в Индии стали покупать меньше валюты
select 
	t.product_name
	, ui.country
	, avg(t.revenue) as avg_check
	, count(t.transaction_id)::float / count(distinct t.user_id) as tr_per_user
from mobile_game.transactions t
	left join mobile_game.user_info ui 
		on t.user_id = ui.user_id
group by 1,2;

--в Индии стали покупать меньше валюты
select 
	event_date::date as event_date
	, case when t.event_date = ui.user_start_date then 'new_users' else 'old_users' end as user_type
	, count(t.transaction_id)::float / count(distinct t.user_id) as tr_per_user
from mobile_game.transactions t
	inner join mobile_game.user_info ui 
		on t.user_id = ui.user_id
		and t.product_name = 'hard_currency'
		and ui.country = 'India'
group by 1,2;

--не обнаружено изменений
select 
	s.session_start_time::date as event_date
	, ui.payer_segment 
	, count(s.user_id)::float / count(distinct s.user_id) as sessions_per_user
from mobile_game.sessions s 
	inner join mobile_game.user_info ui 
		on s.user_id = ui.user_id
		and ui.country = 'India'
group by 1,2;

---------------------------------------------------------------------------
--Расчёт Retention
with day_zero_users as (
    select 
    	count(distinct s.user_id) as total_users_on_day_zero
    from mobile_game.user_info ui
        inner join mobile_game.sessions s
            on ui.user_id = s.user_id
            and s.session_start_time::date = ui.user_start_date
)
select 
    s.session_start_time::date  - ui.user_start_date as active_day
    , count(distinct s.user_id)::float / max(dzu.total_users_on_day_zero) as retention
from mobile_game.user_info ui 
    inner join mobile_game.sessions s
        on ui.user_id = s.user_id
        and s.session_start_time::date >= ui.user_start_date
    cross join day_zero_users dzu
group by 1;

with day_zero_users as (
    select 
    	ui.country 
    	, count(distinct s.user_id) as total_users_on_day_zero
    from mobile_game.user_info ui
        inner join mobile_game.sessions s
            on ui.user_id = s.user_id
            and s.session_start_time::date = ui.user_start_date
    group by 1
)
select 
    s.session_start_time::date  - ui.user_start_date as active_day
    , ui.country 
    , count(distinct s.user_id)::float / max(dzu.total_users_on_day_zero) as retention
from mobile_game.user_info ui 
    inner join mobile_game.sessions s
        on ui.user_id = s.user_id
        and s.session_start_time::date >= ui.user_start_date
    left join day_zero_users dzu
    	on dzu.country = ui.country 
group by 1, 2;

with users_touches_last as (
    select distinct on (user_id) user_id, touch_date, channel
    from mobile_game.users_touches
    where 1=1
    order by user_id, touch_date desc
), day_zero_users as (
    select 
    	utl.channel 
    	, count(distinct s.user_id) as total_users_on_day_zero
    from mobile_game.user_info ui
        inner join mobile_game.sessions s
            on ui.user_id = s.user_id
            and s.session_start_time::date = ui.user_start_date
        left join users_touches_last utl
        	on s.user_id = utl.user_id
    group by 1
)
select 
    s.session_start_time::date  - ui.user_start_date as active_day
    , utl.channel 
    , count(distinct s.user_id)::float / max(dzu.total_users_on_day_zero) as retention
from mobile_game.user_info ui 
    inner join mobile_game.sessions s
        on ui.user_id = s.user_id
        and s.session_start_time::date >= ui.user_start_date
    left join users_touches_last utl
        on s.user_id = utl.user_id
    left join day_zero_users dzu
    	on dzu.channel = utl.channel 
group by 1, 2;