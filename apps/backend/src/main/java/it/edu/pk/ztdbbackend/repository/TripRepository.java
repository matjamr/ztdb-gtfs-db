package it.edu.pk.ztdbbackend.repository;

import it.edu.pk.ztdbbackend.entity.Trip;
import org.springframework.data.neo4j.repository.Neo4jRepository;
import org.springframework.data.neo4j.repository.query.Query;
import org.springframework.data.repository.query.Param;

/**
 * Created by tgulesserian on 5/18/17.
 */
public interface TripRepository extends Neo4jRepository<Trip, String>,Importable {
    @Query("// add the trips\n" +
            "LOAD CSV WITH HEADERS FROM\n" +
            "'file:///trips.txt' AS csv\n" +
            "MATCH (r:Route {id: csv.route_id})\n" +
            "MERGE (r)<-[:USES]-(t:Trip {id: csv.trip_id, service_id: csv.service_id});")
    void loadNodes ();

    //Trip findByTripId(@Param("tripId") String tripId, @Depth @Param("depth") int depth);

    @Query("MATCH (t:Trip {id: $tripId})-[*1..$depth]-(related) RETURN t, collect(related)")
    Trip findByTripIdWithDepth(@Param("tripId") String tripId, @Param("depth") int depth);

}
