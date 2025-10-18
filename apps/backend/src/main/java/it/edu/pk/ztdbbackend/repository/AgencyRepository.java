package it.edu.pk.ztdbbackend.repository;

import it.edu.pk.ztdbbackend.entity.Agency;
import org.springframework.data.neo4j.repository.Neo4jRepository;
import org.springframework.data.neo4j.repository.query.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.data.rest.core.annotation.RepositoryRestResource;

@RepositoryRestResource(collectionResourceRel = "agency", path = "agency")
public interface AgencyRepository extends Neo4jRepository<Agency, String>,Importable {
    @Query("LOAD CSV WITH HEADERS FROM\n" +
            "'file:///agency.txt' AS csv\n" +
            "CREATE (a:Agency {id: csv.agency_id, name: csv.agency_name, url: csv.agency_url, timezone: csv.agency_timezone});\n")
    void loadNodes ();

    //Agency findByAgencyId(@Param("agencyId") String agencyId, @Depth @Param("depth") int depth);

    @Query("MATCH (a:Agency {id: $agencyId})-[*1..$depth]-(related) RETURN a, collect(related)")
    Agency findByAgencyIdWithDepth(@Param("agencyId") String agencyId, @Param("depth") int depth);

}
