package it.edu.pk.ztdbbackend.repository;

import it.edu.pk.ztdbbackend.entity.Route;
import org.springframework.data.neo4j.repository.Neo4jRepository;
import org.springframework.data.neo4j.repository.query.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface RouteRepository extends Neo4jRepository<Route,String>,Importable {
    @Query("// add the routes\n" +
            "LOAD CSV WITH HEADERS FROM\n" +
            "'file:///routes.txt' AS csv\n" +
            "MATCH (a:Agency {id: csv.agency_id})\n" +
            "CREATE (a)-[:OPERATES]->(r:Route {id: csv.route_id, short_name: csv.route_short_name, long_name: csv.route_long_name, type: toInteger(csv.route_type)});\n")
    void loadNodes ();

    @Query("MATCH (r:Route {id: $routeId})-[*1..$depth]-(related) RETURN r, collect(related)")
    Route findByRouteIdWithDepth(@Param("routeId") String routeId, @Param("depth") int depth);
}
