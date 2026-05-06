# Welcome to my A/B-testing projects!
This is a folder for my learning tasks for A/B testing from my university.
You can find project descriptions in Russian and English. / Это папка для моих учебных заданий по A/B-тестированию из моего университета. Вы можете найти описание к проектам на русском и английском. 


# RU
### stat_criteria
Задача: Научиться пользоваться T-тестом и бутстрапом.

Библиотеки: `scipy`, `statsmodels`, `pandas`, `matplotlib`, `seaborn`

Что можно найти в этом блокноте: T-тест, бутстрап, валидация на АА-тестах, сходимость T-теста и бутстрапа

### design_mde
Задача: Задизайнить эксперимент, провести исследования MDE, определиться с параметрами теста.

Библиотеки: `scipy`, `statsmodels`, `pandas`, `matplotlib`, `seaborn`

Что можно найти в этом блокноте: Кастомная функция расчёта MDE, карточка дизайна эксперимента, использование LateX для написания формулы в ячейке.

### split
Задача: Реализовать систему сплитования тест-контроль, провалидировать её, модифицировать и применить.

Библиотеки: `scipy`, `statsmodels`, `hashlib`, `pandas`, `matplotlib`, `seaborn`

Что можно найти в этом блокноте: Кастомная функция сплитования, валидация сплитования тестами Хи-квадрат и Колмогорова-Смирнова.

### result_analysis
Задача: Проанализировать результаты A/B-теста.

Библиотеки: `scipy`, `statsmodels`, `pandas`, `matplotlib`, `seaborn`, `collections`

Что можно найти в этом блокноте: Расчёт коэффициента выборки (SRM), реализация и валидация относительного T-теста, анализ результатов A/B-теста, использование namedtuple для получения результатов вызова функции.

### cuped
Задача: Реализовать и провалидировать методы снижения дисперсии, проанализировать результаты A/B-теста.

Библиотеки: `scipy`, `statsmodels`, `pandas`, `matplotlib`, `seaborn`, `collections`

Что можно найти в этом блокноте: Реализация и валидация CUPED (абсолютного и относительного), анализ результатов A/B-теста.

### balancing
Задача: Реализовать и провалидировать методы снижения дисперсии (совместно CUPED и пост-стратификацию).

Библиотеки: `scipy`, `statsmodels`, `pandas`, `matplotlib`, `seaborn`, `collections`

Что можно найти в этом блокноте: Реализация и валидация CUPED (абсолютного и относительного), реализация и валидация стратифицированного разбиения и пост-стратификации.

### multitesting
Задача: Научиться работать с поправками, исправляющими проблему множественного тестирования.

Библиотеки: `scipy`, `statsmodels`, `pandas`, `matplotlib`, `seaborn`, `collections`

Что можно найти в этом блокноте: Реализация и валидация поправок Бонферрони, Холма и Бенджамини-Хохберга.

# EN
### stat_criteria
Task: Learn how to use T-test and bootstrap.

Libraries: `scipy`, `statsmodels`, `pandas`, `matplotlib`, `seaborn`

What can be found in this notebook: T-test, bootstrap, validation on AA tests, convergence of T-test and bootstrap

### design_mde
Task: To design an experiment, conduct MDE research, and determine the test parameters.

Libraries: `scipy`, `statsmodels`, `pandas`, `matplotlib`, `seaborn`

What can be found in this notebook: A custom MDE calculation function, an experiment design card, and the use of LateX to write a formula in a cell.

### split
Task: To implement a test control splice system, validate it, modify it, and apply it.

Libraries: `scipy`, `statsmodels`, `hashlib`, `pandas`, `matplotlib`, `seaborn`

What can be found in this notebook: Custom splitting function, validation of splitting using Chi-square and Kolmogorov-Smirnov tests.

### result_analysis
Task: To analyze the results of the A/B test.

Libraries: `scipy`, `statsmodels`, `pandas`, `matplotlib`, `seaborn`, `collections`

What can be found in this notebook: Calculation of the sampling coefficient (SRM), implementation and validation of the relative T-test, analysis of the results of the A/B test, using namedtuple to obtain the results of a function call.

### cuped
Task: To implement and test methods to reduce variance, analyze the results of the A/B test.

Libraries: `scipy`, `statsmodels`, `pandas`, `matplotlib`, `seaborn`, `collections`

What can be found in this notebook: Implementation and validation of CUPED (absolute and relative), analysis of A/B test results.

### balancing
Task: To implement and validate methods for reducing variance (jointly CUPED and post-stratification).

Libraries: `scipy`, `statsmodels`, `pandas`, `matplotlib`, `seaborn`, `collections`

What can be found in this notebook: Implementation and validation of CUPED (absolute and relative), implementation and validation of stratified partitioning and post-stratification.

### multitesting
Task: To learn how to work with amendments that correct the problem of multiple testing.

Libraries: `scipy`, `statsmodels`, `pandas`, `matplotlib`, `seaborn`, `collections`

What can be found in this notebook: Implementation and validation of Bonferroni, Holm and Benjamini-Hochberg corrections.