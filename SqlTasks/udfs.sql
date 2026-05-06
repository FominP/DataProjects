/*
У вас есть CRM система, в которой заведены карточки клиентов(Account). Карточки выстроены в иерархию, которая соответствует структуре компаний-клиентов в реальной жизни. 
Данные устроены следующим образом – каждый Account знает только id своего родителя. Максимальное кол-во уровней – не ограничено. 
Вам нужно написать UDF, которая сможет определить головную компанию (корень дерева) для ЛЮБОГО количества уровней иерархии. 
Данные находятся в БД project в схеме udf_tasks в таблицу accounts. Там же вы можете создавать и тестировать свои функции. 
Функция должна называться get_root_account_<фамилия_и_о>, принимать на вход account_id и возвращать root_account_id
*/
create or replace function udf_tasks.get_root_account_fomin_p_a(input_account_id int, max_steps int default 100)
returns int as
$$
declare
    current_account int;
    parent_account int;
    step_counter int := 0;
begin
    current_account := input_account_id;
    loop
        select parent_account_id into parent_account
        from udf_tasks.accounts
        where account_id = current_account;

        if parent_account is null then
            return current_account;
        end if;

        current_account := parent_account;

        step_counter := step_counter + 1;
		--ограничитель количества шагов
        if step_counter >= max_steps then
            raise exception 'превышено максимальное количество шагов (%). возможно, в иерархии есть цикл.', max_steps;
        end if;
    end loop;
end;
$$
language plpgsql;

select 
    account_id, 
    udf_tasks.get_root_account_fomin_p_a(account_id) as root_account_id
from udf_tasks.accounts;

/*
Напишите UDF, которая на вход принимает product_id и возвращает название продукта. Таблица соответствия:
prpduct_id	product_name
1			season
2			hard_currency
3			sale
4			special_offer
Если id не известен функции, то она должна вернуть Unknown
Функция должна называться get_product_name_<фамилия_и_о> и находиться в схеме udf_tasks в БД project
*/

create or replace function udf_tasks.get_product_name_fomin_p_a(p_product_id int)
returns varchar as
$$
declare
    v_product_name varchar;
begin
    select product_name into v_product_name
    from (values
        (1, 'season'),
        (2, 'hard_currency'),
        (3, 'sale'),
        (4, 'special_offer')
    ) as products(product_id, product_name)
    where product_id = p_product_id;

    if v_product_name is null then
        return 'unknown';
    end if;

    return v_product_name;
end;
$$
language plpgsql;

select udf_tasks.get_product_name_fomin_p_a(2);  -- Должно вернуть 'hard_currency'
select udf_tasks.get_product_name_fomin_p_a(5);  -- Должно вернуть 'unknown'

/*
Ваша задача - реализовать UDF для определения выбросов средствами SQL/plpgSQL. Для этого мы воспользуемся классическим методом интерквартильного размаха (IQR). 
На вход функция должна принимать массив из чисел и множитель (multiplier), с помощью которого мы можем определять размер отклонения от IQR по следующей логике: 
lower_bound = q1 - multiplier * iqr;
upper_bound = q3 + multiplier * iqr;
q1 и q3 - 1 и 3 квартили соответственно
На выходе ожидается таблица точек-выбросов (outlier) и размер их абсолютного отклонения от верхней ИЛИ нижней границ (deviation). 
Функция должна называться detect_outliers_<фамилия_и_о> и находиться в схеме udf_tasks в БД project
*/
create or replace function udf_tasks.detect_outliers_fomin_p_a(data_array float[], multiplier float)
returns table(outlier float, deviation float) as
$$
declare
    q1 float;
    q3 float;
    iqr float;
    lower_bound float;
    upper_bound float;
begin
    -- вычисляем q1 (25-й процентиль)
    select percentile_cont(0.25) within group (order by unnested_value)
    into q1
    from unnest(data_array) as unnested_value;

    -- вычисляем q3 (75-й процентиль)
    select percentile_cont(0.75) within group (order by unnested_value)
    into q3
    from unnest(data_array) as unnested_value;

    iqr := q3 - q1;

    lower_bound := q1 - multiplier * iqr;
    upper_bound := q3 + multiplier * iqr;

    return query
    select unnested_value as outlier,
           case
               when unnested_value < lower_bound then lower_bound - unnested_value
               when unnested_value > upper_bound then unnested_value - upper_bound
               else null
           end as deviation
    from unnest(data_array) as unnested_value
    where unnested_value < lower_bound or unnested_value > upper_bound;
end;
$$
language plpgsql;

select *
from udf_tasks.detect_outliers_fomin_p_a(array[-200, 10, 20, 30, 40, 50, 100, 200, 300], 1.5);