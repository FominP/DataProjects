----------------------
-- Исследуем данные --
----------------------
select *
from puzzle.all_events ae 
limit 5;

--Есть ли пропущенные значения в обычных столбцах? - проблем не найдено
select 
	count(*)
	, count(event_time)
	, count(user_id)
	, count(country)
	, count(platform)
	, count(app_version)
	, count(event_name)
	, count(user_properties)
	, count(event_properties)
from puzzle.all_events ae;

select min(event_time), max(event_time) from puzzle.all_events ae;

--Какие страны есть в таблице? - проблем не найдено
select country, count(*)
from puzzle.all_events ae 
group by 1 

--Какие платформы есть в таблице? - проблем не найдено
select platform, count(*)
from puzzle.all_events ae 
group by 1 

--Какие версии приложения указаны в таблице? - проблем не найдено
select app_version, count(*)
from puzzle.all_events ae 
group by 1 

--Какие события есть в таблице? Сколько каждых событий? 
select event_name, count(*)
from puzzle.all_events ae 
group by 1 

--Как устроены новые события level_completed/failed?
select event_properties
from puzzle.all_events ae 
where event_name ilike '%level%'
limit 100

--Проверка значений на NULL
select 
	event_properties ->> 'errors' is null as errors,
	event_properties ->> 'attempt' is null as attempt,
	event_properties ->> 'level_number' is null as level_number,
	event_properties ->> 'level_hardness' is null as level_hardness,
	event_properties ->> 'currency_spent_clues' is null as currency_spent_clues, 
	event_properties ->> 'currency_spent_lives' is null as currency_spent_lives,
	count(*)
from puzzle.all_events ae 
where event_name in ('level_completed', 'level_failed')
group by 1,2,3,4,5,6 
--currency_spent_lives/clues = NULL, их нужно обработать

--Проверка на дубли
select count(*)
from (
select 
	user_id 
	,event_time 
	,user_properties 
	,event_properties 
	,event_name 
	,app_version 
	,platform 
	,country 
from puzzle.all_events ae
group by 1,2,3,4,5,6,7,8 
having count(*) > 1 
) _ 
--В исходной таблице есть дубли

-----------------------------------------
-- Временные таблицы с чистыми данными --
-----------------------------------------

------------------------
--all_events без дублей
drop table if exists temp_all_events;

create temp table temp_all_events as 
select distinct 
	user_id 
	, event_time 
	, user_properties 
	, event_properties 
	, event_name 
	, app_version 
	, platform 
	, country 
from puzzle.all_events;

------------------------
--sessions
drop table if exists temp_sessions;

create temp table temp_sessions as 
select 
    event_time
    , user_id
    , country
    , platform
    , app_version
    -- flattened user_properties without prefix
    , user_properties
    , (user_properties->'segments'->>'gaming_skill')::int as segments_gaming_skill
    , (user_properties->'segments'->>'payer_segment')::int as segments_payer_segment
    , (user_properties->'channels_touch'->>-1)::text as last_click_channel
    , (user_properties->>'first_install_date')::date as first_install_date
from temp_all_events
where event_name = 'session_start';

--Проверим период - проблем не найдено
select min(first_install_date), max(first_install_date)
from temp_sessions;

------------------------
--attempts
drop table if exists temp_attempts;

create temp table temp_attempts as 
select 
    event_time
    , user_id
    , country
    , platform
    , app_version
    , event_name as attempt_result
    -- flattened user_properties without prefix
    , (user_properties->'segments'->>'gaming_skill')::int as segments_gaming_skill
    , (user_properties->'segments'->>'payer_segment')::int as segments_payer_segment
    , (user_properties->'channels_touch'->>-1)::text as last_click_channel
    , (user_properties->>'first_install_date')::date as first_install_date
    -- flattened event_properties without prefix, handling null values
    , coalesce((event_properties->>'errors')::int, 0) as errors
    , coalesce((event_properties->>'attempt')::int, 0) as attempt
    , coalesce((event_properties->>'level_number')::int, null) as level_number
    , coalesce((event_properties->>'level_hardness')::int, null) as level_hardness
    , coalesce(nullif(event_properties->>'currency_spent_clues', '')::int, 0) as currency_spent_clues
    , coalesce(nullif(event_properties->>'currency_spent_lives', '')::int, 0) as currency_spent_lives
from temp_all_events
where event_name in ('level_completed', 'level_failed');

-- Проверка на дубли попыток
select
    user_id
    , event_time
    --, level_number
    , attempt_result
    , count(*)
from temp_attempts a
where 1=1
group by 1,2,3
having count(*) > 1;
-- Есть собыьтия, которые приходят одновременно по нескольким уровням
-- Это ошибка, либо это читеры, так как проставляется level_completed

--Проверяем, что каждая следующая попытка была позже предыдущей
with attempts_with_lag as (
    select
        user_id
        , level_number
        , attempt
        , event_time
        , lag(event_time) over (
            partition by user_id, level_number
            order by attempt
        ) as previous_event_time
    from temp_attempts
)
select
    user_id
    , level_number
    , attempt
    , event_time
    , previous_event_time
from attempts_with_lag
where 1=1
    and event_time <= previous_event_time
order by 1,2,3;
--Номера попыток стоят неправильно, вместо поля attempt можно пронумеровать события самостоятельно
   
-- Проверка на несоответствие времени событий
select count(*)
from (
    select
        a.user_id,
        a.level_number,
        a.event_time as failed_time,
        b.event_time as completed_time
    from temp_attempts a
    	inner join temp_attempts b
    		on a.user_id = b.user_id 
    		and a.level_number = b.level_number 
    		and a.attempt_result = 'level_failed' 
    		and b.attempt_result = 'level_completed'
) _
where 1=1
    and failed_time > completed_time;
--Есть много событий неудачи на уровне после прохождения
--Возможно, это ошибка, но возможно игроки возвращаются на уровень, чтобы его перепройти - оставим

--Проверим сложность уровня на дубликаты
select
	level_number
	, count(distinct level_hardness) as num_level_hardness
from temp_attempts
group by level_number
having count(distinct level_hardness) > 1;
/*
У 249 уровней в таблице стоит несколько сложностей
Это ошибка, проставим значение, которое встречалось в большинстве случаев
Если уровень никто не проходил, то оставим старое значение
*/

--Пересоздадим таблицу
drop table if exists temp_attempts;

create temp table temp_attempts as
	with tmp as (
	select
	    event_time
	    , user_id
	    , country
	    , platform
	    , app_version
	    , event_name as attempt_result
	    -- flattened user_properties without prefix
	    , (user_properties->'segments'->>'gaming_skill')::int as segments_gaming_skill
	    , (user_properties->'segments'->>'payer_segment')::int as segments_payer_segment
	    , (user_properties->'channels_touch'->>-1)::text as last_click_channel
	    , (user_properties->>'first_install_date')::date as first_install_date
	    -- flattened event_properties without prefix, handling null values
	    , coalesce((event_properties->>'errors')::int, 0) as errors
	    , row_number() over (
	        partition by user_id, (event_properties->>'level_number')::int
	        order by event_time
	    ) as attempt
	    , coalesce((event_properties->>'level_number')::int, null) as level_number
	    , coalesce((event_properties->>'level_hardness')::int, null) as level_hardness
	    , coalesce(nullif(event_properties->>'currency_spent_clues', '')::int, 0) as currency_spent_clues
	    , coalesce(nullif(event_properties->>'currency_spent_lives', '')::int, 0) as currency_spent_lives
	from temp_all_events
	where 1=1
	    and event_name in ('level_completed', 'level_failed')
), corrected_level_hardness as (
	select
	    level_number
	    , level_hardness
	    , count(*) as count
	    , row_number() over (partition by level_number order by count(*) desc) as rn
	from tmp
	group by 1,2
)
select
	tmp.event_time
    , tmp.user_id
    , tmp.country
    , tmp.platform
    , tmp.app_version
    , tmp.attempt_result
    , tmp.segments_gaming_skill
    , tmp.segments_payer_segment
    , tmp.last_click_channel
    , tmp.first_install_date
    , tmp.errors
    , tmp.attempt
    , tmp.level_number
    , coalesce(clh.level_hardness, tmp.level_hardness) AS level_hardness
    , tmp.currency_spent_clues
    , tmp.currency_spent_lives
from tmp
	left join corrected_level_hardness clh
		on tmp.level_number = clh.level_number
		and clh.rn = 1;

--Проверим сложность уровня на дубликаты - проблем нет
select
	level_number
	, count(distinct level_hardness) as num_level_hardness
from temp_attempts
group by level_number
having count(distinct level_hardness) > 1;
    
-- Проверяем, что каждая следующая попытка была позже предыдущей - проблем нет
with attempts_with_lag as (
    select
        user_id
        , level_number
        , attempt
        , event_time
        , lag(event_time) over (
            partition by user_id, level_number
            order by attempt
        ) as previous_event_time
    from temp_attempts
)
select
    user_id
    , level_number
    , attempt
    , event_time
    , previous_event_time
from attempts_with_lag
where 1=1
    and event_time <= previous_event_time
order by 1,2,3;

------------------------
--revenue
drop table if exists temp_revenue;

create temp table temp_revenue as 
select 
    event_time
    , user_id
    , country
    , platform
    , app_version
    -- flattened user_properties without prefix
    , (user_properties->'segments'->>'gaming_skill')::int as segments_gaming_skill
    , (user_properties->'segments'->>'payer_segment')::int as segments_payer_segment
    , (user_properties->'channels_touch'->>-1)::text as last_click_channel
    , (user_properties->>'first_install_date')::date as first_install_date
    -- flattened event_properties for transaction details
    , coalesce((event_properties->'transaction'->>'revenue')::numeric, 0) as revenue
    , coalesce((event_properties->'transaction'->>'quantity')::int, 1) as quantity
    , coalesce((event_properties->'transaction'->>'product_id')::int, null) as product_id
    , coalesce((event_properties->'transaction'->>'product_name')::text, null) as product_name
    , coalesce((event_properties->'transaction'->>'transaction_id')::int, null) as transaction_id
from temp_all_events
where event_name = 'transaction';

-- Проверка на дубликаты транзакций - проблем не найдено
select
    transaction_id
    , count(*)
from temp_revenue
group by transaction_id
having count(*) > 1;

--Проверка на соответствие product_id значению product_name
select distinct product_id, product_name from temp_revenue;
--1) В product_name нужно применить lower(), так как есть повторения в разном регистре
--2) В product_name есть значения null, они соответствуют product_id = 3, их нужно заполнить

--Пересоздадим таблицу
drop table if exists temp_revenue;

create temp table temp_revenue as 
select 
    event_time
    , user_id
    , country
    , platform
    , app_version
    -- flattened user_properties without prefix
    , (user_properties->'segments'->>'gaming_skill')::int as segments_gaming_skill
    , (user_properties->'segments'->>'payer_segment')::int as segments_payer_segment
    , (user_properties->'channels_touch'->>-1)::text as last_click_channel
    , (user_properties->>'first_install_date')::date as first_install_date
    -- flattened event_properties for transaction details
    , coalesce((event_properties->'transaction'->>'revenue')::numeric, 0) as revenue
    , coalesce((event_properties->'transaction'->>'quantity')::int, 1) as quantity
    , coalesce((event_properties->'transaction'->>'product_id')::int, null) as product_id
    , coalesce(lower(event_properties->'transaction'->>'product_name'),
    	case 
    		when (event_properties->'transaction'->>'product_id')::int = 1 
    			then 'season' 
    		when (event_properties->'transaction'->>'product_id')::int = 2
    			then 'hard_currency'
    		when (event_properties->'transaction'->>'product_id')::int = 3
    			then 'sale'
    	end) as product_name
    , coalesce((event_properties->'transaction'->>'transaction_id')::int, null) as transaction_id
from temp_all_events
where event_name = 'transaction';
   
------------------------
--cheaters
--Посмотрим, есть ли пользователи, получающие подсказки или жизни нечестным образом
with user_spending as (
    select
        user_id
        , sum(currency_spent_clues) as total_clues_spent
        , sum(currency_spent_lives) as total_lives_spent
    from temp_attempts
    group by 1
), user_revenue as (
    select
        user_id
        , sum(revenue) as total_revenue
    from temp_revenue
    group by 1
)
select
    u.user_id
    , r.total_revenue
    , u.total_clues_spent
    , u.total_lives_spent
from user_spending u
	inner join user_revenue r
		on u.user_id = r.user_id
where 1=1
    and (r.total_revenue = 0 or r.total_revenue is null)
    and (u.total_clues_spent != 0 or u.total_lives_spent != 0);
--Таких пользователей нет, судя по всему они не получают подсказки и жизни нечестным образом


-- Проверим, есть ли аномальное количество прохождения уровней без ошибок
select
    user_id
    , segments_gaming_skill
    , count(attempt) filter(WHERE errors = 0 and attempt = 1 and currency_spent_clues + currency_spent_lives = 0) as perfect_levels
    , count(attempt) as all_levels
    , count(attempt) filter(WHERE errors = 0 and attempt = 1 and currency_spent_clues + currency_spent_lives = 0) / count(attempt)::numeric AS share
from temp_attempts
where 1=1
	and attempt_result = 'level_completed'
group by 1,2 
order by 4 desc
--Есть подозрительные значения, но нам нужно постараться отличить умелых игроков от читеров

--Посчитаем среднее значение и стандартное отклонение для доли "идеальных" уровней
with perfect_levels_stats as (
    select
        user_id
        , segments_gaming_skill
        , segments_payer_segment
        , count(attempt) filter(WHERE errors = 0 and attempt = 1 and currency_spent_clues + currency_spent_lives = 0) as perfect_levels
        , count(attempt) as all_levels
        , count(attempt) filter(WHERE errors = 0 and attempt = 1 and currency_spent_clues + currency_spent_lives = 0) / count(attempt)::numeric as share
    from temp_attempts
    where attempt_result = 'level_completed'
    group by 1,2,3
)
select
	segments_gaming_skill
	, segments_payer_segment
    , avg(share) as avg_share
    , stddev(share) as stddev_share
from perfect_levels_stats
where all_levels > 10
group by rollup(segments_gaming_skill, segments_payer_segment);

/*
Доля "идеальных" уровней незначительно выше в высоких сегментах навыка, но значительно ниже в высоких платящих сегментах
Скорее всего, платящие пользователи пользуются подсказками и жизнями, а мы специально убрали их из расчёта
В среднем она составляет 0,23 со стандартным отклонением 0,08
Выставим пограничное значение в 2 стандартных отклонения по каждой комбинации сегментов
Будем считать только тех, кто прошёл от 10 уровней, чтобы исключить случайности
*/

--Посмотрим на скорость прохождения уровней
with events as (
    select 
        user_id
        , segments_gaming_skill
        , segments_payer_segment
        , event_time
        , level_number
        , attempt
    from temp_attempts
    where 1=1
        and attempt_result = 'level_completed'
    union all
    select 
        user_id
        , segments_gaming_skill
        , segments_payer_segment
        , event_time
        , 0 as level_number
        , 0 as attempt
    from temp_sessions
    order by user_id, event_time
), time_diffs as (
    select
        user_id
        , attempt
        , event_time
        , level_number
        , lag(level_number) over (partition by user_id order by event_time) as prev_level_number
        , lag(attempt) over (partition by user_id order by event_time) as prev_attempt
        , extract(epoch from 
            (event_time - lag(event_time) 
            over (partition by user_id order by event_time)))
            as completion_time_seconds
    from events
)
select
	max(completion_time_seconds) as max_completion_time_seconds
    , percentile_cont(0.5) within group (order by completion_time_seconds desc)::numeric as median
    , percentile_cont(0.75) within group (order by completion_time_seconds desc)::numeric as perc_75
    , percentile_cont(0.9) within group (order by completion_time_seconds desc)::numeric as perc_90
    , percentile_cont(0.95) within group (order by completion_time_seconds desc)::numeric as perc_95
	, min(completion_time_seconds) as min_completion_time_seconds
	, sum(case when completion_time_seconds = 0 then 1 else 0 end) as cheated_level_completions
	, sum(case when completion_time_seconds = 0 then 1 else 0 end) / count(attempt)::numeric as cheated_level_completions_share
	, sum(case when completion_time_seconds <= 5 then 1 else 0 end) / count(attempt)::numeric as level_completions_5_sec_share
from time_diffs;
/*
12% успешных попыток было сделано за 0 секунд, доля попыток до 5 секунд мала, но кажется, что это в рамках случайности
Посчитаем читерами тех, кто прошёл более 5 уровней за 0 секунд
*/

--Найдём читеров по доле идеальных уровней и времени прохождения
drop table if exists temp_cheaters;

create local temp table temp_cheaters as
	with perfect_levels_stats as (
	    select
	        user_id
	        , segments_gaming_skill
	        , segments_payer_segment
	        , count(attempt) filter(WHERE errors = 0 and attempt = 1 and currency_spent_clues + currency_spent_lives = 0) as perfect_levels
	        , count(attempt) as all_levels
	        , count(attempt) filter(WHERE errors = 0 and attempt = 1 and currency_spent_clues + currency_spent_lives = 0) / count(attempt)::numeric as share_perfect
	    from temp_attempts
	    where 1=1
	    	and attempt_result = 'level_completed'
	    group by 1,2,3
	    having count(attempt) > 10
	), perfect_levels_borders as (
		select
			segments_gaming_skill
			, segments_payer_segment
		    , avg(share_perfect) as avg_share_levels
		    , stddev(share_perfect) as stddev_share_levels
		from perfect_levels_stats
		group by 1,2
	), events as (
	    select 
	        user_id
	        , event_time
	        , level_number
	        , attempt
	    from temp_attempts
	    where 1=1
	        and attempt_result = 'level_completed'
	    union all
	    select 
	        user_id
	        , event_time
	        , 0 as level_number
	        , 0 as attempt
	    from temp_sessions
	    order by user_id, event_time
	), time_diffs as (
	    select
	        user_id
	        , attempt
	        , event_time
	        , level_number
	        , lag(level_number) over (partition by user_id order by event_time) as prev_level_number
	        , lag(attempt) over (partition by user_id order by event_time) as prev_attempt
	        , extract(epoch from 
	            (event_time - lag(event_time) 
	            over (partition by user_id order by event_time)))
	            as completion_time_seconds
	    from events
	)
	select distinct
		user_id
	from perfect_levels_stats
		left join perfect_levels_borders
			using(segments_gaming_skill, segments_payer_segment)
	where 1=1
		and share_perfect > avg_share_levels + 2 * stddev_share_levels
	union
	select 
		user_id
	from time_diffs
	group by
		user_id
	having count(attempt) filter(where completion_time_seconds = 0) > 5;


--Скорость прохождения уровней 
	
------------------------------
--Ответы на вопросы продакта--
------------------------------
/*
1. Сколько уровней в расчете на 1 игрока выигрывается с 1 попытки?
Есть ли какая-то зависимость от скилла игроков? Если да, то какая?
*/
with level_stats as (
	select
	    user_id
	    , segments_gaming_skill
	    , count(attempt) filter(WHERE attempt = 1) as perfect_levels
	    , count(attempt) as all_levels
	from temp_attempts
	where 1=1
		and attempt_result = 'level_completed'
	group by 1,2
)
select
	segments_gaming_skill
	, sum(perfect_levels) / count(user_id) as avg_perfect_levels
	, sum(perfect_levels) / sum(all_levels) as perfect_levels_share
from level_stats
group by rollup(segments_gaming_skill)
order by segments_gaming_skill;
/*
В среднем в расчёте на 1 игрока с 1 попытки выигрывается 39 уровней, это 80% от всех проходимых уровней
Чем ниже сегмент, тем меньше в среднем уровней на игрока и тем меньше доля идеальных уровней.
В 0 сегменте в среднем на игрока 35 уровней с 1 попытки и это 71% всех пройденных ими уровней. В 3 сегменте на игрока 43 уровня и это 87% от всех пройденных ими уровней.
*/

/*
2. Какой процент от игроков составляют читеры? Является ли это проблемой?
*/
select 
	(select count(distinct user_id) from temp_cheaters) / (select count(distinct user_id) from temp_attempts)::numeric;

--Проверим cтраны - нет разницы в доле читеров
select 
	country
	, count(distinct temp_cheaters.user_id) / count(distinct temp_attempts.user_id)::numeric
from temp_attempts
	left join temp_cheaters
		using(user_id)
group by rollup(1)

--Проверим платформы - на iOS читеров 60,5% против 47% на андроиде
select 
	platform
	, count(distinct temp_cheaters.user_id) / count(distinct temp_attempts.user_id)::numeric
from temp_attempts
	left join temp_cheaters
		using(user_id)
group by rollup(1)

--Проверим версии приложения - доля читеров в старых версиях (до 1.3.0) чуть выше
--Это мало что даёт, так как возможно, что читы пока плохо работают в новых версиях
select 
	app_version
	, count(distinct temp_cheaters.user_id) / count(distinct temp_attempts.user_id)::numeric
from temp_attempts
	left join temp_cheaters
		using(user_id)
group by rollup(1)

--Проверим сегменты по навыку - чем выше сегмент, тем больше там доля читеров
--Скорее всего это связано с тем, что они проходят больше уровней за счёт читов, и мы считаем их более умелыми из-за этого
--Читеры портят нам сегментацию по навыку
select 
	segments_gaming_skill
	, count(distinct temp_cheaters.user_id) / count(distinct temp_attempts.user_id)::numeric
from temp_attempts
	left join temp_cheaters
		using(user_id)
group by rollup(1)

--Проверим покупательские сегменты - в среднем доли похожие, но в 3 сегменте на 10% меньше читеров
select 
	segments_payer_segment
	, count(distinct temp_cheaters.user_id) / count(distinct temp_attempts.user_id)::numeric
from temp_attempts
	left join temp_cheaters
		using(user_id)
group by rollup(1)

--Проверим каналы привлечения - доля читеров с adwords меньше всего (35%), доля читеров из applovin больше всего (63%), доля читеров из органики 52%
--Возможно, в applovin есть какая-то проблема в мотивации (они заставляют пройти определённое количество уровней), но доля читеров из органики всё равно слишком высока
select 
	last_click_channel
	, count(distinct temp_cheaters.user_id) / count(distinct temp_attempts.user_id)::numeric
from temp_attempts
	left join temp_cheaters
		using(user_id)
group by rollup(1)

--Попытаемся найти проблемную когорту - проблемы начались с 27 февраля
--Со временем количество читеров в когортах падает (скорее всего из-за того, что меньше людей проходят 10 уровней и не попадают в нашу методологию)
--Новые когорты (с 20 ноября) относительно чистые (менее 30% читеров), нужно отслеживать их в будущем
select 
	date_trunc('week', first_install_date) as week
	, count(distinct temp_cheaters.user_id) / count(distinct temp_attempts.user_id)::numeric
from temp_attempts
	left join temp_cheaters
		using(user_id)
group by rollup(1)
order by 1;
/*
Всего читеров по такой методологии 54%, это большая проблема
Доля читеров с adwords меньше всего (35%), доля читеров из applovin больше всего (63%), доля читеров из органики 52%
Возможно, в applovin есть какая-то проблема в мотивации (они заставляют пройти определённое количество уровней), но доля читеров из органики всё равно слишком высока
Чем выше сегмент по навыку, тем больше там доля читеров
Скорее всего это связано с тем, что они проходят больше уровней за счёт читов, и мы считаем их более умелыми из-за этого
Читеры портят нам сегментацию по навыку
*/

/*
3. Сейчас в игре реализовано 1000 уровней.
Достаточно ли у нас уровней сделано для игроков? Насколько этих уровней хватит?
*/

select event_time::date as event_date, count(*)::float / count(distinct user_id) as speed
from temp_attempts
where attempt_result = 'level_completed'
group by 1 
order by 1

select 
	segments_gaming_skill
	, last_click_channel
	, max(level_number) as max_level_achieved
from temp_attempts
group by rollup(1,2)
order by 1,2;
--Максимально достигнутый уровень - 485

--Дальше всего прошли игроки из applovin, органические иг
with user_level_stats as (
	select
		user_id
		, segments_gaming_skill
		, last_click_channel
		, max(level_number) as max_level
	from temp_attempts
	where 1=1
		and attempt_result = 'level_completed'
	group by 1,2,3
)
select 
	segments_gaming_skill
	, last_click_channel
	, avg(max_level) as avg_last_level
	, count(user_id) filter(where max_level >= 300) / count(user_id)::numeric as share_300
from user_level_stats
group by rollup(1,2)
order by 1,2;
--Во всех сегментах доля игроков с более чем 300 уровнями  менее 1%
--В среднем игроки прошли по 40-50 уровней

with user_level_stats as (
	select
		user_id
		, date_trunc('week', first_install_date)::date as week
		, max(level_number) as max_level
	from temp_attempts
	where 1=1
		and attempt_result = 'level_completed'
	group by 1,2
)
select 
	week
	, avg(max_level) as avg_last_level
	, count(user_id) filter(where max_level >= 300) / count(user_id)::numeric as share_100
	, count(user_id) filter(where max_level >= 300) / count(user_id)::numeric as share_300
from user_level_stats
group by rollup(1)
order by 1;
--Самые старые игроки прошли не далее остальных

/*
Этих уровней хватает игрокам, кажется, что их хватит и на длительный период в дальнейшем,
учитывая, что самые старые игроки не дошли до 100 уровня (в когортах до 27 февраля 2023 доля игроков таких игроков менее 1%)
*/

/*
4. Какая общая сложность всей последовательности уровней? Меняется ли она со временем? А какая чистая сложность? 
     a. Общая сложность - отражает сколько нужно совершить попыток 
     чтобы пройти уровень 
     b. Чистая сложность - тоже самое, но в ней не учитывается платное 
     влияние (докупки жизней или подсказок)
*/
with level_attempts as (
    select
        user_id
        , level_number
        , attempt
        , event_time
        , attempt_result
    from temp_attempts
    where 1=1
        and attempt_result in ('level_completed', 'level_failed')
), level_completions as (
    select
        user_id
        , level_number
        , min(attempt) as total_attempts
    from level_attempts
    where 1=1
        and attempt_result = 'level_completed'
    group by 1, 2
)
select
    avg(total_attempts) as avg_total_attempts
    , stddev(total_attempts) as stddev_total_attempts
from level_completions;
--В среднем сложность 1,28 попыток со стандартным отклонением 0,67

with level_attempts as (
    select
        user_id
        , level_number
        , attempt
        , event_time
        , attempt_result
        , currency_spent_clues
        , currency_spent_lives
    from temp_attempts
    where 1=1
        and attempt_result in ('level_completed', 'level_failed')
        and currency_spent_clues = 0 
      	and currency_spent_lives = 0
), level_completions as (
    select
        user_id
        , level_number
        , min(attempt) as net_attempts
    from level_attempts
    where 1=1
        and attempt_result = 'level_completed'
    group by 1, 2
)
select
    avg(net_attempts) as avg_net_attempts
    , stddev(net_attempts) as stddev_net_attempts
from level_completions;
--В среднем сложность 1,28 попыток со стандартным отклонением 0,67

with level_attempts as (
    select
        user_id
        , level_number
        , attempt
        , event_time
        , attempt_result
        , currency_spent_clues
        , currency_spent_lives
    from temp_attempts
    where 1=1
        and attempt_result in ('level_completed', 'level_failed')
), level_completions as (
    select
        user_id
        , level_number
        , attempt
        , event_time
        , attempt_result
        , currency_spent_clues
        , currency_spent_lives
        , min(attempt) over (partition by user_id, level_number) as total_attempts
        , min(attempt) filter (where currency_spent_clues = 0 and currency_spent_lives = 0) over (partition by user_id, level_number) as net_attempts
    from level_attempts
    where 1=1
        and attempt_result = 'level_completed'
)
select
    date_trunc('week', event_time) as week
    , avg(total_attempts) as avg_total_attempts
    , avg(net_attempts) as avg_net_attempts
from level_completions
group by 1;
--В среднем сложность не менялась