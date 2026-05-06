/*
Ваша задача - реализовать UDF для определения выбросов средствами Python. Для этого мы воспользуемся классическим методом интерквартильного размаха (IQR).
На вход функция должна принимать массив из чисел и множитель (multiplier), с помощью которого мы можем определять размер отклонения от IQR по следующей логике: 
lower_bound = q1 - multiplier * iqr;
upper_bound = q3 + multiplier * iqr;
q1 и q3 - 1 и 3 квартили соответственно
На выходе ожидается таблица точек-выбросов (outlier) и размер их абсолютного отклонения от верхней ИЛИ нижней границ (deviation). 
Функция должна называться detect_outlierspython<фамилияио> и находиться в схеме udf_tasks в БД project
*/
--Проверяем, установлен ли python
create extension if not exists plpython3u;

create or replace function udf_tasks.detect_outlierspython_fomin_p_a(data float[], multiplier float)
returns table(outlier float, deviation float) as
$$
def calculate_percentile(data, percentile):
    sorted_data = sorted(data)
    index = (len(sorted_data) - 1) * percentile / 100
    lower_index = int(index)
    upper_index = lower_index + 1

    if upper_index >= len(sorted_data):
        return sorted_data[lower_index]
    return sorted_data[lower_index] + (index - lower_index) * (sorted_data[upper_index] - sorted_data[lower_index])

q1 = calculate_percentile(data, 25)
q3 = calculate_percentile(data, 75)

iqr_value = q3 - q1

lower_bound = q1 - multiplier * iqr_value
upper_bound = q3 + multiplier * iqr_value

outliers = []
deviations = []
for value in data:
    if value < lower_bound or value > upper_bound:
        outliers.append(value)
        deviation = abs(value - lower_bound) if value < lower_bound else abs(value - upper_bound)
        deviations.append(deviation)

# Возвращаем результат
return list(zip(outliers, deviations))
$$ language plpython3u;

select *
from udf_tasks.detect_outlierspython_fomin_p_a(ARRAY[-200, 10, 20, 30, 40, 50, 100, 200, 300], 1.5); 

/*
Реализуйте UDF для нормализации данных с помощью RobustScaler с помощью Python и библиотек numpy/scipy. 
На вход функция должна принимать массив чисел. На выход - также возвращать массив чисел, но нормализованный с помощью реализованного вами RobustScaler. 
Функция должна называться robustnormalize<фамилияио> и находиться в схеме udf_tasks в БД project
*/
create or replace function udf_tasks.robustnormalize_fomin_p_a(data float[])
returns float[] as
$$
def calculate_median(data):
    sorted_data = sorted(data)
    n = len(sorted_data)
    
    if n % 2 == 1:
        return sorted_data[n // 2]
    else:
        return (sorted_data[n // 2 - 1] + sorted_data[n // 2]) / 2

def calculate_percentile(data, percentile):
    sorted_data = sorted(data)
    index = (len(sorted_data) - 1) * percentile / 100
    lower_index = int(index)
    upper_index = lower_index + 1
 
    if upper_index >= len(sorted_data):
        return sorted_data[lower_index]
    return sorted_data[lower_index] + (index - lower_index) * (sorted_data[upper_index] - sorted_data[lower_index])

median = calculate_median(data)
q1 = calculate_percentile(data, 25)
q3 = calculate_percentile(data, 75)

iqr = q3 - q1
normalized_data = [(x - median) / iqr for x in data]

return normalized_data
$$ language plpython3u;

select udf_tasks.robustnormalize_fomin_p_a(array[10, 20, 30, 40, 50]);

/*
Реализуйте UDF с помощью Python, которая обучает модель линейной регрессии y = ax + b и делает предсказания по переданным данным. 
На вход функция принимает 3 массива: 
x_train - массив значений X для обучения (независимые переменные)
y_train - массив значений Y для обучения (зависимые переменные)
x_predict - массив значений X, для которых нужно предсказать Y
А возвращает: 
y_predict - предсказанное значения y для каждого x_predict
a - наклон линии
b - свободный член
Нахождение коэффициентов реализуйте через метод наименьших квадратов. Для этого вам пригодится функция np.linalg.lstsq
Помимо этого UDF должна проверять, что не передан слишком большой массив (не больше 100 элементов) или пустой массив. Также массивы x_train и y_train по длине должны быть одинаковые. 
*/
CREATE OR REPLACE FUNCTION udf_tasks.linear_regression_fomin_p_a(
    x_train numeric[], 
    y_train numeric[], 
    x_predict numeric[]
)
RETURNS TABLE(y_predict float, a float, b float) AS
$$
import numpy as np

# Проверка на пустые массивы
if not x_train or not y_train or not x_predict:
    raise ValueError("Один или несколько массивов пусты.")

# Проверка на размер массивов
if len(x_train) > 100 or len(y_train) > 100 or len(x_predict) > 100:
    raise ValueError("Размер массивов не должен превышать 100 элементов.")

# Проверка на одинаковую длину x_train и y_train
if len(x_train) != len(y_train):
    raise ValueError("Массивы x_train и y_train должны быть одинаковой длины.")

# Явное преобразование в numpy массивы с типом float64
x_train_array = np.array(x_train, dtype=np.float64)
y_train_array = np.array(y_train, dtype=np.float64)
x_predict_array = np.array(x_predict, dtype=np.float64)

A = np.vstack([x_train_array, np.ones(len(x_train_array))]).T

a, b = np.linalg.lstsq(A, y_train_array, rcond=None)[0]

y_predict_array = a * x_predict_array + b

for y in y_predict_array:
    yield y, a, b
$$ LANGUAGE plpython3u;

select * from udf_tasks.linear_regression_fomin_p_a(
   array[1, 2, 3],            -- x_train
   array[1.1, 1.9, 3.2],      -- y_train
   array[4, 5, 6]             -- x_predict
); 