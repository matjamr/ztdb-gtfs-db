-- ============================================================
-- QUERY 1: Find all routes serving a specific stop on a specific date
-- ============================================================
WITH params AS (
    SELECT
        '2025-11-09'::DATE AS travel_date,
        EXTRACT(DOW FROM '2025-11-09'::DATE) AS day_of_week
)
SELECT DISTINCT
    s.stop_name,
    s.stop_id,
    r.route_short_name AS route_number,
    r.route_long_name AS route_name,
    p.day_of_week,
    COUNT(DISTINCT t.trip_id) AS number_of_trips
FROM params p
         CROSS JOIN stops s
         JOIN stop_times st ON s.stop_id = st.stop_id
         JOIN trips t ON st.trip_id = t.trip_id
         JOIN routes r ON t.route_id = r.route_id
         JOIN calendar c ON t.service_id = c.service_id
WHERE s.stop_name ILIKE 'PKP Rakowiec'
  AND p.travel_date >= c.start_date
  AND p.travel_date <= c.end_date
  -- Check if service operates on this day of week
  AND (
    (p.day_of_week = 0 AND c.sunday = 1) OR
    (p.day_of_week = 1 AND c.monday = 1) OR
    (p.day_of_week = 2 AND c.tuesday = 1) OR
    (p.day_of_week = 3 AND c.wednesday = 1) OR
    (p.day_of_week = 4 AND c.thursday = 1) OR
    (p.day_of_week = 5 AND c.friday = 1) OR
    (p.day_of_week = 6 AND c.saturday = 1)
    )
GROUP BY s.stop_name, s.stop_id, r.route_short_name, r.route_long_name, p.day_of_week
ORDER BY r.route_short_name
LIMIT 500;

-- ============================================================
-- QUERY 2: Find routes with departure times for a specific stop on a given date
-- ============================================================

WITH params AS (
    SELECT
        '2025-11-09'::DATE AS travel_date,
        EXTRACT(DOW FROM '2025-11-09'::DATE) AS day_of_week
)
SELECT
    s.stop_name,
    r.route_short_name AS route_number,
    st.departure_time,
    st.arrival_time,
    t.trip_id
FROM params p
         CROSS JOIN stops s
         JOIN stop_times st ON s.stop_id = st.stop_id
         JOIN trips t ON st.trip_id = t.trip_id
         JOIN routes r ON t.route_id = r.route_id
         JOIN calendar c ON t.service_id = c.service_id
WHERE s.stop_name ILIKE 'Rakowiec'
  AND p.travel_date >= c.start_date
  AND p.travel_date <= c.end_date
  AND (
    (p.day_of_week = 0 AND c.sunday = 1) OR
    (p.day_of_week = 1 AND c.monday = 1) OR
    (p.day_of_week = 2 AND c.tuesday = 1) OR
    (p.day_of_week = 3 AND c.wednesday = 1) OR
    (p.day_of_week = 4 AND c.thursday = 1) OR
    (p.day_of_week = 5 AND c.friday = 1) OR
    (p.day_of_week = 6 AND c.saturday = 1)
    )
ORDER BY st.departure_time
LIMIT 500;


-- ============================================================
-- QUERY 3: Direct trip from A to B (no transfers - same vehicle)
-- ============================================================

CREATE OR REPLACE FUNCTION time_to_minutes(time_str TEXT)
    RETURNS INTEGER AS $$
DECLARE
    parts TEXT[];
    hours INTEGER;
    minutes INTEGER;
BEGIN
    parts := string_to_array(time_str, ':');
    hours := parts[1]::INTEGER;
    minutes := parts[2]::INTEGER;
    RETURN hours * 60 + minutes;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Main query for direct connections
SELECT
    start_stop.stop_name AS from_stop,
    end_stop.stop_name AS to_stop,
    r.route_short_name AS route_number,
    r.route_long_name AS route_name,
    t.trip_id,
    st1.departure_time,
    st2.arrival_time,
    (st2.stop_sequence - st1.stop_sequence) AS stops_between,
    (time_to_minutes(st2.arrival_time) - time_to_minutes(st1.departure_time)) AS travel_time_minutes
FROM stops start_stop
         JOIN stop_times st1 ON start_stop.stop_id = st1.stop_id
         JOIN trips t ON st1.trip_id = t.trip_id
         JOIN stop_times st2 ON t.trip_id = st2.trip_id
         JOIN stops end_stop ON st2.stop_id = end_stop.stop_id
         JOIN routes r ON t.route_id = r.route_id
WHERE start_stop.stop_name ILIKE '%PKP Rakowiec%'
  AND end_stop.stop_name ILIKE '%Wawelska%'
  AND st1.departure_time >= '08:00:00'
  AND st1.departure_time <= '18:00:00'
  AND st1.stop_sequence < st2.stop_sequence
  AND st2.stop_sequence - st1.stop_sequence <= 30
ORDER BY st1.departure_time
LIMIT 100;


-- ============================================================
-- QUERY 4: One transfer route from A to B
-- ============================================================

-- STEP 1: First check what columns your nearby_stops table has
-- Run this to see the structure:
-- \d nearby_stops

-- STEP 2: Create nearby_stops table with correct column names
DROP TABLE IF EXISTS nearby_stops;

CREATE TABLE nearby_stops AS
SELECT
    s1.stop_id AS stop_id_from,
    s2.stop_id AS stop_id_to,
    s1.stop_name AS stop_name_from,
    s2.stop_name AS stop_name_to,
    ROUND(
            111319.9 * SQRT(
                    POW(s1.stop_lat - s2.stop_lat, 2) +
                    POW((s1.stop_lon - s2.stop_lon) * COS(RADIANS((s1.stop_lat + s2.stop_lat) / 2)), 2)
                       )
    )::INTEGER AS distance_meters
FROM stops s1
         CROSS JOIN stops s2
WHERE s1.stop_id < s2.stop_id  -- Avoid duplicates and self-references
  AND ROUND(
              111319.9 * SQRT(
                      POW(s1.stop_lat - s2.stop_lat, 2) +
                      POW((s1.stop_lon - s2.stop_lon) * COS(RADIANS((s1.stop_lat + s2.stop_lat) / 2)), 2)
                         )
      ) <= 500;  -- Within 500 meters

-- Create indexes for performance
CREATE INDEX idx_nearby_stops_from ON nearby_stops(stop_id_from);
CREATE INDEX idx_nearby_stops_to ON nearby_stops(stop_id_to);
CREATE INDEX idx_nearby_stops_distance ON nearby_stops(distance_meters);

-- STEP 3: Main query for one-transfer connections (CORRECTED VERSION)
SELECT
    start_stop.stop_name AS from_stop,
    transfer_stop1.stop_name AS arrive_at_stop,
    transfer_stop2.stop_name AS depart_from_stop,
    COALESCE(ns1.distance_meters, ns2.distance_meters) AS walking_distance_meters,
    end_stop.stop_name AS to_stop,
    r1.route_short_name AS first_route,
    r2.route_short_name AS second_route,
    st1.departure_time AS depart_from_start,
    st2.arrival_time AS arrive_at_transfer,
    st3.departure_time AS depart_from_transfer,
    st4.arrival_time AS arrive_at_destination,
    (time_to_minutes(st3.departure_time) - time_to_minutes(st2.arrival_time)) AS transfer_wait_minutes,
    (time_to_minutes(st4.arrival_time) - time_to_minutes(st1.departure_time)) AS total_travel_time_minutes
FROM stops start_stop
-- First leg
         JOIN stop_times st1 ON start_stop.stop_id = st1.stop_id
         JOIN trips t1 ON st1.trip_id = t1.trip_id
         JOIN stop_times st2 ON t1.trip_id = st2.trip_id
         JOIN stops transfer_stop1 ON st2.stop_id = transfer_stop1.stop_id
-- Transfer (nearby stops) - handle both directions
         LEFT JOIN nearby_stops ns1 ON ns1.stop_id_from = transfer_stop1.stop_id
         LEFT JOIN nearby_stops ns2 ON ns2.stop_id_to = transfer_stop1.stop_id
         JOIN stops transfer_stop2 ON (
    transfer_stop2.stop_id = COALESCE(ns1.stop_id_to, ns2.stop_id_from)
    )
-- Second leg
         JOIN stop_times st3 ON transfer_stop2.stop_id = st3.stop_id
         JOIN trips t2 ON st3.trip_id = t2.trip_id
         JOIN stop_times st4 ON t2.trip_id = st4.trip_id
         JOIN stops end_stop ON st4.stop_id = end_stop.stop_id
-- Routes
         JOIN routes r1 ON t1.route_id = r1.route_id
         JOIN routes r2 ON t2.route_id = r2.route_id
WHERE start_stop.stop_name ILIKE '%PKP Rakowiec%'
  AND end_stop.stop_name ILIKE '%PKP Włochy%'
  AND st1.departure_time >= '08:00:00'
  AND st1.departure_time <= '10:00:00'
  -- First leg constraints
  AND st1.stop_sequence < st2.stop_sequence
  AND st2.stop_sequence - st1.stop_sequence <= 20
  -- Second leg constraints
  AND st3.stop_sequence < st4.stop_sequence
  AND st4.stop_sequence - st3.stop_sequence <= 20
  -- Different trips
  AND t1.trip_id <> t2.trip_id
  -- Transfer exists
  AND (ns1.stop_id_from IS NOT NULL OR ns2.stop_id_to IS NOT NULL)
  -- Transfer time constraints
  AND st2.arrival_time < st3.departure_time
  AND COALESCE(ns1.distance_meters, ns2.distance_meters) <= 200
  AND (time_to_minutes(st3.departure_time) - time_to_minutes(st2.arrival_time)) <= 15
ORDER BY st1.departure_time, total_travel_time_minutes
LIMIT 200;


-- ============================================================
-- ALTERNATIVE: Simpler one-transfer query (same stop transfer only)
-- This is faster and doesn't require nearby_stops table
-- ============================================================

SELECT
    start_stop.stop_name AS from_stop,
    transfer_stop.stop_name AS transfer_at_stop,
    end_stop.stop_name AS to_stop,
    r1.route_short_name AS first_route,
    r2.route_short_name AS second_route,
    st1.departure_time AS depart_from_start,
    st2.arrival_time AS arrive_at_transfer,
    st3.departure_time AS depart_from_transfer,
    st4.arrival_time AS arrive_at_destination,
    (time_to_minutes(st3.departure_time) - time_to_minutes(st2.arrival_time)) AS transfer_wait_minutes,
    (time_to_minutes(st4.arrival_time) - time_to_minutes(st1.departure_time)) AS total_travel_time_minutes
FROM stops start_stop
-- First leg
         JOIN stop_times st1 ON start_stop.stop_id = st1.stop_id
         JOIN trips t1 ON st1.trip_id = t1.trip_id
         JOIN stop_times st2 ON t1.trip_id = st2.trip_id
         JOIN stops transfer_stop ON st2.stop_id = transfer_stop.stop_id
-- Second leg (same transfer stop)
         JOIN stop_times st3 ON transfer_stop.stop_id = st3.stop_id
         JOIN trips t2 ON st3.trip_id = t2.trip_id
         JOIN stop_times st4 ON t2.trip_id = st4.trip_id
         JOIN stops end_stop ON st4.stop_id = end_stop.stop_id
-- Routes
         JOIN routes r1 ON t1.route_id = r1.route_id
         JOIN routes r2 ON t2.route_id = r2.route_id
WHERE start_stop.stop_name ILIKE '%PKP Rakowiec%'
  AND end_stop.stop_name ILIKE '%PKP Włochy%'
  AND st1.departure_time >= '08:00:00'
  AND st1.departure_time <= '10:00:00'
  -- First leg constraints
  AND st1.stop_sequence < st2.stop_sequence
  AND st2.stop_sequence - st1.stop_sequence <= 20
  -- Second leg constraints
  AND st3.stop_sequence < st4.stop_sequence
  AND st4.stop_sequence - st3.stop_sequence <= 20
  -- Different trips
  AND t1.trip_id <> t2.trip_id
  -- Transfer time constraints
  AND st2.arrival_time < st3.departure_time
  AND (time_to_minutes(st3.departure_time) - time_to_minutes(st2.arrival_time)) BETWEEN 2 AND 15
ORDER BY st1.departure_time, total_travel_time_minutes
LIMIT 200;


-- ============================================================
-- UTILITY QUERIES
-- ============================================================

-- Check nearby stops for a specific location
SELECT
    stop_name_from,
    stop_name_to,
    distance_meters
FROM nearby_stops
WHERE stop_name_from ILIKE '%PKP Rakowiec%'
   OR stop_name_to ILIKE '%PKP Rakowiec%'
ORDER BY distance_meters
LIMIT 20;

-- Count nearby stops
SELECT COUNT(*) as nearby_stop_pairs
FROM nearby_stops;

-- Find stops within walking distance of a specific stop
SELECT
    s2.stop_name,
    ROUND(
            111319.9 * SQRT(
                    POW(s1.stop_lat - s2.stop_lat, 2) +
                    POW((s1.stop_lon - s2.stop_lon) * COS(RADIANS((s1.stop_lat + s2.stop_lat) / 2)), 2)
                       )
    )::INTEGER AS distance_meters
FROM stops s1
         CROSS JOIN stops s2
WHERE s1.stop_name ILIKE '%PKP Rakowiec%'
  AND s1.stop_id <> s2.stop_id
  AND ROUND(
              111319.9 * SQRT(
                      POW(s1.stop_lat - s2.stop_lat, 2) +
                      POW((s1.stop_lon - s2.stop_lon) * COS(RADIANS((s1.stop_lat + s2.stop_lat) / 2)), 2)
                         )
      ) <= 300
ORDER BY distance_meters
LIMIT 20;

-- ============================================================
-- QUERY 5: Discover all routes with their trip counts
-- ============================================================
SELECT
    r.route_short_name AS route_number,
    CASE r.route_type
        WHEN 0 THEN 'Tram'
        WHEN 1 THEN 'Subway'
        WHEN 2 THEN 'Rail'
        WHEN 3 THEN 'Bus'
        WHEN 4 THEN 'Ferry'
        ELSE 'Other'
    END AS vehicle_type,
    COUNT(DISTINCT t.trip_id) AS total_trips
FROM routes r
         LEFT JOIN trips t ON r.route_id = t.route_id
GROUP BY r.route_short_name, r.route_type
ORDER BY total_trips DESC
LIMIT 100;

-- ============================================================
-- QUERY 6: Find the busiest stops (most trips per day)
SELECT
    s.stop_name,
    s.stop_lat AS latitude,
    s.stop_lon AS longitude,
    COUNT(DISTINCT t.trip_id) AS trips_per_day
FROM stops s
         JOIN stop_times st ON s.stop_id = st.stop_id
         JOIN trips t ON st.trip_id = t.trip_id
GROUP BY s.stop_id, s.stop_name, s.stop_lat, s.stop_lon
HAVING COUNT(DISTINCT t.trip_id) > 50
ORDER BY trips_per_day DESC
LIMIT 20;

-- ============================================================
-- QUERY 7: Show frequency pattern for a stop
SELECT
    (SUBSTRING(st.departure_time, 1, 2))::INTEGER AS hour,
    COUNT(*) AS departures,
    CASE
        WHEN COUNT(*) >= 600 THEN '🔥🔥🔥 Very frequent'
        WHEN COUNT(*) >= 400 THEN '🔥🔥 Frequent'
        WHEN COUNT(*) >= 100 THEN '🔥 Regular'
        ELSE '⏰ Limited'
    END AS frequency
FROM stops s
         JOIN stop_times st ON s.stop_id = st.stop_id
WHERE s.stop_name ILIKE '%PKP Rakowiec%'
  AND (SUBSTRING(st.departure_time, 1, 2))::INTEGER >= 6
  AND (SUBSTRING(st.departure_time, 1, 2))::INTEGER <= 29  -- Allow up to 29:59 (5:59 AM next day)
GROUP BY (SUBSTRING(st.departure_time, 1, 2))::INTEGER
ORDER BY hour;


-- ============================================================
-- QUERY 8: Find transfer hubs (stops with many nearby connections)
SELECT
    s.stop_name AS hub_name,
    COUNT(ns.stop_id_to) + COUNT(ns2.stop_id_from) AS connected_stops,
    COALESCE(
        ROUND(AVG(COALESCE(ns.distance_meters, ns2.distance_meters))),
        ROUND(AVG(ns.distance_meters))
    ) AS avg_distance_meters,
    CASE
        WHEN (COUNT(ns.stop_id_to) + COUNT(ns2.stop_id_from)) >= 20 THEN '⭐⭐⭐ Major hub'
        WHEN (COUNT(ns.stop_id_to) + COUNT(ns2.stop_id_from)) >= 10 THEN '⭐⭐ Important hub'
        ELSE '⭐ Transfer point'
    END AS importance
FROM stops s
         LEFT JOIN nearby_stops ns ON s.stop_id = ns.stop_id_from
         LEFT JOIN nearby_stops ns2 ON s.stop_id = ns2.stop_id_to
GROUP BY s.stop_id, s.stop_name
HAVING (COUNT(ns.stop_id_to) + COUNT(ns2.stop_id_from)) > 5
ORDER BY connected_stops DESC
LIMIT 100;

-- ============================================================
-- QUERY 9: Find longest single-trip journeys (distinct by route)
WITH trip_stats AS (
    SELECT
        t.trip_id,
        t.route_id,
        COUNT(st.stop_sequence) AS total_stops,
        MIN(time_to_minutes(st.departure_time)) AS first_time_minutes,
        MAX(time_to_minutes(st.arrival_time)) AS last_time_minutes
    FROM trips t
             JOIN stop_times st ON t.trip_id = st.trip_id
    GROUP BY t.trip_id, t.route_id
    HAVING COUNT(st.stop_sequence) > 20
)
SELECT
    r.route_short_name AS route,
    MAX(ts.total_stops) AS number_of_stops,
    MAX(ts.last_time_minutes - ts.first_time_minutes) AS duration_minutes
FROM trip_stats ts
         JOIN routes r ON ts.route_id = r.route_id
GROUP BY r.route_short_name
ORDER BY number_of_stops DESC
LIMIT 10;