package it.edu.pk.ztdbbackend.repository;

import it.edu.pk.ztdbbackend.entity.CalendarDate;
import org.springframework.data.neo4j.repository.Neo4jRepository;
import org.springframework.data.neo4j.repository.query.Query;
import org.springframework.data.rest.core.annotation.RepositoryRestResource;

@RepositoryRestResource(collectionResourceRel = "calendarDate", path = "calendarDate")
public interface CalendarDateRepository extends Neo4jRepository<CalendarDate, Long> {
    @Query(
            "LOAD CSV WITH HEADERS FROM\n" +
            "'file:///calendar_dates.txt' AS csv\n" +
            "MATCH (t:Trip {service_id: csv.service_id})\n" +
            "CREATE (t)-[:RUNS_DURING]->(cd:CalendarDate{service_id: csv.service_id, date: csv.date, exception_type: csv.exception_type })"
    )
    void loadNodes ();
}
