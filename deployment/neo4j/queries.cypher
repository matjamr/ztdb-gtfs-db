// Find all routes serving a specific stop on a specific date [WORKS]
WITH '2025-11-09' AS travelDateString,
     date('2025-11-09') AS travelDate
WITH travelDate,
     toString(travelDate.year) +
     CASE WHEN travelDate.month < 10 THEN '0' + toString(travelDate.month) ELSE toString(travelDate.month) END +
     CASE WHEN travelDate.day < 10 THEN '0' + toString(travelDate.day) ELSE toString(travelDate.day) END AS travelDateYYYYMMDD,
     (duration.between(date('1970-01-05'), travelDate).days % 7) AS dayOfWeek

MATCH (s:Stop)<-[:STOPTIME_STOP]-(st:Stoptime)-[:STOPTIME_TRIP]->(t:Trip)
MATCH (t)-[:TRIP_ROUTE]->(r:Route)
MATCH (t)-[:TRIP_CALENDAR]->(c:Calendar)
  WHERE s.name CONTAINS 'PKP Rakowiec'
  AND travelDateYYYYMMDD >= c.start_date
  AND travelDateYYYYMMDD <= c.end_date
RETURN DISTINCT
  s.name AS stop_name,
  s.id AS stop_id,
  r.short_name AS route_number,
  r.long_name AS route_name,
  dayOfWeek,
  COUNT(DISTINCT t) AS number_of_trips
  ORDER BY r.short_name
  LIMIT 500;

// Find routes with departure times for a specific stop on a given date [WORKS]
WITH '2025-11-09' AS travelDateString,
     date('2025-11-09') AS travelDate
WITH travelDate,
     toString(travelDate.year) +
     CASE WHEN travelDate.month < 10 THEN '0' + toString(travelDate.month) ELSE toString(travelDate.month) END +
     CASE WHEN travelDate.day < 10 THEN '0' + toString(travelDate.day) ELSE toString(travelDate.day) END AS travelDateYYYYMMDD,
     (duration.between(date('1970-01-05'), travelDate).days % 7) AS dayOfWeek

MATCH (s:Stop)<-[:STOPTIME_STOP]-(st:Stoptime)-[:STOPTIME_TRIP]->(t:Trip)
MATCH (t)-[:TRIP_ROUTE]->(r:Route)
MATCH (t)-[:TRIP_CALENDAR]->(c:Calendar)
  WHERE s.name CONTAINS 'PKP Rakowiec'
  AND travelDateYYYYMMDD >= c.start_date
  AND travelDateYYYYMMDD <= c.end_date
RETURN
  s.name AS stop_name,
  r.short_name AS route_number,
  st.departure_time AS departure_time,
  st.arrival_time AS arrival_time,
  t.id AS trip_id
  ORDER BY st.departure_time_int
  LIMIT 500;

// Direct trip from A to B (no transfers - same vehicle)
MATCH (st1:Stoptime)-[:STOPTIME_STOP]->(start:Stop)
  WHERE start.name CONTAINS 'PKP Rakowiec'
  AND st1.departure_time >= '08:00:00'
  AND st1.departure_time <= '18:00:00'

MATCH (st1)-[:STOPTIME_TRIP]->(t:Trip)
MATCH (st1)-[:PRECEDES*1..30]->(st2:Stoptime)-[:STOPTIME_STOP]->(end:Stop)

  WHERE end.name CONTAINS 'Wawelska'
  AND st1.stop_sequence < st2.stop_sequence

MATCH (t)-[:TRIP_ROUTE]->(r:Route)

RETURN start.name AS from_stop,
       end.name AS to_stop,
       r.short_name AS route_number,
       r.long_name AS route_name,
       t.id AS trip_id,
       st1.departure_time AS departure_time,
       st2.arrival_time AS arrival_time,
       st2.stop_sequence - st1.stop_sequence AS stops_between,
       (st2.arrival_time_int - st1.departure_time_int) AS travel_time_minutes
  ORDER BY st1.departure_time_int
  LIMIT 100;

// 1 transfer
MATCH (st1:Stoptime)-[:STOPTIME_STOP]->(start:Stop)
  WHERE start.name CONTAINS 'PKP Rakowiec'
  AND st1.departure_time >= '08:00:00'
  AND st1.departure_time <= '10:00:00'
MATCH (st1)-[:STOPTIME_TRIP]->(t1:Trip)
MATCH (st1)-[:PRECEDES*1..20]->(st2:Stoptime)-[:STOPTIME_STOP]->(transferStop1:Stop)
MATCH (transferStop1)-[nearby:NEARBY_STOPS]->(transferStop2:Stop)
  WHERE nearby.distance <= 200

MATCH (st3:Stoptime)-[:STOPTIME_STOP]->(transferStop2)
MATCH (st3)-[:STOPTIME_TRIP]->(t2:Trip)
MATCH (st3)-[:PRECEDES*1..20]->(st4:Stoptime)-[:STOPTIME_STOP]->(end:Stop)

  WHERE end.name CONTAINS 'PKP Włochy'
  AND st1.stop_sequence < st2.stop_sequence
  AND st3.stop_sequence < st4.stop_sequence
  AND t1.id <> t2.id
  AND st2.arrival_time < st3.departure_time
  AND ((st3.departure_time_int / 100) * 60 + (st3.departure_time_int % 100)) -
  ((st2.arrival_time_int / 100) * 60 + (st2.arrival_time_int % 100)) <= 15

MATCH (t1)-[:TRIP_ROUTE]->(r1:Route)
MATCH (t2)-[:TRIP_ROUTE]->(r2:Route)

RETURN start.name AS from_stop,
       transferStop1.name AS arrive_at_stop,
       transferStop2.name AS depart_from_stop,
       nearby.distance AS walking_distance_meters,
       end.name AS to_stop,
       r1.short_name AS first_route,
       r2.short_name AS second_route,
       st1.departure_time AS depart_from_start,
       st2.arrival_time AS arrive_at_transfer,
       st3.departure_time AS depart_from_transfer,
       st4.arrival_time AS arrive_at_destination,
       ((st3.departure_time_int / 100) * 60 + (st3.departure_time_int % 100)) -
       ((st2.arrival_time_int / 100) * 60 + (st2.arrival_time_int % 100)) AS transfer_wait_minutes
  ORDER BY st1.departure_time
  LIMIT 200;

// Discover all routes with their trip counts
MATCH (r:Route)<-[:TRIP_ROUTE]-(t:Trip)
WITH r, COUNT(DISTINCT t) AS trip_count
RETURN
  r.short_name AS route_number,
  CASE r.type
    WHEN 0 THEN 'Tram'
    WHEN 1 THEN 'Subway'
    WHEN 2 THEN 'Rail'
    WHEN 3 THEN 'Bus'
    WHEN 4 THEN 'Ferry'
    ELSE 'Other'
    END AS vehicle_type,
  trip_count AS total_trips
  ORDER BY trip_count DESC
  LIMIT 100;

// Find the busiest stops (most trips per day)
MATCH (s:Stop)<-[:STOPTIME_STOP]-(st:Stoptime)-[:STOPTIME_TRIP]->(t:Trip)
WITH s, COUNT(DISTINCT t) AS trips_per_day
  WHERE trips_per_day > 50
RETURN
  s.name AS stop_name,
  s.lat AS latitude,
  s.lon AS longitude,
  trips_per_day
  ORDER BY trips_per_day DESC
  LIMIT 20;

// 🕐 Show frequency pattern for a stop
MATCH (s:Stop {name: 'PKP Rakowiec'})<-[:STOPTIME_STOP]-(st:Stoptime)
WITH
  toInteger(substring(st.departure_time, 0, 2)) AS hour,
  COUNT(*) AS departures
  WHERE hour >= 6 AND hour <= 23
RETURN
  toString(hour) + ':00 - ' + toString(hour) + ':59' AS time_period,
  departures AS trips_per_hour,
  CASE
    WHEN departures >= 600 THEN '🔥🔥🔥 Very frequent'
    WHEN departures >= 400 THEN '🔥🔥 Frequent'
    WHEN departures >= 100 THEN '🔥 Regular'
    ELSE '⏰ Limited'
    END AS frequency
  ORDER BY hour;

// 🗺️ Find transfer hubs (stops with many nearby connections)
MATCH (s:Stop)-[nearby:NEARBY_STOPS]->(other:Stop)
WITH s, COUNT(other) AS nearby_stops, AVG(nearby.distance) AS avg_distance
  WHERE nearby_stops > 5
RETURN
  s.name AS hub_name,
  nearby_stops AS connected_stops,
  toInteger(avg_distance) AS avg_distance_meters,
  CASE
    WHEN nearby_stops >= 20 THEN '⭐⭐⭐ Major hub'
    WHEN nearby_stops >= 10 THEN '⭐⭐ Important hub'
    ELSE '⭐ Transfer point'
    END AS importance
  ORDER BY nearby_stops DESC
  LIMIT 100;

// 🔍 Find longest single-trip journeys (distinct by route)
MATCH (t:Trip)<-[:STOPTIME_TRIP]-(st:Stoptime)
WITH t,
     COUNT(st) AS total_stops,
     MIN(st.departure_time_int) AS first_time,
     MAX(st.arrival_time_int) AS last_time
  WHERE total_stops > 20
WITH t, total_stops,
     (toInteger(last_time - first_time) / 100) * 60 + toInteger(last_time - first_time) % 100 AS duration_minutes
MATCH (t)-[:TRIP_ROUTE]->(r:Route)
WITH r.short_name AS route,
     MAX(total_stops) AS max_stops,
     MAX(duration_minutes) AS max_duration
RETURN
  route,
  max_stops AS number_of_stops,
  max_duration AS duration_minutes
  ORDER BY max_stops DESC
  LIMIT 10;