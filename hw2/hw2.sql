-- ============================================================
-- Домашнее задание к лекции «Продвинутый SQL»
-- Школа Аналитиков hh.ru · учебная база hh_school
-- Автор: Сулейманов Турал Кямалович
-- ============================================================
-- Формат сдачи:
-- Один файл .sql. Задания по порядку, каждое начинается комментарием
-- с номером. Под каждым итоговым запросом - контрольные значения и вывод.
-- ============================================================

SET search_path TO hh_school;


-- ============================================================
-- БЛОК А
-- ============================================================

-- ЗАДАНИЕ 1.
-- ДОРАБОТКА.

-- 1. Пропуски в calls:
    SELECT
        count(*) AS total,
        count(response_id) AS resp_id,
        count(call_duration) AS duration
    FROM calls;

-- 2. Звонки без отклика:
    SELECT 
        call_id, 
        status, 
        call_duration, 
        call_at
    FROM calls
    WHERE response_id IS NULL
    ORDER BY call_id;

-- 3. Звонок со статусом error:
    SELECT 
        call_id, 
        status, 
        call_at
    FROM calls
    WHERE status = 'error';

-- 4. Пропуски в messages:
    SELECT
        count(*) AS total,
        count(response_id) AS resp_id,
        count(sent_at) AS sent_at,
        count(message_text) AS text_cnt
    FROM messages;

-- 5. Пустые сообщения:
    SELECT 
        sender_role, 
        count(*) AS empty_cnt
    FROM messages
    WHERE message_text IS NULL OR btrim(message_text) = ''
    GROUP BY sender_role;

-- 6. События раньше отклика:
    SELECT 
        'calls' AS tbl, 
        count(*) AS cnt
    FROM calls c
    JOIN responses r ON c.response_id = r.response_id
    WHERE c.call_at < r.created_at
    UNION ALL
    SELECT 
        'messages', 
        count(*)
    FROM messages m
    JOIN responses r ON m.response_id = r.response_id
    WHERE m.sent_at < r.created_at;

-- 7. Несовпадение ID с откликом:
    SELECT 
        'calls' AS tbl, 
        count(*) AS cnt
    FROM calls c
    JOIN responses r ON c.response_id = r.response_id
    WHERE c.applicant_id <> r.resume_id OR c.vacancy_id <> r.vacancy_id
    UNION ALL
    SELECT 
        'messages', 
        count(*)
    FROM messages m
    JOIN responses r ON m.response_id = r.response_id
    WHERE m.applicant_id <> r.resume_id OR m.vacancy_id <> r.vacancy_id;

-- 8. Дубликаты:
    SELECT 
        'calls' AS tbl, 
        count(*) AS cnt
    FROM (
        SELECT response_id, call_at, caller_role, count(*)
        FROM calls 
        WHERE response_id IS NOT NULL
        GROUP BY response_id, call_at, caller_role 
        HAVING count(*) > 1
    ) s
    UNION ALL
    SELECT 
        'messages', 
        count(*)
    FROM (
        SELECT response_id, sent_at, sender_role, count(*)
        FROM messages
        GROUP BY response_id, sent_at, sender_role 
        HAVING count(*) > 1
    ) s;

-- Расчет длительности звонков:
    WITH stats AS (
        SELECT 
            round(avg(call_duration)::numeric, 2) AS avg_duration,
            percentile_cont(0.5) WITHIN GROUP (ORDER BY call_duration) AS p50_duration,
            percentile_cont(0.99) WITHIN GROUP (ORDER BY call_duration) AS p99_duration
        FROM calls
        WHERE status = 'successful'
    )
    SELECT 
        s.avg_duration,
        s.p50_duration,
        s.p99_duration,
        count(c.call_id) FILTER (WHERE c.call_duration > s.p99_duration) AS count_above_p99,
        round(avg(c.call_duration) FILTER (WHERE c.call_duration <= s.p99_duration)::numeric, 2) AS avg_excl_p99
    FROM calls c
    CROSS JOIN stats s
    WHERE c.status = 'successful'
    GROUP BY s.avg_duration, s.p50_duration, s.p99_duration;

-- ДОРАБОТКА.
-- Итоговые значения:
-- Средняя длительность: 467.28 сек
-- Медиана (p50): 438 сек
-- 99-й перцентиль (p99): 890.4 сек
-- Звонков выше p99: 2 шт (id: 700159 - 892 сек, 700199 - 899 сек)
-- Средняя длительность без выбросов: 462.49 сек

-- Вывод:
-- 1. В таблице calls:
--    - 8 звонков без response_id (номера 700244, 700245, 700246, 700247, 700248, 700249, 700250, 700251). Непонятно, к какому отклику они относятся, поэтому исключаем их из анализа откликов.
--    - 1 звонок со статусом error (id 700163). Это сбой, разговора не было, тоже исключаем.
--    - 70 звонков без длительности (69 unsuccessful и 1 error). Это нормально: раз звонок не состоялся, длительности и нет.
-- 2. В таблице messages проблем нет:
--    - Все 2862 строки заполнены без пропусков и привязаны к откликам.
--    - Нет пустых текстов, нет сообщений раньше отклика, нет нестыковок по id и дублей.
-- 3. Выбросы длительности:
--    - Звонки по 892 и 899 сек считаю нормальными, а не ошибками: разговор на 15 минут вполне возможен при интервью.
--    - Для типичной длительности лучше брать медиану (438 сек), так как она устойчива к длинным разговорам.


-- ============================================================
-- БЛОК Б
-- ============================================================

-- ЗАДАНИЕ 2.
-- Запрос:

    WITH msgs_7d AS (                                                            
        SELECT                                                                   
            m.response_id,                                                       
            m.employer_id,                                                       
            m.message_id::text AS event_id,                                      
            m.sent_at AS event_at,                                               
            'message' AS event_type                                              
        FROM messages m                                                          
        JOIN responses r ON m.response_id = r.response_id                        
        WHERE m.sender_role = 'employer'                                         
          AND m.sent_at >= r.created_at                                          
          AND m.sent_at <= r.created_at + INTERVAL '7 days'                      
    ),                                                                           
    calls_7d AS (                                                                
        SELECT                                                                   
            c.response_id,                                                       
            c.employer_id,                                                       
            c.call_id::text AS event_id,                                         
            c.call_at AS event_at,                                               
            'call' AS event_type                                                 
        FROM calls c                                                             
        JOIN responses r ON c.response_id = r.response_id                        
        WHERE c.caller_role = 'employer'                                         
          AND c.call_at >= r.created_at                                          
          AND c.call_at <= r.created_at + INTERVAL '7 days'                      
          AND c.status != 'error'                                                
    ),                                                                           
    events AS (
        SELECT * FROM calls_7d
        UNION ALL
        SELECT * FROM msgs_7d
    )
    SELECT 
        count(*) AS total_events,
        count(DISTINCT response_id) AS distinct_responses,
        count(*) FILTER (WHERE event_type = 'call') AS calls_count,
        count(*) FILTER (WHERE event_type = 'message') AS messages_count         
    FROM events;
    

-- Итоговые значения:
-- 1. Общее количество событий: 1095
-- 2. Количество откликов с коммуникацией: 382 
-- 3. Количество звонков: 107
-- 4. Количество сообщений: 988

-- Вывод:

-- За первые 7 дней после отклика работодатели совершили 1095 коммуникаций по 382 уникальным откликам 
-- Основным каналом связи является переписка: 988 из 1095 событий, 
-- тогда как звонки используются значительно реже 107 событий.


-- ЗАДАНИЕ 3. 

-- Запрос:

    WITH msgs_7d AS (
        SELECT 
            m.response_id,
            m.employer_id,
            m.message_id::text AS event_id,
            m.sent_at AS event_at,
            'message' AS event_type
        FROM messages m
        JOIN responses r ON m.response_id = r.response_id
        WHERE m.sender_role = 'employer'
          AND m.sent_at >= r.created_at
          AND m.sent_at <= r.created_at + INTERVAL '7 days'
    ),
    calls_7d AS (
        SELECT 
            c.response_id,
            c.employer_id,
            c.call_id::text AS event_id,
            c.call_at AS event_at,
            'call' AS event_type
        FROM calls c
        JOIN responses r ON c.response_id = r.response_id
        WHERE c.caller_role = 'employer'
          AND c.call_at >= r.created_at
          AND c.call_at <= r.created_at + INTERVAL '7 days'
          AND c.status != 'error'
    ),
    events AS (
        SELECT * FROM calls_7d
        UNION ALL
        SELECT * FROM msgs_7d
    ),
-- Шаг 1
    timeline AS (
        SELECT 
            response_id,
            employer_id,
            event_id,
            event_at,
            event_type,
            ROW_NUMBER() OVER (PARTITION BY response_id ORDER BY event_at, event_type, event_id) AS event_seq,
            LAG(event_at) OVER (PARTITION BY response_id ORDER BY event_at, event_type, event_id) AS prev_event_at,
            LEAD(event_type) OVER (PARTITION BY response_id ORDER BY event_at, event_type, event_id) AS next_event_type,
            COUNT(*) OVER (
                PARTITION BY response_id 
                ORDER BY event_at, event_type, event_id 
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS running_count,
            FIRST_VALUE(event_type) OVER (
                PARTITION BY response_id 
                ORDER BY event_at, event_type, event_id 
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ) AS first_comm_type,
            LAST_VALUE(event_type) OVER (
                PARTITION BY response_id 
                ORDER BY event_at, event_type, event_id 
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ) AS last_comm_type,
            ROUND((EXTRACT(EPOCH FROM (event_at - LAG(event_at) OVER (PARTITION BY response_id ORDER BY event_at, event_type, event_id))) / 3600.0)::numeric, 2) AS interval_hours
        FROM events
    ),
-- Агрегация событий до уровня отклика
    response_summary AS (
        SELECT 
            response_id,
            COUNT(*) AS total_comms,
            COUNT(*) FILTER (WHERE event_type = 'call') AS calls_count,
            COUNT(*) FILTER (WHERE event_type = 'message') AS messages_count,
            MIN(event_at) AS first_event_at,
            MAX(first_comm_type) AS first_event_type,
            MAX(event_type) FILTER (WHERE event_seq = 2) AS second_event_type,
            MAX(last_comm_type) AS last_event_type,
            MAX(interval_hours) AS max_interval_hours
        FROM timeline
        GROUP BY response_id
    ),
-- Шаг 2
    mart AS (
        SELECT 
            r.response_id,
            v.employer_id,
            v.professional_role,
            r.status AS response_status,
            COALESCE(rs.total_comms, 0) AS total_comms,
            COALESCE(rs.calls_count, 0) AS calls_count,
            COALESCE(rs.messages_count, 0) AS messages_count,
            rs.first_event_at,
            rs.first_event_type,
            rs.second_event_type,
            rs.last_event_type,
            ROUND((EXTRACT(EPOCH FROM (rs.first_event_at - r.created_at)) / 3600.0)::numeric, 2) AS hours_to_first_comm,
            rs.max_interval_hours
        FROM responses r
        JOIN vacancies v ON r.vacancy_id = v.vacancy_id
        LEFT JOIN response_summary rs ON r.response_id = rs.response_id
    )
-- Контрольный запрос по витрине
    SELECT 
        COUNT(*) AS total_rows,
        COUNT(*) FILTER (WHERE total_comms > 0) AS with_comms,
        COUNT(*) FILTER (WHERE total_comms = 0) AS without_comms,
        COUNT(*) FILTER (WHERE first_event_type = 'message') AS first_is_msg,
        COUNT(*) FILTER (WHERE first_event_type = 'call') AS first_is_call
    FROM mart;              

-- Итоговые значения:
-- 1. Всего строк в витрине: 628
-- 2. Откликов с коммуникацией: 382
-- 3. Откликов без коммуникации: 246
-- 4. Первая коммуникация - сообщение: 314 
-- 5. Первая коммуникация - звонок: 68

-- Вывод:
-- В витрину успешно вошли все 628 откликов. 
-- Работодатели выходят на связь в первые 7 дней только по 382 откликов, 
-- а почти 246 откликов остаются полностью без внимания со стороны компании. 
-- При первичном контакте работодатели подавляюще отдают предпочтение сообщениям(314 случаев), 
-- а звонить в качестве первого шага выбирают лишь 68 человек.     

-- ============================================================
-- БЛОК В.
-- ============================================================

-- ЗАДАНИЕ 4. 
-- Запрос:

    WITH msgs_7d AS (
        SELECT 
            m.response_id,
            m.employer_id,
            m.message_id::text AS event_id,
            m.sent_at AS event_at,
            'message' AS event_type
        FROM messages m
        JOIN responses r ON m.response_id = r.response_id
        WHERE m.sender_role = 'employer'
          AND m.sent_at >= r.created_at
          AND m.sent_at <= r.created_at + INTERVAL '7 days'
    ),
    calls_7d AS (
        SELECT 
            c.response_id,
            c.employer_id,
            c.call_id::text AS event_id,
            c.call_at AS event_at,
            'call' AS event_type
        FROM calls c
        JOIN responses r ON c.response_id = r.response_id
        WHERE c.caller_role = 'employer'
          AND c.call_at >= r.created_at
          AND c.call_at <= r.created_at + INTERVAL '7 days'
          AND c.status != 'error'
    ),
    events AS (
        SELECT * FROM calls_7d
        UNION ALL
        SELECT * FROM msgs_7d
    ),
    timeline AS (
        SELECT 
            response_id,
            employer_id,
            event_id,
            event_at,
            event_type,
            ROW_NUMBER() OVER (PARTITION BY response_id ORDER BY event_at, event_type, event_id) AS event_seq,
            LAG(event_at) OVER (PARTITION BY response_id ORDER BY event_at, event_type, event_id) AS prev_event_at,
            LEAD(event_type) OVER (PARTITION BY response_id ORDER BY event_at, event_type, event_id) AS next_event_type,
            COUNT(*) OVER (
                PARTITION BY response_id 
                ORDER BY event_at, event_type, event_id 
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS running_count,
            FIRST_VALUE(event_type) OVER (
                PARTITION BY response_id 
                ORDER BY event_at, event_type, event_id 
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ) AS first_comm_type,
            LAST_VALUE(event_type) OVER (
                PARTITION BY response_id 
                ORDER BY event_at, event_type, event_id 
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ) AS last_comm_type,
            ROUND((EXTRACT(EPOCH FROM (event_at - LAG(event_at) OVER (PARTITION BY response_id ORDER BY event_at, event_type, event_id))) / 3600.0)::numeric, 2) AS interval_hours
        FROM events
    ),
    response_summary AS (
        SELECT 
            response_id,
            COUNT(*) AS total_comms,
            COUNT(*) FILTER (WHERE event_type = 'call') AS calls_count,
            COUNT(*) FILTER (WHERE event_type = 'message') AS messages_count,
            MIN(event_at) AS first_event_at,
            MAX(first_comm_type) AS first_event_type,
            MAX(event_type) FILTER (WHERE event_seq = 2) AS second_event_type,
            MAX(last_comm_type) AS last_event_type,
            MAX(interval_hours) AS max_interval_hours
        FROM timeline
        GROUP BY response_id
    ),
    mart AS (
        SELECT 
            r.response_id,
            v.employer_id,
            v.professional_role,
            r.status AS response_status,
            COALESCE(rs.total_comms, 0) AS total_comms,
            COALESCE(rs.calls_count, 0) AS calls_count,
            COALESCE(rs.messages_count, 0) AS messages_count,
            rs.first_event_at,
            rs.first_event_type,
            rs.second_event_type,
            rs.last_event_type,
            ROUND((EXTRACT(EPOCH FROM (rs.first_event_at - r.created_at)) / 3600.0)::numeric, 2) AS hours_to_first_comm,
            rs.max_interval_hours
        FROM responses r
        JOIN vacancies v ON r.vacancy_id = v.vacancy_id
        LEFT JOIN response_summary rs ON r.response_id = rs.response_id
    ),
    role_employer_stats AS (
        SELECT 
            professional_role,
            employer_id,
            COUNT(*) AS total_responses,
            COUNT(*) FILTER (WHERE total_comms > 0) AS comms_responses,
            ROUND(COUNT(*) FILTER (WHERE total_comms > 0) * 100.0 / COUNT(*), 2) AS processed_share,
            ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first_comm)::numeric, 2) AS p50_hours,
            ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY hours_to_first_comm)::numeric, 2) AS p90_hours,
            ROUND(COUNT(*) FILTER (WHERE response_status = 'invited') * 100.0 / COUNT(*), 2) AS invite_conversion
        FROM mart
        GROUP BY professional_role, employer_id
        HAVING COUNT(*) >= 8
    ),
    ranked AS (
        SELECT 
            professional_role,
            employer_id,
            total_responses,
            comms_responses,
            processed_share,
            p50_hours,
            p90_hours,
            invite_conversion,
            DENSE_RANK() OVER (
                PARTITION BY professional_role 
                ORDER BY processed_share DESC, p50_hours ASC NULLS LAST
            ) AS rank_place
        FROM role_employer_stats
    )
    SELECT 
        professional_role,
        rank_place,
        employer_id,
        total_responses,
        comms_responses,
        processed_share,
        p50_hours,
        p90_hours,
        invite_conversion
    FROM ranked
    WHERE rank_place <= 2
    ORDER BY professional_role, rank_place, employer_id;
                                                                                                                                                  
-- ДОРАБОТКА.
-- Контрольные значения (professional_role | место | employer_id):
-- Аналитик данных: 1 место - работодатель 109, 2 место - работодатель 103
-- Дата-инженер: 1 место - работодатель 106, 2 место - работодатель 101
-- Продуктовый аналитик: 1 место - работодатель 103, 2 место - работодатель 102
-- Разработчик: 1 место - работодатель 112, 2 место - работодатель 104
-- Тестировщик: 1 место - работодатель 107, 2 место - работодатель 108

-- Вывод:
-- 1. Лучше всего компании разбирают отклики на аналитиков данных и тестировщиков (85-89%), а хуже всего - на дата-инженеров (46%).
-- 2. Скорость первого контакта не всегда идет вместе с долей ответов: например, компании 108 и 106 отвечают очень быстро (медиана 6-10 ч), но разбирают меньшую часть откликов, поэтому по правилам рейтинга они ниже.
-- 3. Чаще всего приглашают тестировщиков (конверсия 37-41%), у остальных направлений она около 10-20%. Быстрый ответ сам по себе не гарантирует приглашение.



-- ЗАДАНИЕ 5.

-- Запрос:

    WITH msgs_7d AS (
        SELECT 
            m.message_id,
            m.response_id,
            m.employer_id,
            m.sender_role,
            m.sent_at
        FROM messages m
        JOIN responses r ON m.response_id = r.response_id
        WHERE m.sent_at >= r.created_at
          AND m.sent_at <= r.created_at + INTERVAL '7 days'
    ),
    dialog_steps AS (
        SELECT 
            message_id,
            response_id,
            employer_id,
            sender_role,
            sent_at,
            LAG(sender_role) OVER (PARTITION BY response_id ORDER BY sent_at, message_id) AS prev_role,
            LAG(sent_at) OVER (PARTITION BY response_id ORDER BY sent_at, message_id) AS prev_sent_at
        FROM msgs_7d
    ),
    employer_replies AS (
        SELECT 
            employer_id,
            response_id,
            sent_at,
            prev_sent_at,
            ROUND((EXTRACT(EPOCH FROM (sent_at - prev_sent_at)) / 3600.0)::numeric, 2) AS reply_time_hours
        FROM dialog_steps
        WHERE sender_role = 'employer' 
          AND prev_role = 'applicant'
    )
    SELECT 
        employer_id,
        COUNT(*) AS replies_count,
        ROUND(AVG(reply_time_hours)::numeric, 2) AS avg_reply_hours,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY reply_time_hours)::numeric, 2) AS p50_reply_hours,
        ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY reply_time_hours)::numeric, 2) AS p90_reply_hours
    FROM employer_replies
    GROUP BY employer_id
    ORDER BY p50_reply_hours ASC, employer_id;

-- Контрольные значения:
-- Общее количество найденных ответов: 749
-- employer_id с минимальной медианой: 107
-- Значение минимальной медианы: 3.93 ч

-- Вывод:
-- 1. Медианное время ответа у всех работодателей держится в районе 4-5 часов 
-- 2. Почти все сообщения получают ответ в пределах суток 13-20 часов
-- 3. Среднее время заметно выше медианы это связано с редкими долгими паузами например, на выходных или ночью


-- ============================================================
-- БЛОК Г
-- ============================================================

-- ЗАДАНИЕ 6.

-- Запрос 6.1:

    WITH employer_calls_7d AS (
        SELECT 
            c.call_id,
            c.status,
            c.call_tags
        FROM calls c
        JOIN responses r ON c.response_id = r.response_id
        WHERE c.caller_role = 'employer'
          AND c.call_at >= r.created_at
          AND c.call_at <= r.created_at + INTERVAL '7 days'
          AND (
              (c.status = 'successful' AND c.call_tags @> ARRAY['connected'] AND NOT c.call_tags && ARRAY['no_answer', 'technical_error'])
              OR (c.status = 'unsuccessful' AND c.call_tags @> ARRAY['no_answer'] AND NOT c.call_tags && ARRAY['connected', 'technical_error'])
              OR (c.status = 'error' AND c.call_tags @> ARRAY['technical_error'] AND NOT c.call_tags && ARRAY['connected', 'no_answer'])
          )
    )
    SELECT 
        COUNT(*) FILTER (WHERE 'screening' = ANY(call_tags)) AS screening,
        COUNT(*) FILTER (WHERE 'interview' = ANY(call_tags)) AS interview,
        COUNT(*) FILTER (WHERE 'follow_up' = ANY(call_tags)) AS follow_up,
        COUNT(*) FILTER (WHERE 'details' = ANY(call_tags)) AS details,
        COUNT(*) FILTER (WHERE call_tags && ARRAY['screening', 'interview', 'follow_up', 'details']) AS valid_calls_with_biz_tag,
        ROUND(AVG(cardinality(call_tags))::numeric, 2) AS avg_tags_per_call
    FROM employer_calls_7d;

-- Контрольные значения 6.1:                                                                                                                        
-- screening: 25                                                                                                                                  
-- interview: 31                                                                                                                                  
-- follow_up: 29                                                                                                                                  
-- details: 23                                                                                                                                    
-- Валидные звонки: 108                                                                                                       
-- Среднее число тегов на звонок: 4.00 

-- Запрос 6.2:

    WITH employer_msgs AS (
        SELECT 
            m.message_id,
            COALESCE(m.message_meta ->> 'channel', 'отсутствует') AS channel,
            m.message_meta ? 'is_read' AS has_is_read,
            (m.message_meta ->> 'is_read')::boolean AS is_read,
            COALESCE(jsonb_array_length(m.message_meta -> 'attachments'), 0) AS attachments_count
        FROM messages m
        JOIN responses r ON m.response_id = r.response_id
        WHERE m.sender_role = 'employer'
          AND m.sent_at >= r.created_at
          AND m.sent_at <= r.created_at + INTERVAL '7 days'
    )
    SELECT 
        channel,
        COUNT(*) AS total_messages,
        COUNT(*) FILTER (WHERE has_is_read AND is_read IS NOT NULL) AS known_read_messages,
        COUNT(*) FILTER (WHERE is_read = false) AS unread_messages,
        ROUND(
            COUNT(*) FILTER (WHERE is_read = false) * 100.0 / 
            NULLIF(COUNT(*) FILTER (WHERE has_is_read AND is_read IS NOT NULL), 0), 
            2
        ) AS unread_share_pct,
        COUNT(*) FILTER (WHERE attachments_count >= 1) AS with_attachments_messages,
        ROUND(
            COUNT(*) FILTER (WHERE attachments_count >= 1) * 100.0 / 
            NULLIF(COUNT(*), 0), 
            2
        ) AS with_attachments_share_pct
    FROM employer_msgs
    GROUP BY channel
    ORDER BY total_messages DESC;

                                                                                                                                                      
-- ДОРАБОТКА.
-- Контрольные значения 6.2 по каналам:
-- web:
--   всего сообщений: 628
--   с известным статусом прочтения: 628
--   непрочитанных: 52
--   доля непрочитанных: 8.28%
--   с вложениями: 25
--   доля с вложениями: 3.98%
-- mobile_app:
--   всего сообщений: 360
--   с известным статусом прочтения: 360
--   непрочитанных: 36
--   доля непрочитанных: 10.00%
--   с вложениями: 14
--   доля с вложениями: 3.89%
-- Группа без указания канала: 0 сообщений (пусто).

-- Вывод:
-- 1. В звонках ошибок нет, технические теги везде сходятся со статусом звонка. По целям всё распределено равномерно.
--    Чаще всего звонят по поводу интервью 31. В каждом звонке ровно 4 тега.
-- 2. Работодатели чаще пишут через сайт, чем через мобильное приложение (628 сообщений против 360).
-- 3. Кандидаты читают почти все сообщения (непрочитанных всего 8-10%).
-- 4. Файлы и вложения прикрепляют редко в обоих каналах (около 4%).

-- ============================================================
-- БЛОК Д
-- ============================================================

-- ЗАДАНИЕ 7

-- Гипотеза 1: 
-- Кандидатам, которых в итоге приглашают, работодатели отвечают быстрее, чем остальным 

-- Гипотеза 2: 
-- По откликам с приглашением общение идет активнее, кандидаты чаще отвечают на сообщения работодателя,
-- а в диалоге накапливается больше сообщений и звонков

-- Запрос:

    WITH employer_events AS (
        SELECT 
            m.response_id,
            m.message_id::text AS event_id,
            m.sent_at AS event_at,
            'message' AS event_type
        FROM messages m
        JOIN responses r ON m.response_id = r.response_id
        WHERE m.sender_role = 'employer'
          AND m.sent_at >= r.created_at
          AND m.sent_at <= r.created_at + INTERVAL '7 days'
        UNION ALL
        SELECT 
            c.response_id,
            c.call_id::text AS event_id,
            c.call_at AS event_at,
            'call' AS event_type
        FROM calls c
        JOIN responses r ON c.response_id = r.response_id
        WHERE c.caller_role = 'employer'
          AND c.call_at >= r.created_at
          AND c.call_at <= r.created_at + INTERVAL '7 days'
          AND c.status != 'error'
    ),
    applicant_msgs AS (
        SELECT 
            m.response_id,
            COUNT(*) AS app_msgs_cnt
        FROM messages m
        JOIN responses r ON m.response_id = r.response_id
        WHERE m.sender_role = 'applicant'
          AND m.sent_at >= r.created_at
          AND m.sent_at <= r.created_at + INTERVAL '7 days'
        GROUP BY m.response_id
    ),
    first_events AS (
        SELECT 
            response_id,
            MIN(event_at) AS first_event_at,
            COUNT(*) AS total_emp_events,
            COUNT(*) FILTER (WHERE event_type = 'message') AS emp_msgs_cnt,
            COUNT(*) FILTER (WHERE event_type = 'call') AS emp_calls_cnt,
            (ARRAY_AGG(event_type ORDER BY event_at, event_type, event_id))[1] AS first_event_type
        FROM employer_events
        GROUP BY response_id
    ),
    resp_features AS (
        SELECT 
            r.response_id,
            CASE WHEN r.status = 'invited' THEN 'Приглашение (invited)' ELSE 'Остальные отклики' END AS status_group,
            fe.first_event_at,
            fe.first_event_type,
            COALESCE(fe.total_emp_events, 0) AS total_emp_events,
            COALESCE(fe.emp_msgs_cnt, 0) AS emp_msgs_cnt,
            COALESCE(fe.emp_calls_cnt, 0) AS emp_calls_cnt,
            COALESCE(am.app_msgs_cnt, 0) AS app_msgs_cnt,
            COALESCE(fe.total_emp_events, 0) + COALESCE(am.app_msgs_cnt, 0) AS total_dialog_events,
            ROUND((EXTRACT(EPOCH FROM (fe.first_event_at - r.created_at)) / 3600.0)::numeric, 2) AS hours_to_first_comm
        FROM responses r
        LEFT JOIN first_events fe ON r.response_id = fe.response_id
        LEFT JOIN applicant_msgs am ON r.response_id = am.response_id
    )
    SELECT 
        status_group,
        COUNT(*) AS total_responses,
        COUNT(*) FILTER (WHERE total_emp_events > 0) AS resp_with_comm,
        ROUND(COUNT(*) FILTER (WHERE total_emp_events > 0) * 100.0 / COUNT(*), 2) AS comm_coverage_pct,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first_comm)::numeric, 2) AS p50_hours_to_first,
        ROUND(COUNT(*) FILTER (WHERE hours_to_first_comm <= 24) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE total_emp_events > 0), 0), 2) AS fast_contact_24h_pct,
        ROUND(COUNT(*) FILTER (WHERE app_msgs_cnt > 0) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE total_emp_events > 0), 0), 2) AS candidate_replied_pct,
        ROUND(AVG(total_dialog_events) FILTER (WHERE total_emp_events > 0), 2) AS avg_dialog_events,
        ROUND(COUNT(*) FILTER (WHERE first_event_type = 'call') * 100.0 / NULLIF(COUNT(*) FILTER (WHERE total_emp_events > 0), 0), 2) AS first_is_call_pct,
        ROUND(COUNT(*) FILTER (WHERE emp_calls_cnt > 0 AND emp_msgs_cnt > 0) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE total_emp_events > 0), 0), 2) AS multichannel_pct
    FROM resp_features
    GROUP BY status_group
    ORDER BY total_responses ASC;


-- Результаты проверки гипотез:
-- Гипотеза 1: Не подтверждается.
-- Разницы по скорости почти нет, получилось что медиана первого ответа 51.1 ч у приглашенных против 54.7 ч у остальных, разница всего 3.5 часа. 
-- В первые сутки компании отвечают одинаково.

-- Гипотеза 2: Не подтверждается.
-- Общаются везде одинаково активно, кандидаты отвечают в чате в 87% и 91% случаев, переписка по длине совпадает, а      
-- начинают со звонка одинаково редко.

-- Вывод:
-- Получение приглашения почти никак не связано со скоростью первого ответа или длиной переписки в первую неделю. 
-- Компании общаются по одинаковым сценариям со всеми соискателями, а кандидаты охотно отвечают в чате независимо от того, закончится отклик приглашением или отказом.


-- ЗАДАНИЕ 8. 

-- Итог исследования:
-- За первые 7 дней после отклика работодатели отвечают только на 60.8% резюме, а остальные кандидаты остаются вовсе без внимания.
-- В основном компании общаются через переписку и отправили 988 сообщений, а звонят редко и совершили всего 107 звонков.
-- В самом чате работодатели отвечают довольно быстро, где медиана времени ответа составляет около 4 часов, а у самого оперативного работодателя 107 она равна 3.93 часа.
-- Между профессиями виден большой контраст, потому что тестировщиков зовут на интервью чаще всех с конверсией до 41.2%, а у дата-инженеров эта конверсия составляет около 10%.
-- По скорости первого контакта тоже есть сильная разница, так как самые быстрые компании выходят на связь уже через 6 часов, а остальные затягивают ответ на 2 или 3 дня.
-- Само по себе приглашение почти не зависит от скорости связи, так как медиана времени первого контакта у приглашенных составляет 51.1 часа против 54.7 часа у всех остальных.
-- Соискатели охотно отвечают в чате независимо от исхода отбора, поэтому активность диалога тоже никак не намекает на будущее приглашение.
-- Главное ограничение нашего анализа заключается в том, что мы оценивали только первые 7 дней и не анализировали текст сообщений вроде тестовых заданий или причин отказа.
-- В качестве следующего шага продуктовой команде стоит узнать, кто после приглашения реально доходит до оффера, и проверить влияние зарплаты на скорость ответов работодателей.
