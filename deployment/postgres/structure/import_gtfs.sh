#!/bin/bash

# ============================================
# GTFS Data Import Script for Docker PostgreSQL
# ============================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="postgres"
DB_NAME="mydb"
DB_USER="postgres"
GTFS_DIR="./gtfs_data"  # Change this to your GTFS files directory

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}GTFS Data Import for PostgreSQL${NC}"
echo -e "${BLUE}============================================${NC}"

# Check if GTFS directory exists
if [ ! -d "$GTFS_DIR" ]; then
    echo -e "${RED}✗ GTFS directory not found: $GTFS_DIR${NC}"
    exit 1
fi

# Check if container is running
if ! docker ps | grep -q $CONTAINER_NAME; then
    echo -e "${RED}✗ PostgreSQL container is not running${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PostgreSQL container is running${NC}"

# Step 1: Create schema
echo -e "\n${YELLOW}Step 1: Creating database schema...${NC}"
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOF'
-- Drop existing tables
DROP TABLE IF EXISTS nearby_stops CASCADE;
DROP TABLE IF EXISTS stoptime_precedes CASCADE;
DROP TABLE IF EXISTS stoptimes CASCADE;
DROP TABLE IF EXISTS trips CASCADE;
DROP TABLE IF EXISTS routes CASCADE;
DROP TABLE IF EXISTS calendars CASCADE;
DROP TABLE IF EXISTS stops CASCADE;
DROP TABLE IF EXISTS agencies CASCADE;
DROP TABLE IF EXISTS shapes CASCADE;

-- Create agencies table
CREATE TABLE agencies (
    agency_id VARCHAR(50) PRIMARY KEY,
    agency_name VARCHAR(255) NOT NULL,
    agency_url VARCHAR(255),
    agency_timezone VARCHAR(50),
    agency_phone VARCHAR(50),
    agency_lang VARCHAR(10)
);

-- Create stops table
CREATE TABLE stops (
    id VARCHAR(50) PRIMARY KEY,
    code VARCHAR(50),
    name VARCHAR(255) NOT NULL,
    lat DECIMAL(10, 8),
    lon DECIMAL(11, 8)
);

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_stops_name ON stops(name);
CREATE INDEX idx_stops_name_pattern ON stops USING gin(name gin_trgm_ops);

-- Create routes table
CREATE TABLE routes (
    id VARCHAR(50) PRIMARY KEY,
    agency_id VARCHAR(50) REFERENCES agencies(agency_id),
    short_name VARCHAR(50),
    long_name VARCHAR(255),
    description TEXT,
    type INTEGER
);

CREATE INDEX idx_routes_short_name ON routes(short_name);

-- Create calendars table
CREATE TABLE calendars (
    id VARCHAR(50) PRIMARY KEY,
    monday BOOLEAN DEFAULT FALSE,
    tuesday BOOLEAN DEFAULT FALSE,
    wednesday BOOLEAN DEFAULT FALSE,
    thursday BOOLEAN DEFAULT FALSE,
    friday BOOLEAN DEFAULT FALSE,
    saturday BOOLEAN DEFAULT FALSE,
    sunday BOOLEAN DEFAULT FALSE,
    start_date VARCHAR(8) NOT NULL,
    end_date VARCHAR(8) NOT NULL
);

CREATE INDEX idx_calendars_dates ON calendars(start_date, end_date);

-- Create trips table
CREATE TABLE trips (
    id VARCHAR(50) PRIMARY KEY,
    route_id VARCHAR(50) NOT NULL REFERENCES routes(id),
    calendar_id VARCHAR(50) NOT NULL REFERENCES calendars(id),
    headsign VARCHAR(255),
    direction_id INTEGER,
    shape_id VARCHAR(50)
);

CREATE INDEX idx_trips_route_id ON trips(route_id);
CREATE INDEX idx_trips_calendar_id ON trips(calendar_id);
CREATE INDEX idx_trips_shape_id ON trips(shape_id);

-- Create stoptimes table
CREATE TABLE stoptimes (
    id SERIAL PRIMARY KEY,
    trip_id VARCHAR(50) NOT NULL REFERENCES trips(id),
    stop_id VARCHAR(50) NOT NULL REFERENCES stops(id),
    stop_sequence INTEGER NOT NULL,
    arrival_time VARCHAR(8),
    departure_time VARCHAR(8),
    arrival_time_int INTEGER,
    departure_time_int INTEGER,
    pickup_type INTEGER DEFAULT 0,
    drop_off_type INTEGER DEFAULT 0,
    UNIQUE(trip_id, stop_sequence)
);

CREATE INDEX idx_stoptimes_trip_id ON stoptimes(trip_id);
CREATE INDEX idx_stoptimes_stop_id ON stoptimes(stop_id);
CREATE INDEX idx_stoptimes_sequence ON stoptimes(trip_id, stop_sequence);
CREATE INDEX idx_stoptimes_departure ON stoptimes(departure_time_int);
CREATE INDEX idx_stoptimes_arrival ON stoptimes(arrival_time_int);

-- Create stoptime_precedes table
CREATE TABLE stoptime_precedes (
    from_stoptime_id INTEGER REFERENCES stoptimes(id),
    to_stoptime_id INTEGER REFERENCES stoptimes(id),
    PRIMARY KEY (from_stoptime_id, to_stoptime_id)
);

CREATE INDEX idx_precedes_from ON stoptime_precedes(from_stoptime_id);
CREATE INDEX idx_precedes_to ON stoptime_precedes(to_stoptime_id);

-- Create nearby_stops table
CREATE TABLE nearby_stops (
    from_stop_id VARCHAR(50) REFERENCES stops(id),
    to_stop_id VARCHAR(50) REFERENCES stops(id),
    distance DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (from_stop_id, to_stop_id)
);

CREATE INDEX idx_nearby_from ON nearby_stops(from_stop_id);
CREATE INDEX idx_nearby_to ON nearby_stops(to_stop_id);
CREATE INDEX idx_nearby_distance ON nearby_stops(distance);

-- Create shapes table
CREATE TABLE shapes (
    shape_id VARCHAR(50),
    shape_pt_lat DECIMAL(10, 8),
    shape_pt_lon DECIMAL(11, 8),
    shape_pt_sequence INTEGER,
    PRIMARY KEY (shape_id, shape_pt_sequence)
);

EOF

echo -e "${GREEN}✓ Schema created${NC}"

# Step 2: Copy GTFS files to container
echo -e "\n${YELLOW}Step 2: Copying GTFS files to container...${NC}"
docker cp "$GTFS_DIR" $CONTAINER_NAME:/tmp/gtfs/
echo -e "${GREEN}✓ Files copied${NC}"

# Step 3: Import data
echo -e "\n${YELLOW}Step 3: Importing data...${NC}"

# Import agencies
echo "  - Importing agencies..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOF'
\copy agencies (agency_id, agency_name, agency_url, agency_timezone, agency_phone, agency_lang) FROM '/tmp/gtfs/agency.txt' WITH (FORMAT csv, HEADER true, DELIMITER ',');
EOF

# Import stops
echo "  - Importing stops..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOF'
\copy stops (id, code, name, lat, lon) FROM '/tmp/gtfs/stops.txt' WITH (FORMAT csv, HEADER true, DELIMITER ',');
EOF

# Import routes
echo "  - Importing routes..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOF'
\copy routes (id, agency_id, short_name, long_name, description, type) FROM '/tmp/gtfs/routes.txt' WITH (FORMAT csv, HEADER true, DELIMITER ',');
EOF

# Import calendars
echo "  - Importing calendars..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOF'
\copy calendars (id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date) FROM '/tmp/gtfs/calendar.txt' WITH (FORMAT csv, HEADER true, DELIMITER ',');
EOF

# Import trips
echo "  - Importing trips..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOF'
\copy trips (route_id, calendar_id, id, headsign, direction_id, shape_id) FROM '/tmp/gtfs/trips.txt' WITH (FORMAT csv, HEADER true, DELIMITER ',');
EOF

# Import stop_times with time_int calculation
echo "  - Importing stop times..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOF'
CREATE TEMP TABLE temp_stoptimes (
    trip_id VARCHAR(50),
    arrival_time VARCHAR(8),
    departure_time VARCHAR(8),
    stop_id VARCHAR(50),
    stop_sequence INTEGER,
    stop_headsign VARCHAR(255),
    pickup_type INTEGER,
    drop_off_type INTEGER,
    shape_dist_traveled DECIMAL(10,3),
    timepoint INTEGER
);

\copy temp_stoptimes FROM '/tmp/gtfs/stop_times.txt' WITH (FORMAT csv, HEADER true, DELIMITER ',');

INSERT INTO stoptimes (trip_id, stop_id, stop_sequence, arrival_time, departure_time, arrival_time_int, departure_time_int, pickup_type, drop_off_type)
SELECT
    trip_id,
    stop_id,
    stop_sequence,
    arrival_time,
    departure_time,
    (CAST(SPLIT_PART(arrival_time, ':', 1) AS INTEGER) * 100 + CAST(SPLIT_PART(arrival_time, ':', 2) AS INTEGER)),
    (CAST(SPLIT_PART(departure_time, ':', 1) AS INTEGER) * 100 + CAST(SPLIT_PART(departure_time, ':', 2) AS INTEGER)),
    pickup_type,
    drop_off_type
FROM temp_stoptimes
ORDER BY trip_id, stop_sequence;

DROP TABLE temp_stoptimes;
EOF

# Import shapes (if file exists)
if docker exec $CONTAINER_NAME test -f /tmp/gtfs/shapes.txt; then
    echo "  - Importing shapes..."
    docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOF'
\copy shapes (shape_id, shape_pt_lat, shape_pt_lon, shape_pt_sequence) FROM '/tmp/gtfs/shapes.txt' WITH (FORMAT csv, HEADER true, DELIMITER ',');
EOF
else
    echo "  - Shapes file not found, skipping..."
fi

echo -e "${GREEN}✓ Data imported${NC}"

# Step 4: Build relationships
echo -e "\n${YELLOW}Step 4: Building relationships...${NC}"

echo "  - Building stoptime precedes..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOF'
INSERT INTO stoptime_precedes (from_stoptime_id, to_stoptime_id)
SELECT
    st1.id AS from_stoptime_id,
    st2.id AS to_stoptime_id
FROM stoptimes st1
JOIN stoptimes st2 ON st1.trip_id = st2.trip_id
    AND st2.stop_sequence = st1.stop_sequence + 1
ON CONFLICT DO NOTHING;
EOF

echo "  - Building nearby stops (this may take a while)..."
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOF'
INSERT INTO nearby_stops (from_stop_id, to_stop_id, distance)
SELECT
    s1.id AS from_stop_id,
    s2.id AS to_stop_id,
    (6371000 * ACOS(
        LEAST(1.0, GREATEST(-1.0,
            COS(RADIANS(s1.lat)) * COS(RADIANS(s2.lat)) *
            COS(RADIANS(s2.lon) - RADIANS(s1.lon)) +
            SIN(RADIANS(s1.lat)) * SIN(RADIANS(s2.lat))
        ))
    )) AS distance
FROM stops s1
CROSS JOIN stops s2
WHERE s1.id < s2.id
    AND s1.lat IS NOT NULL
    AND s1.lon IS NOT NULL
    AND s2.lat IS NOT NULL
    AND s2.lon IS NOT NULL
    AND ABS(s1.lat - s2.lat) < 0.01
    AND ABS(s1.lon - s2.lon) < 0.01
HAVING (6371000 * ACOS(
        LEAST(1.0, GREATEST(-1.0,
            COS(RADIANS(s1.lat)) * COS(RADIANS(s2.lat)) *
            COS(RADIANS(s2.lon) - RADIANS(s1.lon)) +
            SIN(RADIANS(s1.lat)) * SIN(RADIANS(s2.lat))
        ))
    )) <= 500
ON CONFLICT DO NOTHING;

-- Add reverse direction
INSERT INTO nearby_stops (from_stop_id, to_stop_id, distance)
SELECT to_stop_id, from_stop_id, distance
FROM nearby_stops
ON CONFLICT DO NOTHING;
EOF

echo -e "${GREEN}✓ Relationships built${NC}"

# Step 5: Analyze tables
echo -e "\n${YELLOW}Step 5: Analyzing tables...${NC}"
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOF'
ANALYZE agencies;
ANALYZE stops;
ANALYZE routes;
ANALYZE calendars;
ANALYZE trips;
ANALYZE stoptimes;
ANALYZE stoptime_precedes;
ANALYZE nearby_stops;
ANALYZE shapes;
EOF

echo -e "${GREEN}✓ Tables analyzed${NC}"

# Step 6: Show statistics
echo -e "\n${YELLOW}Step 6: Database statistics${NC}"
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOF'
SELECT
    'Agencies' AS table_name,
    COUNT(*) AS count
FROM agencies
UNION ALL
SELECT 'Stops', COUNT(*) FROM stops
UNION ALL
SELECT 'Routes', COUNT(*) FROM routes
UNION ALL
SELECT 'Calendars', COUNT(*) FROM calendars
UNION ALL
SELECT 'Trips', COUNT(*) FROM trips
UNION ALL
SELECT 'Stop Times', COUNT(*) FROM stoptimes
UNION ALL
SELECT 'Precedes Relationships', COUNT(*) FROM stoptime_precedes
UNION ALL
SELECT 'Nearby Stops', COUNT(*) FROM nearby_stops
UNION ALL
SELECT 'Shapes', COUNT(*) FROM shapes;
EOF

echo -e "\n${BLUE}============================================${NC}"
echo -e "${GREEN}✓ DATA IMPORT COMPLETED SUCCESSFULLY!${NC}"
echo -e "${BLUE}============================================${NC}"