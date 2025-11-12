package it.edu.pk.ztdbbackend.repository;

import it.edu.pk.ztdbbackend.entity.Stop;
import org.springframework.data.neo4j.repository.Neo4jRepository;
import org.springframework.data.neo4j.repository.query.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface StopRepository extends Neo4jRepository<Stop, String> {
    @Query("CREATE INDEX stop_id_index IF NOT EXISTS FOR (s:Stop) ON (s.id)")
    void createIndex();

    @Query(
            "//connect parent/child relationships to stops\n" +
            "CALL apoc.periodic.iterate(\n" +
            "  'LOAD CSV WITH HEADERS FROM \"file:///stops.txt\" AS csv WITH csv WHERE csv.parent_station IS NOT NULL RETURN csv',\n" +
            "  'MATCH (ps:Stop {id: csv.parent_station}) MATCH (s:Stop {id: csv.stop_id}) CREATE (ps)<-[:PART_OF]-(s)',\n" +
            "  {batchSize: 1000, parallel: false}\n" +
            ") YIELD batches RETURN batches")
    Long connectParentChild ();

    @Query( "//add the stops\n" +
            "CALL apoc.periodic.iterate(\n" +
            "  'LOAD CSV WITH HEADERS FROM \"file:///stops.txt\" AS csv RETURN csv',\n" +
            "  'CREATE (s:Stop {id: csv.stop_id, name: csv.stop_name, lat: toFloat(csv.stop_lat), lon: toFloat(csv.stop_lon), platform_code: csv.platform_code, parent_station: csv.parent_station, location_type: csv.location_type})',\n" +
            "  {batchSize: 1000, parallel: true}\n" +
            ") YIELD batches RETURN batches")
    Long addStops();

    //Stop findByName(@Param("stopName") String stopName,@Depth @Param("depth") int depth);

    @Query("MATCH (s:Stop {name: $stopName})-[*1..$depth]-(related) RETURN s, collect(related)")
    Stop findByNameWithDepth(@Param("stopName") String stopName, @Param("depth") int depth);

    @Query("""
        MATCH (t:Trip)-[:TRIP_ROUTE]->(r:Route {id: $routeId})
        MATCH (st:Stoptime)-[:STOPTIME_TRIP]->(t)
        MATCH (st)-[:STOPTIME_STOP]->(s:Stop)
        RETURN DISTINCT s ORDER BY s.name
    """)
    List<Stop> findStopsForRoute(@Param("routeId") String routeId);

    @Query(
            "//create nearby stops relationships for stops within 200 meters\n" +
            "CALL apoc.periodic.iterate(\n" +
            "  'MATCH (s1:Stop) WHERE s1.location_type IS NULL OR s1.location_type <> \"1\" RETURN s1',\n" +
            "  'MATCH (s2:Stop) " +
            "   WHERE (s2.location_type IS NULL OR s2.location_type <> \"1\") " +
            "   AND s1.id <> s2.id " +
            "   AND point.distance(" +
            "     point({latitude: s1.lat, longitude: s1.lon}), " +
            "     point({latitude: s2.lat, longitude: s2.lon})" +
            "   ) <= 200 " +
            "   WITH s1, s2, toInteger(point.distance(" +
            "     point({latitude: s1.lat, longitude: s1.lon}), " +
            "     point({latitude: s2.lat, longitude: s2.lon})" +
            "   )) AS distance " +
            "   CREATE (s1)-[:NEARBY_STOPS {distance: distance}]->(s2)',\n" +
            "  {batchSize: 100, parallel: false}\n" +
            ") YIELD batches RETURN batches")
    Long createNearbyStopsRelationships();

}
