-- load_gtfs.sql - Script to load GTFS data into PostgreSQL
-- Run this inside the container after copying GTFS files

-- Clear existing data
TRUNCATE TABLE stop_times CASCADE;
TRUNCATE TABLE nearby_stops CASCADE;
TRUNCATE TABLE trips CASCADE;
TRUNCATE TABLE calendar_dates CASCADE;
TRUNCATE TABLE calendar CASCADE;
TRUNCATE TABLE routes CASCADE;
TRUNCATE TABLE stops CASCADE;
TRUNCATE TABLE agency CASCADE;
TRUNCATE TABLE shapes CASCADE;
TRUNCATE TABLE feed_info CASCADE;

-- Load agency
COPY agency(agency_id, agency_name, agency_url, agency_timezone, agency_phone, agency_lang)
    FROM '/import/gtfs/agency.txt'
    DELIMITER ','
    CSV HEADER;

-- Load feed_info
COPY feed_info(feed_publisher_name, feed_publisher_url, feed_lang, feed_start_date, feed_end_date, feed_contact_email, feed_version)
    FROM '/import/gtfs/feed_info.txt'
    DELIMITER ','
    CSV HEADER;

-- Load routes
COPY routes(route_id, agency_id, route_short_name, route_long_name, route_desc, route_type)
    FROM '/import/gtfs/routes.txt'
    DELIMITER ','
    CSV HEADER;

-- Load stops
COPY stops(stop_id, stop_code, stop_name, stop_lat, stop_lon)
    FROM '/import/gtfs/stops.txt'
    DELIMITER ','
    CSV HEADER;

-- Load calendar
COPY calendar(service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date)
    FROM '/import/gtfs/calendar.txt'
    DELIMITER ','
    CSV HEADER;

-- Load calendar_dates (handle potential file name variations)
COPY calendar_dates(service_id, date, exception_type)
    FROM '/import/gtfs/calendar_dates.txt'
    DELIMITER ','
    CSV HEADER;

-- Load shapes
COPY shapes(shape_id, shape_pt_lat, shape_pt_lon, shape_pt_sequence)
    FROM '/import/gtfs/shapes.txt'
    DELIMITER ','
    CSV HEADER;

-- Load trips
COPY trips(route_id, service_id, trip_id, trip_headsign, direction_id, shape_id)
    FROM '/import/gtfs/trips.txt'
    DELIMITER ','
    CSV HEADER;

-- Load stop_times
COPY stop_times(trip_id, arrival_time, departure_time, stop_id, stop_sequence, stop_headsign, pickup_type, drop_off_type, shape_dist_traveled, timepoint)
    FROM '/import/gtfs/stop_times.txt'
    DELIMITER ','
    CSV HEADER;

-- Update time integer fields for faster queries
UPDATE stop_times
SET arrival_time_int = time_to_int(arrival_time),
    departure_time_int = time_to_int(departure_time);

-- Create nearby stops relationships (stops within 200 meters)
INSERT INTO nearby_stops (stop_id_from, stop_id_to, distance_meters)
SELECT
    s1.stop_id,
    s2.stop_id,
    calculate_distance(s1.stop_lat, s1.stop_lon, s2.stop_lat, s2.stop_lon) as distance
FROM stops s1
         CROSS JOIN stops s2
WHERE s1.stop_id <> s2.stop_id
  AND s1.stop_lat IS NOT NULL
  AND s1.stop_lon IS NOT NULL
  AND s2.stop_lat IS NOT NULL
  AND s2.stop_lon IS NOT NULL
  AND calculate_distance(s1.stop_lat, s1.stop_lon, s2.stop_lat, s2.stop_lon) <= 200;

-- Analyze tables for query optimization
ANALYZE agency;
ANALYZE routes;
ANALYZE stops;
ANALYZE calendar;
ANALYZE calendar_dates;
ANALYZE trips;
ANALYZE stop_times;
ANALYZE nearby_stops;

-- Show loading statistics
SELECT 'agency' as table_name, COUNT(*) as row_count FROM agency
UNION ALL
SELECT 'routes', COUNT(*) FROM routes
UNION ALL
SELECT 'stops', COUNT(*) FROM stops
UNION ALL
SELECT 'calendar', COUNT(*) FROM calendar
UNION ALL
SELECT 'calendar_dates', COUNT(*) FROM calendar_dates
UNION ALL
SELECT 'trips', COUNT(*) FROM trips
UNION ALL
SELECT 'stop_times', COUNT(*) FROM stop_times
UNION ALL
SELECT 'nearby_stops', COUNT(*) FROM nearby_stops
ORDER BY table_name;