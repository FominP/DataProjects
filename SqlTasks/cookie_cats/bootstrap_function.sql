CREATE OR REPLACE FUNCTION cookiecats.bootstrap_fomin_p_a(
    group_a_data float[], 
    group_b_data float[], 
    metric text
)
RETURNS TABLE(
    metric_name text,
    group_a_lower float,
    group_a_upper float,
    group_b_lower float,
    group_b_upper float
) AS
$$
import numpy as np

n_iterations = 1000

# Выбираем величину в зависимости от метрики
def calculate_metric(data, metric):
    if metric == 'retention_1':
        return np.mean(data)
    elif metric == 'retention_7':
        return np.mean(data)
    elif metric == 'median_gamerounds':
        return np.median(data)
    elif metric == 'mean_gamerounds':
        return np.mean(data)
    elif metric == '75_quantile_gamerounds':
        return np.quantile(data, 0.75)
    elif metric == '95_quantile_gamerounds':
        return np.quantile(data, 0.95)
    else:
        raise ValueError("Неизвестная метрика")

def bootstrap(data, metric, n_iterations):
    metrics = []
    for _ in range(n_iterations):
        sample = np.random.choice(data, size=len(data)//100, replace=True)
        metrics.append(calculate_metric(sample, metric))
    return np.percentile(metrics, 2.5), np.percentile(metrics, 97.5)

group_a_lower, group_a_upper = bootstrap(group_a_data, metric, n_iterations)
group_b_lower, group_b_upper = bootstrap(group_b_data, metric, n_iterations)

return [(metric, group_a_lower, group_a_upper, group_b_lower, group_b_upper)]
$$ LANGUAGE plpython3u;

-- Вызов функции
select * from cookiecats.bootstrap_fomin_p_a(
    (select array_agg(retention_1::int) from cookie_cats.ab_results where version = 'gate_30'),
    (select array_agg(retention_1::int) from cookie_cats.ab_results where version = 'gate_40'),
    'retention_1'
)
union all
select * from cookiecats.bootstrap_fomin_p_a(
    (select array_agg(retention_7::int) from cookie_cats.ab_results where version = 'gate_30'),
    (select array_agg(retention_7::int) from cookie_cats.ab_results where version = 'gate_40'),
    'retention_7'
)
union all
select * from cookiecats.bootstrap_fomin_p_a(
    (select array_agg(sum_gamerounds) from cookie_cats.ab_results where version = 'gate_30'),
    (select array_agg(sum_gamerounds) from cookie_cats.ab_results where version = 'gate_40'),
    'median_gamerounds'
)
union all
select * from cookiecats.bootstrap_fomin_p_a(
    (select array_agg(sum_gamerounds) from cookie_cats.ab_results where version = 'gate_30'),
    (select array_agg(sum_gamerounds) from cookie_cats.ab_results where version = 'gate_40'),
    'mean_gamerounds'
)
union all
select * from cookiecats.bootstrap_fomin_p_a(
    (select array_agg(sum_gamerounds) from cookie_cats.ab_results where version = 'gate_30'),
    (select array_agg(sum_gamerounds) from cookie_cats.ab_results where version = 'gate_40'),
    '75_quantile_gamerounds'
)
union all
select * from cookiecats.bootstrap_fomin_p_a(
    (select array_agg(sum_gamerounds) from cookie_cats.ab_results where version = 'gate_30'),
    (select array_agg(sum_gamerounds) from cookie_cats.ab_results where version = 'gate_40'),
    '95_quantile_gamerounds'
);