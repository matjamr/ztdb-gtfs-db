package it.edu.pk.ztdbbackend.repository;

import it.edu.pk.ztdbbackend.api.TripOneStopProjection;
import it.edu.pk.ztdbbackend.api.TripProjection;
import it.edu.pk.ztdbbackend.entity.Stoptime;
import org.springframework.data.neo4j.repository.Neo4jRepository;
import org.springframework.data.neo4j.repository.query.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface StoptimeRepository extends Neo4jRepository<Stoptime, Long> {


    @Query("//add the stoptimes \n" +
            "CALL apoc.periodic.iterate(\n" +
            "  'LOAD CSV WITH HEADERS FROM \"file:///stop_times.txt\" AS csv RETURN csv',\n" +
            "  'MATCH (t:Trip {id: csv.trip_id}) MATCH (s:Stop {id: csv.stop_id}) CREATE (st:Stoptime {arrival_time: csv.arrival_time, departure_time: csv.departure_time, stop_sequence: toInteger(csv.stop_sequence)})-[:STOPTIME_TRIP]->(t), (st)-[:STOPTIME_STOP]->(s)',\n" +
            "  {batchSize: 1000, parallel: false}\n" +
            ") YIELD batches RETURN batches")
    Long addStopTimes();

    @Query( "//create integers out of the stoptimes (to allow for calculations/ordering)\n" +
            "CALL apoc.periodic.iterate(\n" +
            "  'MATCH (s:Stoptime) RETURN s',\n" +
            "  'SET s.arrival_time_int=toInteger(replace(s.arrival_time, \\\":\\\" , \\\"\\\"))/100, s.departure_time_int=toInteger(replace(s.departure_time, \\\":\\\" , \\\"\\\"))/100',\n" +
            "  {batchSize: 1000, parallel: false}\n" +
            ") YIELD batches RETURN batches")
    Long stopTimeToInt();

    @Query(
            "//connect the stoptime sequences\n" +
            "CALL apoc.periodic.iterate(\n" +
            "  'MATCH (s1:Stoptime)-[:STOPTIME_TRIP]->(t:Trip), (s2:Stoptime)-[:STOPTIME_TRIP]->(t) WHERE s2.stop_sequence=s1.stop_sequence + 1 RETURN s1, s2',\n" +
            "  'CREATE (s1)-[:PRECEDES]->(s2)',\n" +
            "  {batchSize: 1000, parallel: false}\n" +
            ") YIELD batches RETURN batches")
    Long connectSequences();


    @Query(
            value="""
                WITH $travelDate AS travelDate,
                     date(
                       toInteger(substring(travelDate, 0, 4)),
                       toInteger(substring(travelDate, 4, 2)),
                       toInteger(substring(travelDate, 6, 2))
                     ) AS targetDate,
                     (duration.between(date('1970-01-05'), date(
                       toInteger(substring(travelDate, 0, 4)),
                       toInteger(substring(travelDate, 4, 2)),
                       toInteger(substring(travelDate, 6, 2))
                     )).days % 7) AS dayOfWeek

                MATCH
                  (st_orig:Stoptime)-[:STOPTIME_STOP]->(orig:Stop {name: $origStation}),
                  (st_orig)-[:STOPTIME_TRIP]->(trip:Trip),
                  (st_orig)-[:PRECEDES*1..50]->(st_dest:Stoptime)-[:STOPTIME_STOP]->(dest:Stop {name: $destStation})
                OPTIONAL MATCH (trip)-[:TRIP_CALENDAR]->(c:Calendar)
                WHERE
                  (c IS NOT NULL 
                   AND travelDate >= c.start_date 
                   AND travelDate <= c.end_date
                   AND CASE dayOfWeek
                     WHEN 0 THEN c.monday
                     WHEN 1 THEN c.tuesday
                     WHEN 2 THEN c.wednesday
                     WHEN 3 THEN c.thursday
                     WHEN 4 THEN c.friday
                     WHEN 5 THEN c.saturday
                     WHEN 6 THEN c.sunday
                   END = true)
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

    @Query("""
        WITH $stopA AS stopA,
             $stopB AS stopB,
             $departureAfter AS departure_after,
             $departureBefore AS departure_before
        
        // Stops from A
        MATCH (st_a:Stoptime)-[:STOPTIME_STOP]->(a:Stop {name: stopA})
        MATCH (st_a)-[:STOPTIME_TRIP]->(trip_a:Trip)
        MATCH (st_a)-[:PRECEDES*0..30]->(st_mid_a:Stoptime)-[:STOPTIME_STOP]->(mid:Stop)
        WITH stopA, stopB, departure_after, departure_before, collect(DISTINCT mid.name) AS stops_from_A
        
        // Stops from B
        MATCH (st_b:Stoptime)-[:STOPTIME_STOP]->(b:Stop {name: stopB})
        MATCH (st_mid_b:Stoptime)-[:STOPTIME_TRIP]->(trip_b:Trip)
        MATCH (st_mid_b)-[:PRECEDES*0..30]->(st_b)
        MATCH (st_mid_b)-[:STOPTIME_STOP]->(mid2:Stop)
        WITH stopA, stopB, departure_after, departure_before, stops_from_A, collect(DISTINCT mid2.name) AS stops_to_B
        
        // Common Stops
        WITH stopA, stopB, departure_after, departure_before,
             [s IN stops_from_A WHERE s IN stops_to_B] AS common_stops
        
        // Find connections through each common stop
        UNWIND common_stops AS transfer_stop
        
        MATCH (st_orig:Stoptime)-[:STOPTIME_STOP]->(orig:Stop {name: stopA}),
              (st_orig)-[:STOPTIME_TRIP]->(trip:Trip),
              (st_orig)-[:PRECEDES*1..50]->(st_dest:Stoptime)-[:STOPTIME_STOP]->(dest:Stop {name: transfer_stop})
          WHERE st_orig.departure_time > departure_after
          AND st_orig.departure_time < departure_before
          AND st_dest.arrival_time_int > st_orig.departure_time_int
        
        // Now find second leg from transfer to destination
        MATCH (st_transfer:Stoptime)-[:STOPTIME_STOP]->(transfer:Stop {name: transfer_stop}),
              (st_transfer)-[:STOPTIME_TRIP]->(trip2:Trip),
              (st_transfer)-[:PRECEDES*1..50]->(st_final:Stoptime)-[:STOPTIME_STOP]->(final:Stop {name: stopB})
          WHERE st_transfer.departure_time_int >= st_dest.arrival_time_int
          AND st_final.arrival_time_int > st_transfer.departure_time_int
        
        RETURN
          orig.name AS startStop,
          st_orig.departure_time AS startDeparture,
          dest.name AS transferStop,
          st_dest.arrival_time AS arrivalAtTransfer,
          st_transfer.departure_time AS departureFromTransfer,
          final.name AS endStop,
          st_final.arrival_time AS endArrival,
          trip.id AS firstTripId,
          trip2.id AS secondTripId,
          (st_dest.arrival_time_int - st_orig.departure_time_int) / 60 AS firstLegMinutes,
          (st_final.arrival_time_int - st_transfer.departure_time_int) / 60 AS secondLegMinutes,
          ((st_final.arrival_time_int - st_orig.departure_time_int) / 60) AS totalTravelMinutes
        ORDER BY totalTravelMinutes ASC
        """)
    List<TripOneStopProjection> findTripsWithOneTransfer(
            @Param("stopA") String stopA,
            @Param("stopB") String stopB,
            @Param("departureAfter") String departureAfter,
            @Param("departureBefore") String departureBefore
    );
    
    @Query("""
        WITH $travelDate AS travelDate,
             CASE 
               WHEN travelDate IS NULL THEN null
               ELSE (duration.between(date('1970-01-05'), date(
                 toInteger(substring(travelDate, 0, 4)),
                 toInteger(substring(travelDate, 4, 2)),
                 toInteger(substring(travelDate, 6, 2))
               )).days % 7)
             END AS dayOfWeek
        MATCH (st:Stoptime)-[:STOPTIME_STOP]->(s:Stop {name: $stopName})
        MATCH (st)-[:STOPTIME_TRIP]->(t:Trip)
        OPTIONAL MATCH (t)-[:TRIP_CALENDAR]->(c:Calendar)
        WHERE (travelDate IS NULL OR 
               (c IS NOT NULL 
                AND travelDate >= c.start_date 
                AND travelDate <= c.end_date
                AND CASE dayOfWeek
                  WHEN 0 THEN c.monday
                  WHEN 1 THEN c.tuesday
                  WHEN 2 THEN c.wednesday
                  WHEN 3 THEN c.thursday
                  WHEN 4 THEN c.friday
                  WHEN 5 THEN c.saturday
                  WHEN 6 THEN c.sunday
                END = true))
        RETURN
          s.name AS stopName,
          t.id AS tripId,
          st.arrival_time AS arrivalTime,
          st.departure_time AS departureTime
        ORDER BY st.departure_time_int ASC
        SKIP $skip
        LIMIT $limit
    """)
    List<it.edu.pk.ztdbbackend.api.TripsAtStopProjection> findTripsAtStop(
            @Param("stopName") String stopName,
            @Param("travelDate") String travelDate,
            @Param("skip") int skip,
            @Param("limit") int limit
    );
}


