-- init.sql - PostgreSQL schema initialization for GTFS data
-- Place this file in: ./deployment/postgres/init.sql

-- Drop existing tables if they exist (for clean reload)
DROP TABLE IF EXISTS stop_times CASCADE;
DROP TABLE IF EXISTS nearby_stops CASCADE;
DROP TABLE IF EXISTS trips CASCADE;
DROP TABLE IF EXISTS calendar_dates CASCADE;
DROP TABLE IF EXISTS calendar CASCADE;
DROP TABLE IF EXISTS routes CASCADE;
DROP TABLE IF EXISTS stops CASCADE;
DROP TABLE IF EXISTS agency CASCADE;
DROP TABLE IF EXISTS shapes CASCADE;
DROP TABLE IF EXISTS feed_info CASCADE;

-- Agency table
CREATE TABLE agency (
                        agency_id VARCHAR(255) PRIMARY KEY,
                        agency_name VARCHAR(255) NOT NULL,
                        agency_url VARCHAR(500),
                        agency_timezone VARCHAR(100),
                        agency_phone VARCHAR(50),
                        agency_lang VARCHAR(10)
);

-- Feed info table
CREATE TABLE feed_info (
                           feed_publisher_name VARCHAR(255),
                           feed_publisher_url VARCHAR(500),
                           feed_lang VARCHAR(10),
                           feed_start_date VARCHAR(8),
                           feed_end_date VARCHAR(8),
                           feed_contact_email VARCHAR(255),
                           feed_version VARCHAR(100)
);

-- Routes table
CREATE TABLE routes (
                        route_id VARCHAR(255) PRIMARY KEY,
                        agency_id VARCHAR(255) REFERENCES agency(agency_id),
                        route_short_name VARCHAR(50),
                        route_long_name VARCHAR(255),
                        route_desc TEXT,
                        route_type INTEGER
);

-- Stops table
CREATE TABLE stops (
                       stop_id VARCHAR(255) PRIMARY KEY,
                       stop_code VARCHAR(50),
                       stop_name VARCHAR(255) NOT NULL,
                       stop_lat DECIMAL(10, 8),
                       stop_lon DECIMAL(11, 8),
                       parent_station VARCHAR(255) REFERENCES stops(stop_id)
);

-- Calendar table
CREATE TABLE calendar (
                          service_id VARCHAR(255) PRIMARY KEY,
                          monday SMALLINT,
                          tuesday SMALLINT,
                          wednesday SMALLINT,
                          thursday SMALLINT,
                          friday SMALLINT,
                          saturday SMALLINT,
                          sunday SMALLINT,
                          start_date VARCHAR(8) NOT NULL,
                          end_date VARCHAR(8) NOT NULL
);

-- Calendar dates table (exceptions)
CREATE TABLE calendar_dates (
                                service_id VARCHAR(255),
                                date VARCHAR(8) NOT NULL,
                                exception_type SMALLINT,
                                PRIMARY KEY (service_id, date)
);

-- Shapes table
CREATE TABLE shapes (
                        shape_id VARCHAR(255),
                        shape_pt_lat DECIMAL(10, 8),
                        shape_pt_lon DECIMAL(11, 8),
                        shape_pt_sequence INTEGER,
                        PRIMARY KEY (shape_id, shape_pt_sequence)
);

-- Trips table
CREATE TABLE trips (
                       trip_id VARCHAR(255) PRIMARY KEY,
                       route_id VARCHAR(255) REFERENCES routes(route_id),
                       service_id VARCHAR(255) REFERENCES calendar(service_id),
                       trip_headsign VARCHAR(255),
                       direction_id SMALLINT,
                       shape_id VARCHAR(255)
);

-- Stop times table
CREATE TABLE stop_times (
                            trip_id VARCHAR(255) REFERENCES trips(trip_id),
                            stop_id VARCHAR(255) REFERENCES stops(stop_id),
                            arrival_time VARCHAR(8) NOT NULL,
                            departure_time VARCHAR(8) NOT NULL,
                            stop_sequence INTEGER NOT NULL,
                            stop_headsign VARCHAR(255),
                            pickup_type SMALLINT,
                            drop_off_type SMALLINT,
                            shape_dist_traveled DECIMAL(10, 2),
                            timepoint SMALLINT,
    -- Computed integer fields for easier time comparison
                            arrival_time_int INTEGER,
                            departure_time_int INTEGER,
                            PRIMARY KEY (trip_id, stop_sequence)
);

-- Nearby stops table (equivalent to NEARBY_STOPS relationship in Neo4j)
CREATE TABLE nearby_stops (
                              stop_id_from VARCHAR(255) REFERENCES stops(stop_id),
                              stop_id_to VARCHAR(255) REFERENCES stops(stop_id),
                              distance_meters DECIMAL(10, 2),
                              PRIMARY KEY (stop_id_from, stop_id_to)
);

-- Create indexes for performance
CREATE INDEX idx_routes_agency ON routes(agency_id);
CREATE INDEX idx_routes_short_name ON routes(route_short_name);

CREATE INDEX idx_stops_name ON stops(stop_name);
CREATE INDEX idx_stops_location ON stops(stop_lat, stop_lon);
CREATE INDEX idx_stops_parent ON stops(parent_station);

CREATE INDEX idx_calendar_dates_service ON calendar_dates(service_id);
CREATE INDEX idx_calendar_dates_date ON calendar_dates(date);

CREATE INDEX idx_trips_route ON trips(route_id);
CREATE INDEX idx_trips_service ON trips(service_id);

CREATE INDEX idx_stop_times_trip ON stop_times(trip_id);
CREATE INDEX idx_stop_times_stop ON stop_times(stop_id);
CREATE INDEX idx_stop_times_departure ON stop_times(departure_time_int);
CREATE INDEX idx_stop_times_sequence ON stop_times(stop_sequence);
CREATE INDEX idx_stop_times_trip_sequence ON stop_times(trip_id, stop_sequence);

CREATE INDEX idx_nearby_stops_from ON nearby_stops(stop_id_from);
CREATE INDEX idx_nearby_stops_to ON nearby_stops(stop_id_to);
CREATE INDEX idx_nearby_stops_distance ON nearby_stops(distance_meters);

-- Function to convert time string to integer (HH:MM:SS to HHMM)
CREATE OR REPLACE FUNCTION time_to_int(time_str VARCHAR)
RETURNS INTEGER AS $$
DECLARE
parts TEXT[];
    hours INTEGER;
    minutes INTEGER;
BEGIN
    IF time_str IS NULL THEN
        RETURN NULL;
END IF;

    parts := string_to_array(time_str, ':');
    hours := parts[1]::INTEGER;
    minutes := parts[2]::INTEGER;

RETURN hours * 100 + minutes;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to calculate distance between two points (Haversine formula)
CREATE OR REPLACE FUNCTION calculate_distance(
    lat1 DECIMAL, lon1 DECIMAL,
    lat2 DECIMAL, lon2 DECIMAL
)
RETURNS DECIMAL AS $$
DECLARE
r DECIMAL := 6371000; -- Earth radius in meters
    dlat DECIMAL;
    dlon DECIMAL;
    a DECIMAL;
    c DECIMAL;
BEGIN
    dlat := radians(lat2 - lat1);
    dlon := radians(lon2 - lon1);

    a := sin(dlat/2) * sin(dlat/2) +
         cos(radians(lat1)) * cos(radians(lat2)) *
         sin(dlon/2) * sin(dlon/2);

    c := 2 * atan2(sqrt(a), sqrt(1-a));

RETURN r * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Grants (adjust username if needed)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;