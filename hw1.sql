-- ============================================================
-- Домашнее задание к лекции «SQL. Введение»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Сулейманов Турал Кямалович
-- ============================================================
-- Формат: задания по порядку, каждое начинается с комментария
-- с номером; под каждым запросом — вывод (2–3 предложения).
-- Запрос без вывода не засчитывается.
-- ============================================================

SET search_path TO hh_school;


-- ============================================================
-- БЛОК А. Разминка: термины и структура (текстом)
-- ============================================================

-- ЗАДАНИЕ А1
-- 1) Категория и конкретный тип колонок:
--    vacancies.salary_from        — категория: числовой     тип: INT
--    vacancies.vacancy_name       — категория: строковый    тип: TEXT
--    vacancies.published_at       — категория: дата и время тип: TIMESTAMP 
--    employers.is_accredited_it   — категория: логический   тип: BOOLEAN
--    responses.created_at         — категория: дата и время тип: TIMESTAMP
--
-- 2) Первичные ключи таблиц:
--    areas: area_id
--    employers: employer_id
--    vacancies: vacancy_id
--    vacancy_details: vacancy_id  (чем особенный: этот ключ является одновременно первичным ключом, и внешним ключом, ссылающийся на vacancies.vacancy_id)
--    responses: response_id
--
-- 3) Почему vacancy_name не может быть первичным ключом:
--    1) название вакансий повторяются и поэтому эта колонка не может быть первичным ключем;
--    2) категориальный тип этой колонки TEXT при использовании колонок с таким типом тратится лишняя память ,
--    проще взять колонку с INT + название могут быть не приведени к единому типу ( с заглавной буквой, с пробелами и тд)

--    Запрос для подтверждения числом:

-- запрос:

    SELECT vacancy_name, count(*) FROM vacancies
    GROUP BY vacancy_name
    ORDER BY count(*) DESC 
    LIMIT 1;

-- Вывод:
-- Самым частым названием вакансии является "Стажёр: аналитик данных"
-- Кол-во = 6
--
-- 4. Что произойдёт при записи строки «по договорённости» в salary_from:
-- Произойдёт ошибка (несоответствие типов данных), так
-- как тип этой колонки INT,а при записи "по договорённости" мы передаём TEXT.  
-- Такое поведение СУБД - это хорошо, тк оберегает нас от ошибок типов и защищает нас от мусора

-- ============================================================
-- БЛОК Б. Первые запросы: SELECT, WHERE, ORDER BY
-- ============================================================

-- ЗАДАНИЕ Б1
-- Запрос: experience

    SELECT DISTINCT experience FROM vacancies;

-- Запрос: employment

    SELECT DISTINCT employment FROM vacancies;

-- Запрос: professional_role

    SELECT DISTINCT professional_role FROM vacancies;

-- Вывод:
-- experience: всего 3 типа, проблем с качеством данных нет
-- employment: всего 3 типа, проблем с качеством данных нет
-- professional_role: 5 типов, проблем с качеством данных нет 

-- ЗАДАНИЕ Б2
-- Запрос 1: стажировки в Москве без опыта, вакансия открыта
    
    SELECT vacancy_id,vacancy_name,salary_from,published_at
    FROM vacancies
    WHERE area_id = 1
      AND employment = 'Стажировка'
      AND experience = 'Нет опыта'
      AND closed_at IS NULL
    ORDER BY published_at DESC;

-- Запрос 2: топ-10 вакансий по salary_from

    SELECT 
        vacancy_name, 
        professional_role, 
        salary_from
    FROM vacancies
    ORDER BY salary_from DESC NULLS LAST
    LIMIT 10;

-- Вывод:
-- В первом запросе нашлось 8 вакансий. Если убрать фильтр по Москве,
-- число вакансий увеличится до 10. Это говорит нам , что основная часть вакансий находится в Москве.


-- ЗАДАНИЕ Б3
-- Ловушка 1. NULL — выполнить и объяснить результат
SELECT count(*) FROM vacancies WHERE closed_at = NULL;
SELECT count(*) FROM vacancies WHERE closed_at IS NULL;

-- Ловушка 2. AND / OR — выполнить и объяснить результат
SELECT count(*) FROM vacancies
WHERE area_id = 1 OR area_id = 2 AND experience = 'Нет опыта';

SELECT count(*) FROM vacancies
WHERE (area_id = 1 OR area_id = 2) AND experience = 'Нет опыта';

-- Вывод:
-- Ловушка 1: в первом случае у нас вывело 0 (можно ошибочно подумать, что открытых вакансий вообще нет), 
-- тк в sql нельзя писать = NULL (будет возвращать UNKNOWN),
-- NULL в closed_at означает, что вакансия ещё открыта 
-- во втором случае всё отработало правильно и вывело 33 
-- Ловушка 2: в первом случае у нас вывело 31, тк у AND приоритет выше чем у OR , выполняется сначала (area_id = 2 AND experience = 'Нет опыта';),
-- затем этот результать объединяется с (area_id = 1 OR).
-- Во втором случае все отработало правильно и вывело 20
-- на вопрос "вакансии из Москвы или Санкт-Петербурга, но обязательно без опыта" отвечает второй запрос.


-- ============================================================
-- БЛОК В. Агрегации и метрики
-- ============================================================

-- ЗАДАНИЕ В1
-- Запрос 1: счётчики (строки, зарплата указана, направления, работодатели)
    SELECT count(*) AS total_vacancies,
        count(salary_from) AS vacancies_with_salary,          
        count(DISTINCT professional_role) AS unique_roles,    
        count(DISTINCT employer_id) AS unique_employers       
    FROM vacancies;

-- Запрос 2: доля активных вакансий (без JOIN)
    SELECT
        count(*) - count(closed_at) AS open_vacancies,
        count(closed_at) AS closed_vacancies,
        round(100.0 * (count(*) - count(closed_at)) / count(*), 1) AS open_pct
    FROM vacancies;

-- Вывод:
-- 1)
-- count(*) = 52 считает абсолютно все строки таблицы подряд
-- count(salary_from) = 44 считает строки с непустыми значениями (8 было пропущено)
-- count(DISTINCT professional_role) = 5 считает только уникальные значения, отбрасывая дубликаты
-- 2)
-- Сейчас в бд активных вакансий 33 из 52, что составляет 63.5% от общего числа.


-- ЗАДАНИЕ В2
-- Запрос 1: направления — вакансии, работодатели, средняя зарплата

    SELECT professional_role,
        count(*) AS vacancies_count,
        count(DISTINCT employer_id) AS employers_count,       
        round(avg(salary_from)) AS avg_salary_from            
    FROM vacancies
    GROUP BY professional_role
    ORDER BY vacancies_count DESC;


-- Запрос 2: то же, только направления с ≥ 5 открытыми вакансиями (WHERE + HAVING)

    SELECT professional_role,                                    
        count(*) AS vacancies_count,                          
        count(DISTINCT employer_id) AS employers_count,       
        round(avg(salary_from)) AS avg_salary_from            
    FROM vacancies                                            
    WHERE closed_at IS NULL                                   
    GROUP BY professional_role                                
    HAVING count(*) >= 5                                      
    ORDER BY vacancies_count DESC;  

-- Вывод:
-- 1) Больше половины рынка занимают «Аналитик данных» (16) и «Разработчик» (15). 
-- Соискатель подумал бы, что туда проще всего         
-- устроиться, раз вакансий больше. Для реального           
-- вывода не хватает данных об откликах, так как мы не видим количество конкурентов.
-- На одно место могут претендовать сотни людей, тем самым будет сложнее поступить туда.

-- 2) Потому что WHERE фильтрует строки ДО группировки, а HAVING уже готовые группы после подчёта.
-- Если написать WHERE count(*) >= 5, будет ошибка, тк на этапе WHERE база ещё не посчитала количество.

-- 3) avg(salary_from) отвечает на вопрос: «какая средняя зарплата у тех, кто её написал в объявлении». 
-- На реальную среднюю по рынку не отвечает, тк вакансии с NULL функция avg проигнорировала.


-- ============================================================
-- БЛОК Г. Соединение таблиц
-- ============================================================

-- ЗАДАНИЕ Г1
-- Запрос: топ-5 по salary_from с названием компании и городом (псевдонимы таблиц)
    SELECT 
        v.vacancy_name,
        e.employer_name,
        a.area_name,
        v.salary_from
    FROM vacancies v
    JOIN employers e ON v.employer_id = e.employer_id         
    JOIN areas a ON v.area_id = a.area_id
    ORDER BY v.salary_from DESC NULLS LAST
    LIMIT 5;

-- Вывод:                                               
-- Если убрать псевдонимы и написать просто area_id, бд выдаст ошибку                       
-- Потому, что колонка area_id существует сразу в нескольких соединяемых таблицах и  
-- СУБД не может понять из какой именно таблицы мы хотим взять это поле.


-- ЗАДАНИЕ Г2
-- Запрос 1: все работодатели, число вакансий и откликов (LEFT JOIN)

    SELECT e.employer_name, count(DISTINCT v.vacancy_id) AS vacancies_count,
     count(r.response_id) AS responses_count
    FROM employers e
    LEFT JOIN vacancies v ON e.employer_id = v.employer_id
    LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
    GROUP BY e.employer_id, e.employer_name
    ORDER BY responses_count DESC;
   

-- Запрос 2: тот же запрос с INNER JOIN

    SELECT e.employer_name, count(DISTINCT v.vacancy_id) AS vacancies_count,
     count(r.response_id) AS responses_count
    FROM employers e
    JOIN vacancies v ON e.employer_id = v.employer_id
    JOIN responses r ON v.vacancy_id = r.vacancy_id
    GROUP BY e.employer_id, e.employer_name
    ORDER BY responses_count DESC;

-- Вывод:
-- В первом запросе вышло 12 строк, а во втором 11 строк. 
-- 1) Вакансии считаем через count(DISTINCT v.vacancy_id), 
--    потому что при объединении с таблицей responses одна вакансия размножается на  
--    столько строк, сколько у неё откликов.          
--    Обычный count(*) посчитал бы количество откликов, а не самих вакансий.

-- 2) Исчезла компания «ГринЭнерго».   
--    Это потеря, потому что HR как раз ищет компании с нулём откликов, 
--    чтобы разобраться в проблеме, а INNER JOIN её просто скрыл.       

-- 3) LEFT JOIN берём, когда важны вообще все строки и нули. 
--    INNER JOIN берём, когда нужны только совпадения с обеих сторон, 
--    а строки без пары нужно выкинуть.


-- ============================================================
-- БЛОК Д. Функции и финальный кейс
-- ============================================================

-- ЗАДАНИЕ Д1
-- Запрос: помесячная динамика откликов и конверсия
-- (месяц как дата, условный агрегат, nullif в знаменателе)
    SELECT 
        date_trunc('month', created_at)::date AS response_month,
        count(*) AS responses_count,
        count(*) FILTER (WHERE status = 'invited') AS invitations_count,
        round(100.0 * count(*) FILTER (WHERE status = 'invited') / nullif(count(*), 0), 1) AS conversion_pct
    FROM responses
    GROUP BY 1
    ORDER BY 1;

-- Вывод:
-- 1. Конверсия максимальна в июне 2026 года (19.5%)

-- 2. Можно, тк объём данных в июне большой: 118 откликов, 
--    поэтому это статистически надёжный результат и не является случайностью        

-- 3. С последним месяцем проблема в том, что он неполный, данные обрываются середине месяца.
--    Поэтому этот месяц учитывать нельзя


-- ЗАДАНИЕ Д2
-- Запрос: таблица по направлениям (вакансии, отклики, приглашения,
-- откликов на вакансию, конверсия)
                      
    SELECT v.professional_role,
        count(DISTINCT v.vacancy_id) AS vacancies_count,      
        count(r.response_id) AS responses_count,              
        count(r.response_id) FILTER (WHERE r.status = 'invited') AS invitations_count,                            
        round(count(r.response_id)::numeric / nullif(count(DISTINCT v.vacancy_id), 0), 1) AS responses_per_vacancy,                                      
        round(100.0 * count(r.response_id) FILTER (WHERE r.status = 'invited') / nullif(count(r.response_id), 0), 1) AS conversion_pct                                              
    FROM vacancies v                                          
    LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id      
    GROUP BY v.professional_role                              
    ORDER BY conversion_pct DESC; 
-- Письменные ответы:
-- 1. Совпадает ли направление с наибольшим числом вакансий с направлением
--    с наибольшей конверсией?
-- Нет. Больше всего вакансий у "Аналитика данных" 16 штук, но конверсия у него 12.1%
-- А наивысшая конверсия у "Тестировщика" 35.9%.

-- 2. Какое направление выбрать и почему (опираясь на два столбца):
-- Опираясь на столбцы "responses_per_vacancy" и "conversion_pct", 
-- выгодно выбрать "Тестировщик" или "Разработчик". 
-- У Тестировщика огромная конверсия 35.9%, при низкой конкуренции
-- всего 5.6 отклика на место. 
-- А на "Аналитика данных" огромный ажиотаж 19.6 откликов на вакансию,
-- а конверсия всего 12.1%, поэтому пробиться туда намного труднее.

-- 3. Оговорка к выводу:
-- В данных нет разделения по грейдам.
-- Там, где зарплаты выше, требуют гораздо больше сложных знаний, поэтому новичку
-- без опыта туда будет просто не пробиться.

-- ============================================================
-- БЛОК Е. Со звёздочкой
-- ============================================================

-- ЗАДАНИЕ Е1
-- Исходный запрос (выполнить и посмотреть результат):
-- SELECT v.professional_role,
-- count(*) AS vacancies,
-- sum(v.salary_from) AS total_salary,
-- count(r.response_id) / count(*) AS responses_per_vacancy
-- FROM vacancies v
-- JOIN responses r ON v.vacancy_id = r.vacancy_id
-- WHERE v.closed_at = NULL
-- GROUP BY 1;
--
-- Ошибки (минимум четыре):
-- 1. Сравнение с NULL через знак "=" (WHERE v.closed_at = NULL).                                                      
--    Такое сравнение возвращает UNKNOWN,поэтому запрос будет возвращать 0. 
-- 2. Использование INNER JOIN вместо LEFT JOIN.          
--    Если у какой-то открытой вакансии пока нет откликов, обычный JOIN просто выкинет ее из отчета.                   
-- 3. Подсчёт вакансий через count(*) при связи 1:N                                
--    Из-за JOIN строки вакансий размножились. count(*) посчитает количество откликов, а не вакансий.
--    Надо сделать так: COUNT(DISTINCT v.vacancy_id).                   
-- 4. Из-за JOIN зарплата одной вакансии сложилась 
--    столько раз, сколько на неё пришло откликов.
-- 5. Деление целых чисел отсекает дробь нужно использовать ::numeric
--    делить надо на уникальные вакансии count(DISTINCT), а не на count(*).


-- Исправленный запрос:

    SELECT v.professional_role,
        count(DISTINCT v.vacancy_id) AS vacancies,            
        round(count(r.response_id)::numeric / nullif(count(DISTINCT v.vacancy_id), 0), 1) AS responses_per_vacancy                                       
    FROM vacancies v                                          
    LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id      
    WHERE v.closed_at IS NULL                                 
    GROUP BY v.professional_role                              
    ORDER BY vacancies DESC;  

-- Какие два правила из лекции защитили бы от этих ошибок при написании запроса:
-- 1. Правило работы с NULL
-- 2. Контролировать размножение строк при JOIN.
