// 1 przesiadka
MATCH (start:Stop {stop_id: '669525'})<-[st1:STOPS_AT]-(t1:Trip)-[st2:STOPS_AT]->(transfer:Stop)
MATCH (transfer)<-[st3:STOPS_AT]-(t2:Trip)-[st4:STOPS_AT]->(end:Stop {stop_id: '669722'})
  WHERE st1.stop_sequence < st2.stop_sequence
  AND st3.stop_sequence < st4.stop_sequence
  AND t1.trip_id <> t2.trip_id
  AND st1.departure_time >= '08:00:00'
  AND st2.arrival_time < st3.departure_time
MATCH (t1)-[:ON_ROUTE]->(r1:Route)
MATCH (t2)-[:ON_ROUTE]->(r2:Route)
RETURN start.stop_name, transfer.stop_name, end.stop_name,
       r1.route_short_name, r2.route_short_name,
       st1.departure_time, st2.arrival_time, st3.departure_time, st4.arrival_time
  ORDER BY st1.departure_time
  LIMIT 10;



// 2 przesiadki
MATCH (start:Stop {stop_id: '669525'})<-[st1:STOPS_AT]-(t1:Trip)-[st2:STOPS_AT]->(tr1:Stop)
MATCH (tr1)<-[st3:STOPS_AT]-(t2:Trip)-[st4:STOPS_AT]->(tr2:Stop)
MATCH (tr2)<-[st5:STOPS_AT]-(t3:Trip)-[st6:STOPS_AT]->(end:Stop {stop_id: '669722'})
  WHERE st1.stop_sequence < st2.stop_sequence
  AND st3.stop_sequence < st4.stop_sequence
  AND st5.stop_sequence < st6.stop_sequence
  AND t1.trip_id <> t2.trip_id AND t2.trip_id <> t3.trip_id
  AND st1.departure_time >= '08:00:00'
  AND st2.arrival_time < st3.departure_time
  AND st4.arrival_time < st5.departure_time
MATCH (t1)-[:ON_ROUTE]->(r1:Route)
MATCH (t2)-[:ON_ROUTE]->(r2:Route)
MATCH (t3)-[:ON_ROUTE]->(r3:Route)
RETURN start.stop_name, tr1.stop_name, tr2.stop_name, end.stop_name,
       r1.route_short_name, r2.route_short_name, r3.route_short_name,
       st1.departure_time, st2.arrival_time, st3.departure_time,
       st4.arrival_time, st5.departure_time, st6.arrival_time
  ORDER BY st1.departure_time
  LIMIT 10;


// 3 przesiadki
MATCH (start:Stop {stop_id: '669525'})<-[st1:STOPS_AT]-(t1:Trip)-[st2:STOPS_AT]->(tr1:Stop)
MATCH (tr1)<-[st3:STOPS_AT]-(t2:Trip)-[st4:STOPS_AT]->(tr2:Stop)
MATCH (tr2)<-[st5:STOPS_AT]-(t3:Trip)-[st6:STOPS_AT]->(tr3:Stop)
MATCH (tr3)<-[st7:STOPS_AT]-(t4:Trip)-[st8:STOPS_AT]->(end:Stop {stop_id: '669722'})
  WHERE st1.stop_sequence < st2.stop_sequence
  AND st3.stop_sequence < st4.stop_sequence
  AND st5.stop_sequence < st6.stop_sequence
  AND st7.stop_sequence < st8.stop_sequence
  AND t1.trip_id <> t2.trip_id
  AND t2.trip_id <> t3.trip_id
  AND t3.trip_id <> t4.trip_id
  AND st1.departure_time >= '08:00:00'
  AND st2.arrival_time < st3.departure_time
  AND st4.arrival_time < st5.departure_time
  AND st6.arrival_time < st7.departure_time
MATCH (t1)-[:ON_ROUTE]->(r1:Route)
MATCH (t2)-[:ON_ROUTE]->(r2:Route)
MATCH (t3)-[:ON_ROUTE]->(r3:Route)
MATCH (t4)-[:ON_ROUTE]->(r4:Route)
RETURN start.stop_name, tr1.stop_name, tr2.stop_name, tr3.stop_name, end.stop_name,
       r1.route_short_name, r2.route_short_name, r3.route_short_name, r4.route_short_name,
       st1.departure_time, st2.arrival_time, st3.departure_time,
       st4.arrival_time, st5.departure_time, st6.arrival_time,
       st7.departure_time, st8.arrival_time
  ORDER BY st1.departure_time
  LIMIT 10;
