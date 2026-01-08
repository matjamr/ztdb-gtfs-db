-- GTFS PostgreSQL Schema
-- This file creates the database schema for GTFS data

-- Drop tables if they exist (for clean reinstallation)
DROP TABLE IF EXISTS stop_times CASCADE;
DROP TABLE IF EXISTS trips CASCADE;
DROP TABLE IF EXISTS routes CASCADE;
DROP TABLE IF EXISTS stops CASCADE;
DROP TABLE IF EXISTS calendar CASCADE;
DROP TABLE IF EXISTS calendar_dates CASCADE;
DROP TABLE IF EXISTS shapes CASCADE;
DROP TABLE IF EXISTS agency CASCADE;
DROP TABLE IF EXISTS feed_info CASCADE;

-- Agency table
CREATE TABLE agency (
                        agency_id VARCHAR(255) PRIMARY KEY,
                        agency_name VARCHAR(255) NOT NULL,
                        agency_url VARCHAR(255) NOT NULL,
                        agency_timezone VARCHAR(100) NOT NULL,
                        agency_phone VARCHAR(50),
                        agency_lang VARCHAR(10)
);

-- Routes table
CREATE TABLE routes (
                        route_id VARCHAR(255) PRIMARY KEY,
                        agency_id VARCHAR(255),
                        route_short_name VARCHAR(50),
                        route_long_name VARCHAR(255),
                        route_desc TEXT,
                        route_type INTEGER NOT NULL,
                        FOREIGN KEY (agency_id) REFERENCES agency(agency_id)
);

-- Stops table
CREATE TABLE stops (
                       stop_id VARCHAR(255) PRIMARY KEY,
                       stop_code VARCHAR(50),
                       stop_name VARCHAR(255) NOT NULL,
                       stop_lat DECIMAL(10, 8) NOT NULL,
                       stop_lon DECIMAL(11, 8) NOT NULL
);

-- Calendar table
CREATE TABLE calendar (
                          service_id VARCHAR(255) PRIMARY KEY,
                          monday INTEGER NOT NULL,
                          tuesday INTEGER NOT NULL,
                          wednesday INTEGER NOT NULL,
                          thursday INTEGER NOT NULL,
                          friday INTEGER NOT NULL,
                          saturday INTEGER NOT NULL,
                          sunday INTEGER NOT NULL,
                          start_date DATE NOT NULL,
                          end_date DATE NOT NULL
);

-- Calendar dates table (exceptions)
CREATE TABLE calendar_dates (
                                service_id VARCHAR(255) NOT NULL,
                                date DATE NOT NULL,
                                exception_type INTEGER NOT NULL,
                                PRIMARY KEY (service_id, date),
                                FOREIGN KEY (service_id) REFERENCES calendar(service_id)
);

-- Shapes table
CREATE TABLE shapes (
                        shape_id VARCHAR(255) NOT NULL,
                        shape_pt_lat DECIMAL(10, 8) NOT NULL,
                        shape_pt_lon DECIMAL(11, 8) NOT NULL,
                        shape_pt_sequence INTEGER NOT NULL,
                        PRIMARY KEY (shape_id, shape_pt_sequence)
);

-- Trips table
CREATE TABLE trips (
                       trip_id VARCHAR(255) PRIMARY KEY,
                       route_id VARCHAR(255) NOT NULL,
                       service_id VARCHAR(255) NOT NULL,
                       trip_headsign VARCHAR(255),
                       direction_id INTEGER,
                       shape_id VARCHAR(255),
                       FOREIGN KEY (route_id) REFERENCES routes(route_id),
                       FOREIGN KEY (service_id) REFERENCES calendar(service_id)
);

-- Stop times table
CREATE TABLE stop_times (
                            trip_id VARCHAR(255) NOT NULL,
                            arrival_time VARCHAR(8) NOT NULL,
                            departure_time VARCHAR(8) NOT NULL,
                            stop_id VARCHAR(255) NOT NULL,
                            stop_sequence INTEGER NOT NULL,
                            stop_headsign VARCHAR(255),
                            pickup_type INTEGER,
                            drop_off_type INTEGER,
                            shape_dist_traveled DECIMAL(10, 2),
                            timepoint INTEGER,
                            PRIMARY KEY (trip_id, stop_sequence),
                            FOREIGN KEY (trip_id) REFERENCES trips(trip_id),
                            FOREIGN KEY (stop_id) REFERENCES stops(stop_id)
);

-- Feed info table
CREATE TABLE feed_info (
                           feed_publisher_name VARCHAR(255) NOT NULL,
                           feed_publisher_url VARCHAR(255) NOT NULL,
                           feed_lang VARCHAR(10) NOT NULL,
                           feed_start_date DATE,
                           feed_end_date DATE,
                           feed_contact_email VARCHAR(255),
                           feed_version VARCHAR(50)
);

-- Create indexes for better query performance
CREATE INDEX idx_routes_agency ON routes(agency_id);
CREATE INDEX idx_trips_route ON trips(route_id);
CREATE INDEX idx_trips_service ON trips(service_id);
CREATE INDEX idx_stop_times_trip ON stop_times(trip_id);
CREATE INDEX idx_stop_times_stop ON stop_times(stop_id);
CREATE INDEX idx_calendar_dates_service ON calendar_dates(service_id);
CREATE INDEX idx_shapes_id ON shapes(shape_id);
CREATE INDEX idx_stops_location ON stops(stop_lat, stop_lon);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;

COMMENT ON TABLE agency IS 'Transit agencies with service represented in this dataset';
COMMENT ON TABLE routes IS 'Transit routes';
COMMENT ON TABLE stops IS 'Stops where vehicles pick up or drop off riders';
COMMENT ON TABLE calendar IS 'Service patterns that operate recurringly';
COMMENT ON TABLE calendar_dates IS 'Exceptions for the services defined in calendar';
COMMENT ON TABLE shapes IS 'Vehicle travel paths';
COMMENT ON TABLE trips IS 'Trips for each route';
COMMENT ON TABLE stop_times IS 'Times that a vehicle arrives at and departs from stops';
COMMENT ON TABLE feed_info IS 'Dataset metadata';

-- Success message
SELECT 'GTFS schema created successfully!' AS status;