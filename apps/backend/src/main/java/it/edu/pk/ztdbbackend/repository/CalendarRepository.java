package it.edu.pk.ztdbbackend.repository;

import it.edu.pk.ztdbbackend.entity.Calendar;
import org.springframework.data.neo4j.repository.Neo4jRepository;
import org.springframework.data.neo4j.repository.query.Query;
import org.springframework.data.rest.core.annotation.RepositoryRestResource;

@RepositoryRestResource(collectionResourceRel = "calendar", path = "calendar")
public interface CalendarRepository extends Neo4jRepository<Calendar, Long>, Importable {

    @Query("CREATE INDEX calendar_service_id_index IF NOT EXISTS FOR (c:Calendar) ON (c.service_id)")
    void createIndex();

    @Query(
            "CALL apoc.periodic.iterate(\n" +
            "  'LOAD CSV WITH HEADERS FROM \"file:///calendar.txt\" AS csv RETURN csv',\n" +
            "  'CREATE (c:Calendar {" +
            "    service_id: csv.service_id, " +
            "    monday: CASE csv.monday WHEN \"1\" THEN true ELSE false END, " +
            "    tuesday: CASE csv.tuesday WHEN \"1\" THEN true ELSE false END, " +
            "    wednesday: CASE csv.wednesday WHEN \"1\" THEN true ELSE false END, " +
            "    thursday: CASE csv.thursday WHEN \"1\" THEN true ELSE false END, " +
            "    friday: CASE csv.friday WHEN \"1\" THEN true ELSE false END, " +
            "    saturday: CASE csv.saturday WHEN \"1\" THEN true ELSE false END, " +
            "    sunday: CASE csv.sunday WHEN \"1\" THEN true ELSE false END, " +
            "    start_date: csv.start_date, " +
            "    end_date: csv.end_date" +
            "  }) " +
            "  WITH c, csv " +
            "  MATCH (t:Trip {service_id: csv.service_id}) " +
            "  CREATE (t)-[:TRIP_CALENDAR]->(c)',\n" +
            "  {batchSize: 1000, parallel: false}\n" +
            ") YIELD batches RETURN batches"
    )
    Long loadNodes();
}

