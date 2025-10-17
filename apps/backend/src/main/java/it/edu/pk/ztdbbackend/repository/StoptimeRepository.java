package it.edu.pk.ztdbbackend.repository;

import it.edu.pk.ztdbbackend.entity.Stoptime;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.neo4j.repository.Neo4jRepository;
import org.springframework.data.neo4j.repository.query.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface StoptimeRepository extends Neo4jRepository<Stoptime, Long> {


    @Query("//add the stoptimes \n" +
            "LOAD CSV WITH HEADERS FROM\n" +
            "'file:///stop_times.txt' AS csv\n" +
            "MATCH (t:Trip {id: csv.trip_id}), (s:Stop {id: csv.stop_id})\n" +
            "CREATE (t)<-[:PART_OF_TRIP]-(st:Stoptime {arrival_time: csv.arrival_time, departure_time: csv.departure_time, stop_sequence: toInteger(csv.stop_sequence)})-[:LOCATED_AT]->(s);\n")
    void addStopTimes();

    @Query( "//create integers out of the stoptimes (to allow for calculations/ordering)\n" +
            "MATCH (s:Stoptime)\n" +
            "SET s.arrival_time_int=toInteger(replace(s.arrival_time,':',''))/100\n" +
            "SET s.departure_time_int=toInteger(replace(s.departure_time,':',''))/100\n" +
            "; ")
    void stopTimeToInt();

    @Query(
            "//connect the stoptime sequences\n" +
            "MATCH (s1:Stoptime)-[:PART_OF_TRIP]->(t:Trip),\n" +
            "      (s2:Stoptime)-[:PART_OF_TRIP]->(t)\n" +
            "WHERE s2.stop_sequence=s1.stop_sequence + 1 \n" +
            "CREATE (s1)-[:PRECEDES]->(s2);")
    void connectSequences();


    @Query(
            value="""
                MATCH
                  (cd:CalendarDate)
                WHERE
                  cd.date = $travelDate
                WITH
                  cd

                MATCH
                  (orig:Stop {name: $origStation})<-[:LOCATED_AT]-(st_orig:Stoptime)-[:PART_OF_TRIP]->(trip:Trip),
                  (st_orig)-[:PRECEDES*1..50]->(st_dest:Stoptime)-[:LOCATED_AT]->(dest:Stop {name: $destStation})
                WHERE
                  trip.service_id = cd.service_id
                  AND st_orig.departure_time > $origArrivalTimeLow
                  AND st_orig.departure_time < $origArrivalTimeHigh
                  AND st_dest.arrival_time_int > st_orig.departure_time_int

                RETURN
                  orig.name AS startStop,
                  st_orig.departure_time AS startDeparture,
                  trip.id AS tripId,
                  dest.name AS endStop,
                  st_dest.arrival_time AS endArrival,
                  (st_dest.arrival_time_int - st_orig.departure_time_int) / 60 AS travelTimeMinutes

                ORDER BY
                  st_dest.arrival_time_int - st_orig.departure_time_int ASC
                SKIP $skip
                LIMIT $limit
        """
    )
    List<TripProjection> getMyTrips(
            @Param("travelDate") String travelDate,
            @Param("origStation") String origStation,
            @Param("origArrivalTimeLow") String origArrivalTimeLow,
            @Param("origArrivalTimeHigh") String origArrivalTimeHigh,
            @Param("destStation") String destStation,
            @Param("destArrivalTimeLow") String destArrivalTimeLow,
            @Param("destArrivalTimeHigh") String destArrivalTimeHigh,
            @Param("skip") int skip,
            @Param("limit") int limit);



    @Query(
            "MATCH\n" +
            "  (cd:CalendarDate)\n" +
            "WHERE \n" +
            "    cd.date = $travelDate AND \n" +
            "    cd.exception_type = '1'\n" +
            "WITH cd\n" +
            "MATCH\n" +
            "    p3=(orig:Stop {name: $origStation})<-[:LOCATED_AT]-(st_orig:Stoptime)-[r1:PART_OF_TRIP]->(trp1:Trip),\n" +
            "    p4=(dest:Stop {name:$destStation})<-[:LOCATED_AT]-(st_dest:Stoptime)-[r2:PART_OF_TRIP]->(trp2:Trip),\n" +
            "    p1=(st_orig)-[im1:PRECEDES*]->(st_midway_arr:Stoptime),\n"+
            "    p5=(st_midway_arr)-[:LOCATED_AT]->(midway:Stop)<-[:LOCATED_AT]-(st_midway_dep:Stoptime),\n" +
            "    p2=(st_midway_dep)-[im2:PRECEDES*]->(st_dest)\n" +
            "WHERE\n" +
            "  st_orig.departure_time > $origArrivalTimeLow\n" +
            "  AND st_orig.departure_time < $origArrivalTimeHigh\n" +
            "  AND st_dest.arrival_time < $destArrivalTimeHigh\n" +
            "  AND st_dest.arrival_time > $destArrivalTimeLow\n" +
            "  AND st_midway_arr.arrival_time > st_orig.departure_time\n"+
            "  AND st_midway_dep.departure_time > st_midway_arr.arrival_time\n" +
            "  AND st_dest.arrival_time > st_midway_dep.departure_time\n" +
            "  AND trp1.service_id = cd.service_id\n" +
            "  AND trp2.service_id = cd.service_id\n" +
            "WITH\n"+
            "  st_orig, st_dest, nodes(p1) + nodes(p2) AS allStops1\n" +
            "ORDER BY\n" +
            "    (st_dest.arrival_time_int-st_orig.departure_time_int) ASC\n" +
            "SKIP $skip LIMIT 1\n" +
            "UNWIND\n" +
            "  allStops1 AS stoptime\n" +
            "MATCH\n" +
            "  p6=(loc:Stop)<-[r:LOCATED_AT]-(stoptime)-[r2:PART_OF_TRIP]->(trp5:Trip),\n" +
            "  (stoptime)-[im1:PRECEDES*]->(stoptime2)\n" +
            "RETURN\n" +
            "  p6\n" +
            "ORDER BY stoptime.departure_time_int ASC\n" +
            ";")
    <T> List<T> getMyTripsOneStop(
                                        @Param("travelDate") String travelDate,
                                        @Param("origStation") String origStation,
                                        @Param("origArrivalTimeLow") String origArrivalTimeLow,
                                        @Param("origArrivalTimeHigh") String origArrivalTimeHigh,
                                        @Param("destStation") String destStation,
                                        @Param("destArrivalTimeLow") String destArrivalTimeLow,
                                        @Param("destArrivalTimeHigh")String destArrivalTimeHigh,
                                        @Param("skip")Long skip,
                                        Class<T> type
                                    );

    @Query("MATCH (s:Stoptime)-[*1..$depth]-(related) WHERE id(s) = $id RETURN s, collect(related)")
    Optional<Stoptime> findByIdWithDepth(@Param("id") Long id, @Param("depth") int depth);

}


