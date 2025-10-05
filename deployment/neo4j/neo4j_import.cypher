USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM 'file:///stops.txt' AS row
CREATE (:Stop {
  stop_id: row.stop_id,
  stop_name: row.stop_name,
  stop_lat: toFloat(row.stop_lat),
  stop_lon: toFloat(row.stop_lon)
});
