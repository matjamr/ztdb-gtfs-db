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

// List available stops (to find actual stop names in your data) [WORKS]
MATCH (s:Stop)
RETURN s.name, s.id
ORDER BY s.name;

// 1 transfer - PKP Rakowiec to Metro Ratusz Arsenał [WORKS]
MATCH (st1:Stoptime)-[:STOPTIME_STOP]->(start:Stop)
  WHERE start.name CONTAINS 'PKP Rakowiec'
MATCH (st1)-[:STOPTIME_TRIP]->(t1:Trip)
MATCH (st1)-[:PRECEDES*1..]->(st2:Stoptime)-[:STOPTIME_STOP]->(transfer:Stop)
MATCH (st3:Stoptime)-[:STOPTIME_STOP]->(transfer)
MATCH (st3)-[:STOPTIME_TRIP]->(t2:Trip)
MATCH (st3)-[:PRECEDES*1..]->(st4:Stoptime)-[:STOPTIME_STOP]->(end:Stop)
  WHERE end.name CONTAINS 'Metro Ratusz Arsenał'
  AND st1.stop_sequence < st2.stop_sequence
  AND st3.stop_sequence < st4.stop_sequence
  AND t1.id <> t2.id
  AND st1.departure_time >= '08:00:00'
  AND st2.arrival_time < st3.departure_time
  AND ((st3.departure_time_int / 100) * 60 + (st3.departure_time_int % 100)) -
  ((st2.arrival_time_int / 100) * 60 + (st2.arrival_time_int % 100)) <= 15
MATCH (t1)-[:TRIP_ROUTE]->(r1:Route)
MATCH (t2)-[:TRIP_ROUTE]->(r2:Route)
RETURN start.name AS from_stop,
       transfer.name AS transfer_stop,
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
  LIMIT 100;

// 1 transfer - PKP Rakowiec to Żołny
MATCH (start:Stop)
  WHERE start.name CONTAINS 'PKP Rakowiec'
WITH COLLECT(start.id) AS directStartIds, COLLECT(start.parent_station) AS parentStartIds
WITH directStartIds + [id IN parentStartIds WHERE id IS NOT NULL] AS allStartIds

MATCH (end:Stop)
  WHERE end.name CONTAINS 'Żołny'
WITH allStartIds, COLLECT(end.id) AS directEndIds, COLLECT(end.parent_station) AS parentEndIds
WITH allStartIds, directEndIds + [id IN parentEndIds WHERE id IS NOT NULL] AS allEndIds

MATCH (st1:Stoptime)-[:STOPTIME_STOP]->(startStop:Stop)
  WHERE startStop.id IN allStartIds
  OR startStop.parent_station IN allStartIds
  AND st1.departure_time >= '08:00:00'
  AND st1.departure_time <= '10:00:00'
MATCH (st1)-[:STOPTIME_TRIP]->(t1:Trip)
MATCH (st1)-[:PRECEDES*1..20]->(st2:Stoptime)-[:STOPTIME_STOP]->(transfer:Stop)

MATCH (st3:Stoptime)-[:STOPTIME_STOP]->(transfer)
MATCH (st3)-[:STOPTIME_TRIP]->(t2:Trip)
MATCH (st3)-[:PRECEDES*1..20]->(st4:Stoptime)-[:STOPTIME_STOP]->(endStop:Stop)

  WHERE (endStop.id IN allEndIds OR endStop.parent_station IN allEndIds)
  AND st1.stop_sequence < st2.stop_sequence
  AND st3.stop_sequence < st4.stop_sequence
  AND t1.id <> t2.id
  AND st2.arrival_time < st3.departure_time
  AND ((st3.departure_time_int / 100) * 60 + (st3.departure_time_int % 100)) -
  ((st2.arrival_time_int / 100) * 60 + (st2.arrival_time_int % 100)) <= 15

MATCH (t1)-[:TRIP_ROUTE]->(r1:Route)
MATCH (t2)-[:TRIP_ROUTE]->(r2:Route)

RETURN startStop.name AS from_stop,
       transfer.name AS transfer_stop,
       endStop.name AS to_stop,
       r1.short_name AS first_route,
       r2.short_name AS second_route,
       st1.departure_time AS depart_from_start,
       st2.arrival_time AS arrive_at_transfer,
       st3.departure_time AS depart_from_transfer,
       st4.arrival_time AS arrive_at_destination,
       ((st3.departure_time_int / 100) * 60 + (st3.departure_time_int % 100)) -
       ((st2.arrival_time_int / 100) * 60 + (st2.arrival_time_int % 100)) AS transfer_wait_minutes
  ORDER BY st1.departure_time
  LIMIT 5;

// 1 transfer - PKP Rakowiec to Metro Ratusz Arsenał SORT BY SHORTEST [WORKS]
MATCH (st1:Stoptime)-[:STOPTIME_STOP]->(start:Stop)
  WHERE start.name CONTAINS 'PKP Rakowiec'
  AND st1.departure_time >= '08:00:00'
MATCH (st1)-[:STOPTIME_TRIP]->(t1:Trip)
MATCH (st1)-[:PRECEDES*1..30]->(st2:Stoptime)-[:STOPTIME_STOP]->(transfer:Stop)
  WHERE st1.stop_sequence < st2.stop_sequence

MATCH (st3:Stoptime)-[:STOPTIME_STOP]->(transfer)
MATCH (st3)-[:STOPTIME_TRIP]->(t2:Trip)
MATCH (st3)-[:PRECEDES*1..30]->(st4:Stoptime)-[:STOPTIME_STOP]->(end:Stop)
  WHERE end.name CONTAINS 'Metro Ratusz Arsenał'
  AND st3.stop_sequence < st4.stop_sequence
  AND t1.id <> t2.id
  AND st2.arrival_time < st3.departure_time

MATCH (t1)-[:TRIP_ROUTE]->(r1:Route)
MATCH (t2)-[:TRIP_ROUTE]->(r2:Route)

WITH start, transfer, end, r1, r2, st1, st2, st3, st4,
     ((st3.departure_time_int / 100) * 60 + (st3.departure_time_int % 100)) -
     ((st2.arrival_time_int / 100) * 60 + (st2.arrival_time_int % 100)) AS transfer_wait_minutes

  WHERE transfer_wait_minutes <= 15 AND transfer_wait_minutes >= 0

RETURN start.name AS from_stop,
       transfer.name AS transfer_stop,
       end.name AS to_stop,
       r1.short_name AS first_route,
       r2.short_name AS second_route,
       st1.departure_time AS depart_from_start,
       st2.arrival_time AS arrive_at_transfer,
       st3.departure_time AS depart_from_transfer,
       st4.arrival_time AS arrive_at_destination,
       transfer_wait_minutes
  ORDER BY st1.departure_time
  LIMIT 100;


