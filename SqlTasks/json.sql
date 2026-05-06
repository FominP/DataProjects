/*
1. Анализ сегментации пользователей и вклада в доход
Используя таблицу mobile_game_raw.all_events в БД project, проанализируйте взаимосвязь между сегментацией пользователей (payer_segment, gaming_skill) и их вкладом в доход. Для этого: 
Рассчитайте общий доход, который приносят пользователи из каждой комбинации payer_segment и gaming_skill, указанных в поле segments в JSON user_properties.
Определите комбинацию сегментов, которая приносит наибольший доход.
Дополнительно рассчитайте средний доход на одного пользователя для каждой комбинации payer_segment и gaming_skill.
*/
    
with user_segments as (
    select
    	user_id
        , user_properties->'segments'->>'payer_segment' as payer_segment
        , user_properties->'segments'->>'gaming_skill' as gaming_skill
    from mobile_game_raw.all_events
    where 1=1
    	and user_properties is not null
), revenue_per_user as (
    select
        user_id
        , sum(cast(event_properties->'transaction'->>'revenue' as numeric)) as total_revenue
    from mobile_game_raw.all_events
    where 1=1
    	and event_name = 'transaction'
    group by user_id
)
select
    us.payer_segment
    , us.gaming_skill
    , sum(rpu.total_revenue) as total_revenue
    , count(distinct us.user_id) as user_count
    , sum(rpu.total_revenue)::numeric / count(us.user_id) as avg_revenue_per_user
from user_segments us
	left join revenue_per_user rpu 
		on us.user_id = rpu.user_id
group by 1,2
order by total_revenue desc;
--наибольший доход приносит payer segment 1 и gaming skill 3

/*
2. First и Last Click атрибуция
Используя таблицу mobile_game_raw.all_events в БД project, необходимо для каждого пользователя определить,
какой канал стал первым (First Click) и последним (Last Click) в последовательности касаний (порядок каналов в массиве channels_touch). Для этого: 
Определите First Click (первый канал), который взаимодействовал с пользователем. Это первый элемент в массиве channels_touch для каждого пользователя.
Определите Last Click (последний канал), который взаимодействовал с пользователем. Это последний элемент в массиве channels_touch.
Создайте запрос, который возвращает эти каналы (First Click и Last Click) для каждого пользователя.
*/
with user_channels as (
    select
        user_id
        , jsonb_array_elements_text(user_properties -> 'channels_touch') as channel
    from mobile_game_raw.all_events
    where 1=1
    	and event_properties is not null
), first_last_click as (
    select
        user_id
        , min(channel) as first_click
        , max(channel) as last_click
    from user_channels
    group by user_id
)
select
    user_id
    , first_click
    , last_click
from first_last_click;

/*
3. Анализ поведения пользователей в разных сегментах на основе временных интервалов
Используя таблицу mobile_game_raw.all_events в БД project, проанализировать,
как пользователи с разными уровнями gaming_skill и payer_segment меняют свою активность в зависимости от времени дня (time of day).
Инструкция:
Разделите время событий (из поля event_time) на интервалы: утро (6:00 - 12:00), день (12:00 - 18:00), вечер (18:00 - 24:00), ночь (0:00 - 6:00).
Для каждого интервала и для каждой комбинации gaming_skill и payer_segment рассчитайте:
Общее количество сессий.
Средний доход на пользователя (если были транзакции в этом интервале времени), т.е. ARPU пользователя в данном сочетании сегментов и временном интервале. 
Определите, как изменяются поведенческие показатели для пользователей с разными комбинациями сегментов в разные периоды дня. 
Объясните наблюдаемую разницу между временными интервалами внутри сегментов. 
*/

with user_segments as (
    select
        user_id
        , user_properties->'segments'->>'payer_segment' as payer_segment
        , user_properties->'segments'->>'gaming_skill' as gaming_skill
    from mobile_game_raw.all_events
    where 1=1
    	and user_properties is not null
), time_intervals as (
    select
        user_id
        , event_time
        , case
            when extract(hour from event_time) between 6 and 11 then 'morning'
            when extract(hour from event_time) between 12 and 17 then 'afternoon'
            when extract(hour from event_time) between 18 and 23 then 'evening'
            else 'night'
        end as time_of_day
    from mobile_game_raw.all_events
), session_counts as (
    select
        us.payer_segment
        , us.gaming_skill
        , ti.time_of_day
        , count(distinct ae.user_id) as session_count
    from user_segments us
    	join time_intervals ti 
    		on us.user_id = ti.user_id
    	join mobile_game_raw.all_events ae 
    		on us.user_id = ae.user_id 
    		and ti.event_time = ae.event_time
    group by 1,2,3
), revenue_per_interval as (
    select
        us.payer_segment
        , us.gaming_skill
        , ti.time_of_day
        , sum(cast(ae.event_properties->'transaction'->>'revenue' as numeric)) as total_revenue
    from user_segments us
    	join time_intervals ti 
    		on us.user_id = ti.user_id
    	join mobile_game_raw.all_events ae 
    		on us.user_id = ae.user_id 
    		and ti.event_time = ae.event_time
    where 1=1
    	and ae.event_name = 'transaction'
    group by 1,2,3
)
select
    sc.payer_segment
    , sc.gaming_skill
    , sc.time_of_day
    , sc.session_count
    , rpi.total_revenue
    , rpi.total_revenue::numeric / sc.session_count as arpu
from session_counts sc
	left join revenue_per_interval rpi 
		on sc.payer_segment = rpi.payer_segment 
		and sc.gaming_skill = rpi.gaming_skill 
		and sc.time_of_day = rpi.time_of_day
order by 1,2,3;
/*
в 0 платёжном сегменте нет выручки
в 1 и 2 платёжных сегментах утро - самое лучшее время по общей и средней выручке, а вечер - самое худшее время
в 3 сегменте сложно оценивать динамику, так как там количество сессий в интервале не превышает 10
*/