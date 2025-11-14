-- ============================================
-- PostgreSQL Queries Converted from Neo4j Cypher
-- READY TO RUN - Just copy and paste into psql
-- ============================================

-- ============================================
-- QUERY 1: Find all routes serving a specific stop on a specific date
-- Neo4j equivalent: Find routes at PKP Rakowiec on 2025-11-09
-- ============================================

-- Basic version (change the stop name and date as needed)
WITH date_params AS (
    SELECT
        '2025-11-09'::DATE AS travel_date,
            TO_CHAR('2025-11-09'::DATE, 'YYYYMMDD') AS travel_date_yyyymmdd,
        EXTRACT(DOW FROM '2025-11-09'::DATE) AS day_of_week
)
SELECT DISTINCT
    s.name AS stop_name,
    s.id AS stop_id,
    r.short_name AS route_number,
    r.long_name AS route_name,
    dp.day_of_week,
    COUNT(DISTINCT t.id) AS number_of_trips
FROM stops s
         JOIN stoptimes st ON s.id = st.stop_id
         JOIN trips t ON st.trip_id = t.id
         JOIN routes r ON t.route_id = r.id
         JOIN calendars c ON t.calendar_id = c.id
         CROSS JOIN date_params dp
WHERE s.name LIKE '%PKP Rakowiec%'
  AND dp.travel_date_yyyymmdd >= c.start_date
  AND dp.travel_date_yyyymmdd <= c.end_date
GROUP BY s.name, s.id, r.short_name, r.long_name, dp.day_of_week
ORDER BY r.short_name
    LIMIT 500;


-- ============================================
-- QUERY 2: Find routes with departure times for a specific stop on a given date
-- Neo4j equivalent: Get all departures from PKP Rakowiec on 2025-11-09
-- ============================================

WITH date_params AS (
    SELECT
        '2025-11-09'::DATE AS travel_date,
            TO_CHAR('2025-11-09'::DATE, 'YYYYMMDD') AS travel_date_yyyymmdd,
        EXTRACT(DOW FROM '2025-11-09'::DATE) AS day_of_week
)
SELECT
    s.name AS stop_name,
    r.short_name AS route_number,
    st.departure_time,
    st.arrival_time,
    t.id AS trip_id
FROM stops s
         JOIN stoptimes st ON s.id = st.stop_id
         JOIN trips t ON st.trip_id = t.id
         JOIN routes r ON t.route_id = r.id
         JOIN calendars c ON t.calendar_id = c.id
         CROSS JOIN date_params dp
WHERE s.name LIKE '%PKP Rakowiec%'
  AND dp.travel_date_yyyymmdd >= c.start_date
  AND dp.travel_date_yyyymmdd <= c.end_date
ORDER BY st.departure_time_int
    LIMIT 500;


-- ============================================
-- QUERY 3: Direct trip from A to B (no transfers - same vehicle)
-- Neo4j equivalent: [:PRECEDES*1..30] path traversal
-- ============================================

-- METHOD 1: Simple JOIN approach (faster, recommended)
SELECT
    start.name AS from_stop,
    end_stop.name AS to_stop,
    r.short_name AS route_number,
    r.long_name AS route_name,
    t.id AS trip_id,
    st1.departure_time,
    st2.arrival_time,
    (st2.stop_sequence - st1.stop_sequence) AS stops_between,
    (st2.arrival_time_int - st1.departure_time_int) AS travel_time_minutes
FROM stops start
         JOIN stoptimes st1 ON start.id = st1.stop_id
         JOIN trips t ON st1.trip_id = t.id
         JOIN routes r ON t.route_id = r.id
         JOIN stoptimes st2 ON t.id = st2.trip_id
         JOIN stops end_stop ON st2.stop_id = end_stop.id
WHERE start.name LIKE '%PKP Rakowiec%'
  AND end_stop.name LIKE '%Wawelska%'
  AND st1.departure_time >= '08:00:00'
  AND st1.departure_time <= '18:00:00'
  AND st1.stop_sequence < st2.stop_sequence
  AND st2.stop_sequence - st1.stop_sequence <= 30
ORDER BY st1.departure_time_int
    LIMIT 100;


-- METHOD 2: Using Recursive CTE (more Neo4j-like, follows PRECEDES relationships)
WITH RECURSIVE stop_path AS (
    -- Base case: starting stoptimes at PKP Rakowiec
    SELECT
        st1.id AS start_stoptime_id,
        st1.stop_id AS start_stop_id,
        st1.trip_id,
        st1.stop_sequence AS start_sequence,
        st1.departure_time,
        st1.departure_time_int,
        st1.id AS current_stoptime_id,
        st1.stop_id AS current_stop_id,
        st1.stop_sequence AS current_sequence,
        st1.arrival_time AS current_arrival,
        st1.arrival_time_int AS current_arrival_int,
        0 AS depth
    FROM stoptimes st1
             JOIN stops start ON st1.stop_id = start.id
    WHERE start.name LIKE '%PKP Rakowiec%'
      AND st1.departure_time >= '08:00:00'
      AND st1.departure_time <= '18:00:00'

    UNION ALL

    -- Recursive case: follow PRECEDES to next stops
    SELECT
        sp.start_stoptime_id,
        sp.start_stop_id,
        sp.trip_id,
        sp.start_sequence,
        sp.departure_time,
        sp.departure_time_int,
        st.id,
        st.stop_id,
        st.stop_sequence,
        st.arrival_time,
        st.arrival_time_int,
        sp.depth + 1
    FROM stop_path sp
             JOIN stoptimes st ON sp.trip_id = st.trip_id
        AND st.stop_sequence = sp.current_sequence + 1
    WHERE sp.depth < 30
)
SELECT
    start.name AS from_stop,
    end_stop.name AS to_stop,
    r.short_name AS route_number,
    r.long_name AS route_name,
    t.id AS trip_id,
    sp.departure_time,
    sp.current_arrival AS arrival_time,
    (sp.current_sequence - sp.start_sequence) AS stops_between,
    (sp.current_arrival_int - sp.departure_time_int) AS travel_time_minutes
FROM stop_path sp
         JOIN stops start ON sp.start_stop_id = start.id
         JOIN stops end_stop ON sp.current_stop_id = end_stop.id
         JOIN trips t ON sp.trip_id = t.id
         JOIN routes r ON t.route_id = r.id
WHERE end_stop.name LIKE '%Wawelska%'
  AND sp.current_sequence > sp.start_sequence
ORDER BY sp.departure_time_int
    LIMIT 100;


-- ============================================
-- QUERY 4: Trip with 1 transfer
-- Neo4j equivalent: Two [:PRECEDES*] paths connected by [:NEARBY_STOPS]
-- ============================================

-- METHOD 1: Simple JOIN approach (faster, recommended)
SELECT
    start.name AS from_stop,
    transfer1.name AS arrive_at_stop,
    transfer2.name AS depart_from_stop,
    ns.distance AS walking_distance_meters,
    end_stop.name AS to_stop,
    r1.short_name AS first_route,
    r2.short_name AS second_route,
    st1.departure_time AS depart_from_start,
    st2.arrival_time AS arrive_at_transfer,
    st3.departure_time AS depart_from_transfer,
    st4.arrival_time AS arrive_at_destination,
    (
        ((st3.departure_time_int / 100) * 60 + (st3.departure_time_int % 100)) -
        ((st2.arrival_time_int / 100) * 60 + (st2.arrival_time_int % 100))
        ) AS transfer_wait_minutes
FROM stops start
-- First leg: start -> transfer point 1
         JOIN stoptimes st1 ON start.id = st1.stop_id
         JOIN trips t1 ON st1.trip_id = t1.id
         JOIN routes r1 ON t1.route_id = r1.id
         JOIN stoptimes st2 ON t1.id = st2.trip_id
         JOIN stops transfer1 ON st2.stop_id = transfer1.id
-- Transfer: walk from transfer1 to transfer2
         JOIN nearby_stops ns ON transfer1.id = ns.from_stop_id
         JOIN stops transfer2 ON ns.to_stop_id = transfer2.id
-- Second leg: transfer point 2 -> end
         JOIN stoptimes st3 ON transfer2.id = st3.stop_id
         JOIN trips t2 ON st3.trip_id = t2.id
         JOIN routes r2 ON t2.route_id = r2.id
         JOIN stoptimes st4 ON t2.id = st4.trip_id
         JOIN stops end_stop ON st4.stop_id = end_stop.id
WHERE start.name LIKE '%PKP Rakowiec%'
  AND end_stop.name LIKE '%PKP Włochy%'
  AND st1.departure_time >= '08:00:00'
  AND st1.departure_time <= '10:00:00'
  -- First leg constraints
  AND st1.stop_sequence < st2.stop_sequence
  AND st2.stop_sequence - st1.stop_sequence <= 20
  -- Second leg constraints
  AND st3.stop_sequence < st4.stop_sequence
  AND st4.stop_sequence - st3.stop_sequence <= 20
  -- Transfer constraints
  AND t1.id <> t2.id
  AND ns.distance <= 200
  AND st2.arrival_time < st3.departure_time
  AND (
          ((st3.departure_time_int / 100) * 60 + (st3.departure_time_int % 100)) -
          ((st2.arrival_time_int / 100) * 60 + (st2.arrival_time_int % 100))
          ) <= 15
ORDER BY st1.departure_time_int
    LIMIT 200;


-- METHOD 2: Using Recursive CTEs (more Neo4j-like)
WITH RECURSIVE
-- First leg path
first_leg AS (
    SELECT
        st1.id AS start_stoptime_id,
        st1.stop_id AS start_stop_id,
        st1.trip_id,
        st1.stop_sequence AS start_sequence,
        st1.departure_time,
        st1.departure_time_int,
        st1.id AS current_stoptime_id,
        st1.stop_id AS current_stop_id,
        st1.stop_sequence AS current_sequence,
        st1.arrival_time AS current_arrival,
        st1.arrival_time_int AS current_arrival_int,
        0 AS depth
    FROM stoptimes st1
             JOIN stops start ON st1.stop_id = start.id
    WHERE start.name LIKE '%PKP Rakowiec%'
      AND st1.departure_time >= '08:00:00'
      AND st1.departure_time <= '10:00:00'

    UNION ALL

    SELECT
        fl.start_stoptime_id,
        fl.start_stop_id,
        fl.trip_id,
        fl.start_sequence,
        fl.departure_time,
        fl.departure_time_int,
        st.id,
        st.stop_id,
        st.stop_sequence,
        st.arrival_time,
        st.arrival_time_int,
        fl.depth + 1
    FROM first_leg fl
             JOIN stoptimes st ON fl.trip_id = st.trip_id
        AND st.stop_sequence = fl.current_sequence + 1
    WHERE fl.depth < 20
),
-- Second leg path
second_leg AS (
    SELECT
        st3.id AS start_stoptime_id,
        st3.stop_id AS start_stop_id,
        st3.trip_id,
        st3.stop_sequence AS start_sequence,
        st3.departure_time,
        st3.departure_time_int,
        st3.id AS current_stoptime_id,
        st3.stop_id AS current_stop_id,
        st3.stop_sequence AS current_sequence,
        st3.arrival_time AS current_arrival,
        st3.arrival_time_int AS current_arrival_int,
        0 AS depth
    FROM stoptimes st3

    UNION ALL

    SELECT
        sl.start_stoptime_id,
        sl.start_stop_id,
        sl.trip_id,
        sl.start_sequence,
        sl.departure_time,
        sl.departure_time_int,
        st.id,
        st.stop_id,
        st.stop_sequence,
        st.arrival_time,
        st.arrival_time_int,
        sl.depth + 1
    FROM second_leg sl
             JOIN stoptimes st ON sl.trip_id = st.trip_id
        AND st.stop_sequence = sl.current_sequence + 1
    WHERE sl.depth < 20
)
SELECT
    start.name AS from_stop,
    transfer1.name AS arrive_at_stop,
    transfer2.name AS depart_from_stop,
    ns.distance AS walking_distance_meters,
    end_stop.name AS to_stop,
    r1.short_name AS first_route,
    r2.short_name AS second_route,
    fl.departure_time AS depart_from_start,
    fl.current_arrival AS arrive_at_transfer,
    sl.departure_time AS depart_from_transfer,
    sl.current_arrival AS arrive_at_destination,
    (
        ((sl.departure_time_int / 100) * 60 + (sl.departure_time_int % 100)) -
        ((fl.current_arrival_int / 100) * 60 + (fl.current_arrival_int % 100))
        ) AS transfer_wait_minutes
FROM first_leg fl
         JOIN stops start ON fl.start_stop_id = start.id
         JOIN stops transfer1 ON fl.current_stop_id = transfer1.id
         JOIN nearby_stops ns ON transfer1.id = ns.from_stop_id
         JOIN stops transfer2 ON ns.to_stop_id = transfer2.id
         JOIN second_leg sl ON transfer2.id = sl.start_stop_id
         JOIN stops end_stop ON sl.current_stop_id = end_stop.id
         JOIN trips t1 ON fl.trip_id = t1.id
         JOIN routes r1 ON t1.route_id = r1.id
         JOIN trips t2 ON sl.trip_id = t2.id
         JOIN routes r2 ON t2.route_id = r2.id
WHERE end_stop.name LIKE '%PKP Włochy%'
  AND fl.depth > 0
  AND sl.depth > 0
  AND t1.id <> t2.id
  AND ns.distance <= 200
  AND fl.current_arrival < sl.departure_time
  AND (
          ((sl.departure_time_int / 100) * 60 + (sl.departure_time_int % 100)) -
          ((fl.current_arrival_int / 100) * 60 + (fl.current_arrival_int % 100))
          ) <= 15
ORDER BY fl.departure_time_int
    LIMIT 200;