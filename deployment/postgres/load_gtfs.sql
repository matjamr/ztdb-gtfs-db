-- GTFS Data Loading Script
-- This script loads GTFS data from CSV files into PostgreSQL tables

\echo 'Starting GTFS data import...'

-- Load agency data
\echo 'Loading agency.txt...'
COPY agency(agency_id, agency_name, agency_url, agency_timezone, agency_phone, agency_lang)
    FROM '/import/gtfs/agency.txt'
    DELIMITER ','
    CSV HEADER;

-- Load routes data
\echo 'Loading routes.txt...'
COPY routes(route_id, agency_id, route_short_name, route_long_name, route_desc, route_type)
    FROM '/import/gtfs/routes.txt'
    DELIMITER ','
    CSV HEADER;

-- Load stops data
\echo 'Loading stops.txt...'
COPY stops(stop_id, stop_code, stop_name, stop_lat, stop_lon)
    FROM '/import/gtfs/stops.txt'
    DELIMITER ','
    CSV HEADER;

-- Load calendar data
\echo 'Loading calendar.txt...'
COPY calendar(service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date)
    FROM '/import/gtfs/calendar.txt'
    DELIMITER ','
    CSV HEADER;

-- Load calendar_dates data (if file exists)
\echo 'Loading calendar_dates.txt...'
DO $$
    BEGIN
        COPY calendar_dates(service_id, date, exception_type)
            FROM '/import/gtfs/calendar_dates.txt'
            DELIMITER ','
            CSV HEADER;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'calendar_dates.txt not found or empty, skipping...';
    END $$;

-- Load shapes data (if file exists)
\echo 'Loading shapes.txt...'
DO $$
    BEGIN
        COPY shapes(shape_id, shape_pt_lat, shape_pt_lon, shape_pt_sequence)
            FROM '/import/gtfs/shapes.txt'
            DELIMITER ','
            CSV HEADER;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'shapes.txt not found or empty, skipping...';
    END $$;

-- Load trips data
\echo 'Loading trips.txt...'
COPY trips(route_id, service_id, trip_id, trip_headsign, direction_id, shape_id)
    FROM '/import/gtfs/trips.txt'
    DELIMITER ','
    CSV HEADER;

-- Load stop_times data (this is usually the largest file)
\echo 'Loading stop_times.txt (this may take a while)...'
COPY stop_times(trip_id, arrival_time, departure_time, stop_id, stop_sequence, stop_headsign, pickup_type, drop_off_type, shape_dist_traveled, timepoint)
    FROM '/import/gtfs/stop_times.txt'
    DELIMITER ','
    CSV HEADER;

-- Load feed_info data (if file exists)
\echo 'Loading feed_info.txt...'
DO $$
    BEGIN
        COPY feed_info(feed_publisher_name, feed_publisher_url, feed_lang, feed_start_date, feed_end_date, feed_contact_email, feed_version)
            FROM '/import/gtfs/feed_info.txt'
            DELIMITER ','
            CSV HEADER;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'feed_info.txt not found or empty, skipping...';
    END $$;

-- Verify data loaded
\echo '================================================'
\echo 'GTFS Data Import Complete!'
\echo '================================================'
\echo 'Record counts:'

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
SELECT 'shapes', COUNT(*) FROM shapes
UNION ALL
SELECT 'trips', COUNT(*) FROM trips
UNION ALL
SELECT 'stop_times', COUNT(*) FROM stop_times
UNION ALL
SELECT 'feed_info', COUNT(*) FROM feed_info
ORDER BY table_name;

\echo '================================================'
\echo 'Import verification complete'
\echo '================================================'