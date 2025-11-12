package it.edu.pk.ztdbbackend.repository;

import it.edu.pk.ztdbbackend.entity.Route;
import org.springframework.data.neo4j.repository.Neo4jRepository;
import org.springframework.data.neo4j.repository.query.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface RouteRepository extends Neo4jRepository<Route,String>,Importable {
    @Query("CREATE INDEX route_id_index IF NOT EXISTS FOR (r:Route) ON (r.id)")
    void createIndex();

    @Query("// add the routes\n" +
            "CALL apoc.periodic.iterate(\n" +
            "  'LOAD CSV WITH HEADERS FROM \"file:///routes.txt\" AS csv RETURN csv',\n" +
            "  'MATCH (a:Agency {id: csv.agency_id}) CREATE (a)-[:OPERATES]->(r:Route {id: csv.route_id, short_name: csv.route_short_name, long_name: csv.route_long_name, type: toInteger(csv.route_type)})',\n" +
            "  {batchSize: 1000, parallel: false}\n" +
            ") YIELD batches RETURN batches")
    Long loadNodes ();

    @Query("MATCH (r:Route {id: $routeId})-[*1..$depth]-(related) RETURN r, collect(related)")
    Route findByRouteIdWithDepth(@Param("routeId") String routeId, @Param("depth") int depth);
}
