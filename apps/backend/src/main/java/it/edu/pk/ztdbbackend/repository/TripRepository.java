package it.edu.pk.ztdbbackend.repository;

import it.edu.pk.ztdbbackend.entity.Trip;
import org.springframework.data.neo4j.repository.Neo4jRepository;
import org.springframework.data.neo4j.repository.query.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

/**
 * Created by tgulesserian on 5/18/17.
 */
public interface TripRepository extends Neo4jRepository<Trip, String>,Importable {
    @Query("CREATE INDEX trip_id_index IF NOT EXISTS FOR (t:Trip) ON (t.id)")
    void createIndexId();

    @Query("CREATE INDEX trip_service_id_index IF NOT EXISTS FOR (t:Trip) ON (t.service_id)")
    void createIndexServiceId();

    @Query("// add the trips\n" +
            "CALL apoc.periodic.iterate(\n" +
            "  'LOAD CSV WITH HEADERS FROM \"file:///trips.txt\" AS csv RETURN csv',\n" +
            "  'MATCH (r:Route {id: csv.route_id}) MERGE (t:Trip {id: csv.trip_id, service_id: csv.service_id})-[:TRIP_ROUTE]->(r)',\n" +
            "  {batchSize: 1000, parallel: false}\n" +
            ") YIELD batches RETURN batches")
    Long loadNodes ();

    //Trip findByTripId(@Param("tripId") String tripId, @Depth @Param("depth") int depth);

    @Query("MATCH (t:Trip {id: $tripId})-[*1..$depth]-(related) RETURN t, collect(related)")
    Trip findByTripIdWithDepth(@Param("tripId") String tripId, @Param("depth") int depth);

    @Query("""
        WITH $travelDate AS travelDate
        MATCH (t:Trip)-[:TRIP_ROUTE]->(r:Route {id: $routeId})
        OPTIONAL MATCH (t)-[:TRIP_CALENDAR]->(c:Calendar)
        WITH t, c, travelDate,
             CASE 
               WHEN travelDate IS NULL THEN true
               WHEN c IS NULL THEN false
               WHEN travelDate < c.start_date OR travelDate > c.end_date THEN false
               ELSE 
                 CASE toInteger(substring(datetime({date: date(
                   toInteger(substring(travelDate, 0, 4)),
                   toInteger(substring(travelDate, 4, 2)),
                   toInteger(substring(travelDate, 6, 2))
                 )}).epochMillis / 86400000, 0, 1))
                   WHEN 0 THEN c.monday
                   WHEN 1 THEN c.tuesday
                   WHEN 2 THEN c.wednesday
                   WHEN 3 THEN c.thursday
                   WHEN 4 THEN c.friday
                   WHEN 5 THEN c.saturday
                   WHEN 6 THEN c.sunday
                 END
             END AS isActive
        WHERE isActive = true
        RETURN t
        ORDER BY t.id ASC
        SKIP $skip
        LIMIT $limit
    """)
    List<Trip> findTripsForRoute(
            @Param("routeId") String routeId,
            @Param("travelDate") String travelDate,
            @Param("skip") int skip,
            @Param("limit") int limit
    );
}
