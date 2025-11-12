# Neo4j GTFS Transit Queries Documentation

This document explains all the Cypher queries available for querying GTFS (General Transit Feed Specification) data in Neo4j.

## Table of Contents
1. [Date-Based Queries](#date-based-queries)
2. [Direct Trip Queries](#direct-trip-queries)
3. [Transfer Journey Queries](#transfer-journey-queries)
4. [Network Analysis Queries](#network-analysis-queries)

---

## Date-Based Queries

### 1. Find All Routes Serving a Specific Stop on a Specific Date

**Purpose**: Discover which routes operate at a given stop on a particular day.

**Query Details**:
- Converts date to YYYYMMDD format for comparison with Calendar nodes
- Calculates day of week to match service patterns
- Filters trips by calendar dates and day-of-week patterns

**Parameters to customize**:
- `'2025-11-09'` - Target date
- `'PKP Rakowiec'` - Stop name (uses CONTAINS for partial matching)

**Returns**:
- Stop name and ID
- Route number and name
- Day of week (0=Monday, 6=Sunday)
- Number of trips operating that day

**Use case**: "What buses/trains stop at PKP Rakowiec on November 9th?"

---

### 2. Find Routes with Departure Times for a Specific Stop

**Purpose**: Get detailed schedule information for a stop on a specific date.

**Query Details**:
- Similar to Query #1 but returns individual trip times
- Shows actual departure and arrival times
- Sorted chronologically

**Parameters to customize**:
- `'2025-11-09'` - Target date
- `'PKP Rakowiec'` - Stop name

**Returns**:
- Stop name
- Route number
- Departure and arrival times
- Trip ID

**Use case**: "Show me all departures from PKP Rakowiec on November 9th"

---

## Direct Trip Queries

### 3. Direct Trip from Stop A to Stop B (No Transfers)

**Purpose**: Find direct connections between two stops on the same vehicle/route.

**Query Details**:
- Uses `PRECEDES*1..30` to traverse stops within a single trip
- Both stops must be on the same trip (same vehicle)
- Limits time window to 08:00-18:00
- Maximum 30 stops between origin and destination

**Parameters to customize**:
- `'PKP Rakowiec'` - Origin stop
- `'Wawelska'` - Destination stop
- `'08:00:00'` and `'18:00:00'` - Time window
- `*1..30` - Max stops to traverse (adjust for performance)

**Returns**:
- Origin and destination names
- Route number and name
- Trip ID
- Departure and arrival times
- Number of stops between origin and destination
- Travel time in minutes

**Use case**: "Can I get from PKP Rakowiec to Wawelska on the same bus/train?"

---

## Transfer Journey Queries

### 4. One Transfer Journey

**Purpose**: Find journeys requiring exactly one transfer between two stops.

**Query Details**:
- **First leg**: Find trips from origin to transfer point
- **Transfer**: Uses `NEARBY_STOPS` relationship to find walking transfers (≤200m)
- **Second leg**: Find trips from transfer point to destination
- Ensures transfer wait time ≤ 15 minutes
- Different trips (no same-route connections)

**Key features**:
- Handles walking transfers between nearby stops
- Shows walking distance in meters
- Calculates transfer waiting time
- Both stops in transfer can be different (walking transfer)

**Parameters to customize**:
- `'PKP Rakowiec'` - Origin
- `'PKP Włochy'` - Destination
- `'08:00:00'` to `'10:00:00'` - Departure time window
- `*1..20` - Max stops per leg (reduce for faster queries)
- `nearby.distance <= 200` - Max walking distance
- `<= 15` - Max transfer wait time (minutes)

**Returns**:
- Origin and destination names
- Transfer stop names (arrival and departure, can be different)
- Walking distance between transfer stops
- Route numbers for both legs
- Complete timing information
- Transfer wait time

**Use case**: "How do I get from PKP Rakowiec to PKP Włochy with one transfer?"

---

## Network Analysis Queries

### 5. Discover All Routes with Trip Counts

**Purpose**: Overview of all routes in the system with their frequency.

**Query Details**:
- Counts total trips per route
- Classifies routes by vehicle type (GTFS type codes)
- Sorted by frequency (busiest routes first)

**Vehicle Type Codes**:
- 0 = Tram
- 1 = Subway
- 2 = Rail
- 3 = Bus
- 4 = Ferry

**Returns**:
- Route number
- Vehicle type (human-readable)
- Total number of trips

**Use case**: "What are the busiest routes in the network?"

---

### 6. Find the Busiest Stops

**Purpose**: Identify major transit hubs by counting trips.

**Query Details**:
- Counts distinct trips stopping at each location
- Filters for stops with >50 trips/day
- Shows geographic coordinates

**Parameters to customize**:
- `trips_per_day > 50` - Minimum threshold

**Returns**:
- Stop name
- Latitude and longitude
- Daily trip count

**Use case**: "Where are the major transit hubs?"

---

### 7. Show Frequency Pattern for a Stop

**Purpose**: Understand service frequency throughout the day at a specific stop.

**Query Details**:
- Groups departures by hour (6 AM to 11 PM)
- Categorizes frequency with emojis
- Extracts hour from departure time string

**Frequency Thresholds**:
- 🔥🔥🔥 Very frequent: ≥600 departures/hour
- 🔥🔥 Frequent: ≥400 departures/hour
- 🔥 Regular: ≥100 departures/hour
- ⏰ Limited: <100 departures/hour

**Parameters to customize**:
- `'PKP Rakowiec'` - Stop name (exact match)
- `hour >= 6 AND hour <= 23` - Time range

**Returns**:
- Time period (hourly blocks)
- Number of departures
- Frequency category

**Use case**: "When is the busiest time at PKP Rakowiec?"

---

### 8. Find Transfer Hubs

**Purpose**: Identify stops with many nearby connection opportunities.

**Query Details**:
- Uses `NEARBY_STOPS` relationships
- Counts nearby stops within 200m
- Calculates average walking distance
- Categorizes hub importance

**Hub Categories**:
- ⭐⭐⭐ Major hub: ≥20 nearby stops
- ⭐⭐ Important hub: ≥10 nearby stops
- ⭐ Transfer point: 6-9 nearby stops

**Parameters to customize**:
- `nearby_stops > 5` - Minimum threshold

**Returns**:
- Hub name
- Number of connected stops
- Average walking distance
- Importance rating

**Use case**: "Where are the best places to transfer between routes?"

---

### 9. Find Longest Single-Trip Journeys

**Purpose**: Discover the longest routes in the system.

**Query Details**:
- Counts stops per trip
- Calculates total journey duration
- Groups by route to show longest trip per route
- Filters for routes with >20 stops

**Calculation Details**:
- Duration calculated from first departure to last arrival
- Converts time_int format (HHmm) to minutes
- Shows one result per unique route (using MAX aggregation)

**Parameters to customize**:
- `total_stops > 20` - Minimum stops threshold

**Returns**:
- Route number
- Maximum stops on any trip
- Maximum duration in minutes

**Use case**: "What are the longest routes in the system?"

---

## Technical Notes

### Date Format
- Neo4j storage: `'20251109'` (YYYYMMDD string)
- Query input: `'2025-11-09'` (converted to YYYYMMDD)

### Day of Week Calculation
```cypher
(duration.between(date('1970-01-05'), travelDate).days % 7) AS dayOfWeek
```
- 0 = Monday
- 6 = Sunday
- Reference date: 1970-01-05 (a Monday)

### Time Format
- String: `'08:30:00'` (HH:MM:SS)
- Integer: `830` (HHmm, for calculations)

### Performance Tips
1. **Limit path traversal**: Use `*1..15` instead of `*1..` 
2. **Add time windows**: Narrow departure times
3. **Use indexes**: Run index creation queries
4. **Limit results**: Use `LIMIT` appropriately

### Relationship Types
- `STOPTIME_STOP`: Stoptime → Stop
- `STOPTIME_TRIP`: Stoptime → Trip
- `TRIP_ROUTE`: Trip → Route
- `TRIP_CALENDAR`: Trip → Calendar
- `PRECEDES`: Stoptime → Stoptime (sequence within trip)
- `NEARBY_STOPS`: Stop → Stop (geographic proximity ≤200m)

---

## Common Customizations

### Change Date
Replace all instances of `'2025-11-09'` or `'20251109'` with your target date.

### Change Stops
Replace stop names like `'PKP Rakowiec'` with your desired stops.
Use `CONTAINS` for partial matching or `=` for exact matching.

### Adjust Time Windows
Change time constraints:
```cypher
AND st1.departure_time >= '06:00:00'
AND st1.departure_time <= '22:00:00'
```

### Performance Tuning
For faster queries:
- Reduce `PRECEDES*1..30` to `PRECEDES*1..15`
- Narrow time windows
- Add intermediate `LIMIT` clauses
- Use more specific stop names

---

## Query Execution Order

For exploring a new dataset:
1. Run Query #5 (Discover routes)
2. Run Query #6 (Find busiest stops)
3. Run Query #2 (Check schedule for specific stop)
4. Run Query #3 (Test direct connections)
5. Run Query #4 (Test transfer connections)

