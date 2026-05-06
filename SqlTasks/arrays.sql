/*
Используя таблицу array_tasks.user_activity в БД postgres напишите запрос, который найдет всех пользователей, которые добавили товар в корзину (add_to_cart) равно 3 раза.
Верните уникальные идентификаторы таких пользователей и сессии, в которых произошло данное событие.
*/

select 
	user_id,
    session_id
from array_tasks.user_activity
where 1=1 
    and cardinality(array_positions(clickstream_sequence, 'add_to_cart')) = 3;

/*
Используя таблицу array_tasks.user_activity в БД postgres напишите запрос, который рассчитает конверсию из page_view в purchase. 
Расчет относительно сессий, т.е. если в сессии случилась более одной последовательности “просмотр страницы - продажа”, то мы считаем это как 1 в числителе. 
Помимо запроса напишите ответ в виде десятичного числа. Например: 0.1234.
*/

with sessions_with_purchase as (
    select session_id
    from array_tasks.user_activity
    where 1=1
        and 'purchase' = any(clickstream_sequence)
), sessions_with_page_view as (
    select session_id
    from array_tasks.user_activity
    where 1=1
        and 'page_view' = any(clickstream_sequence)
)
select 
	(select count(distinct session_id) from sessions_with_purchase) as purchase,
	(select count(distinct session_id) from sessions_with_page_view) as page_view,
    (select count(distinct session_id) from sessions_with_purchase)::float/(select count(distinct session_id) from sessions_with_page_view) as conversion_rate;
   
/*
Используя таблицу array_tasks.user_activity в БД postgres, определите, сколько пользователей выполнили последовательность действий: просмотр страницы (page_view), просмотр продукта (product_view), добавление товара в корзину (add_to_cart) в одной сессии. Верните количество таких пользователей.
*/

with tmp as (
    select user_id
    from array_tasks.user_activity
    where 1=1
        and array_position(clickstream_sequence, 'page_view') < array_position(clickstream_sequence, 'product_view')
        and array_position(clickstream_sequence, 'page_view') < array_position(clickstream_sequence, 'add_to_cart')
)
select count(distinct user_id) as users_count
from tmp;
   
/*
Используя таблицу array_tasks.user_activity в БД postgres, найдите долю сессий,
 которые добавили товар в корзину (add_to_cart), но не завершили покупку (например, нет действия типа purchase).
  Помимо запроса укажите какую конверсию вы получили в виде десятичного числа. Не округляйте результат.
*/

with sessions_with_add_to_cart as (
    select session_id
    from array_tasks.user_activity
    where 1=1
    	and 'add_to_cart' = any(clickstream_sequence)
), sessions_with_purchase as (
    select session_id
    from array_tasks.user_activity
    where 1=1
        and 'purchase' = any(clickstream_sequence)
)
select 
	count(swp.session_id)::numeric / count(swatc.session_id)::numeric as conversion_rate
	, 1-count(swp.session_id)::numeric / count(swatc.session_id)::numeric as share_not_bought
from sessions_with_add_to_cart swatc
	left join sessions_with_purchase swp
		on swatc.session_id = swp.session_id
where 1=1
    and swp.session_id is null; 