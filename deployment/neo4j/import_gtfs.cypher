MATCH (s:Stop {stop_id: "1450714"})<-[:STOPS_AT]-(t:Trip)-[:ON_ROUTE]->(r:Route)
RETURN DISTINCT r.route_short_name AS route

MATCH (s:Stop {stop_id: "1841203"})<-[:STOPS_AT]-(t:Trip)
RETURN t.trip_id, t.trip_headsign

MATCH path = (s1:Stop {stop_id: "80416"})-[:NEXT_STOP*1..200]->(s2:Stop {stop_id: "280603"})
RETURN path LIMIT 5

// Sprawdź czy masz węzły
MATCH (n) RETURN labels(n) as label, count(n) as count;

// Sprawdź czy masz relacje
MATCH ()-[r]->() RETURN type(r) as relationship, count(r) as count;

// Znajdź połączenia między przystankami
WITH "1527743" AS start_stop, "1527738" AS end_stop
MATCH path = (s1:Stop {stop_id: start_stop})-[:NEXT_STOP*1..10]->(s2:Stop {stop_id: end_stop})
RETURN path LIMIT 5;
