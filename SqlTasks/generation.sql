/*
Используя таблицу mobile_game_raw.all_events в БД project, напишите запрос,
который создаст по каждому пользователю (user_id) запись на каждый день с момента его первой сессии 
в период с 2023-03-01 по 2023-06-30. 
Т.е. ДО даты первой сессии пользователя быть не должно, а после - он должен быть в каждую дату, даже если он не был активен в этот день.
Таким образом, в таблице должно происходить накопление пользователей.
*/

select 
	user_id
	, generate_series(min(event_time)::date, '2023-06-30'::date, '1 day'::interval)::timestamp as day
from mobile_game_raw.all_events
where 1=1
	and event_time between '2023-03-01' and '2023-06-30'
group by 1;

/*
Используя данные из mobile_game_raw.all_events в БД project, определите, какие источники при втором касании (channels_touch) чаще всего приводят 
к первым установкам приложения (определяется по полю first_install_date) за период с мая по июль 2023 года. 
Отсортируйте источники трафика по количеству пользователей, которые пришли из них. 
Если у юзера не было второго касания, то не учитываем его в расчете. 
В решении используйте функцию для генерации индексов массива. 
В базе данных также добавлена функция конвертации массива из JSON в ARRAY - jsonb_array_to_text_array. 
*/
with channel_array as (
	select 
		user_id
		, jsonb_array_to_text_array(user_properties['channels_touch']) as channels_touch
	from mobile_game_raw.all_events
	where 1=1
		and user_properties is not null
		and user_properties ->> 'first_install_date' >= '2023-05-01'
		and user_properties ->> 'first_install_date' < '2023-08-01'
), channel_array_index as (
select 
	user_id
	, channels_touch[generate_subscripts(channels_touch, 1)] as channel
	, generate_subscripts(channels_touch, 1) as index
from channel_array
where 1=1
	and array_length(channels_touch, 1) >= 2
)
select
	channel
	, count(distinct user_id) as user_count
from channel_array_index
where 1=1
	and index = 2
group by 1
order by 2 desc;
	
/*
Используя данные таблицу mobile_game_raw.all_events, необходимо смоделировать конверсию пользователей по дням. 
Задача заключается в следующем:
Для каждого пользователя, который начал хотя бы одну сессию в период с 1 марта 2023 года по 30 июня 2023 года, нужно в этом дне смоделировать факт наличия или отсутствия транзакций. 
Для этого: 
Принять вероятность совершения транзакции фиксированной и равной N для всех пользователей.
Для каждого активного юзера в заданном дне необходимо сгенерировать случайное число и, если оно меньше N, считать, что покупка в этом дне была совершена (смоделированная транзакция).
Для каждой сессии также нужно проверить, совершил ли пользователь реальную транзакцию в этот же день, используя данные о транзакциях в таблице.
После этого необходимо агрегировать данные по дням и вывести следующую информацию:
День
Общее количество активных юзеров в день.
Смоделированная конверсия в платеж
Реальная конверсия в платеж
Подберите N так, чтобы отклонение сгенерированной конверсии от реальной было бы минимальным. 
 */
with active_users as (
    select distinct user_id
    from mobile_game_raw.all_events
    where 1=1 
    	and event_name = 'session_start'
    	and event_time >= '2023-03-01'
    	and event_time < '2023-07-01'
), simulated_transactions AS (
    select
        user_id
        , date_trunc('day', event_time) as event_day
        , random() < 0.05518899861269621 as simulated_transaction --среднее значение конверсии
    from mobile_game_raw.all_events
    where 1=1 
    	and user_id in (select user_id from active_users)
      	and event_name = 'session_start'
      	and event_time >= '2023-03-01'
      	and event_time < '2023-07-01'
), real_transactions AS (
    select
        user_id
        , date_trunc('day', event_time) as event_day
        , true as real_transaction
    from mobile_game_raw.all_events
    where 1=1
    	and event_name = 'transaction'
        and event_time >= '2023-03-01'
        and event_time < '2023-07-01'
), combined_data as (
	select
        st.user_id
        , st.event_day
        , st.simulated_transaction
        , rt.real_transaction
    from simulated_transactions st
        left join real_transactions rt
        	on st.user_id = rt.user_id and st.event_day = rt.event_day
), aggregated_data as (
    select
        event_day
        , count(distinct user_id) as total_active_users
        , count(distinct case when simulated_transaction then user_id end) as simulated_paying_users
        , count(distinct case when real_transaction then user_id end) as real_paying_users
    from combined_data
    group by event_day
)
select
    event_day
    , total_active_users
    , simulated_paying_users::float / total_active_users as simulated_conversion
    , real_paying_users::float / total_active_users as real_conversion
from aggregated_data
order by event_day