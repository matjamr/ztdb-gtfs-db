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

    @Query("""
        WITH $stopA AS stopA,
             $stopB AS stopB,
             $departureAfter AS departure_after,
             $departureBefore AS departure_before
        
        // Stops from A
        MATCH (a:Stop {name: stopA})<-[:LOCATED_AT]-(st_a:Stoptime)-[:PART_OF_TRIP]->(trip_a:Trip)
        MATCH (st_a)-[:PRECEDES*0..30]->(st_mid_a:Stoptime)-[:LOCATED_AT]->(mid:Stop)
        WITH stopA, stopB, departure_after, departure_before, collect(DISTINCT mid.name) AS stops_from_A
        
        // Stops from B
        MATCH (b:Stop {name: stopB})<-[:LOCATED_AT]-(st_b:Stoptime)
        MATCH (st_mid_b:Stoptime)-[:PART_OF_TRIP]->(trip_b:Trip)
        MATCH (st_mid_b)-[:PRECEDES*0..30]->(st_b)
        MATCH (st_mid_b)-[:LOCATED_AT]->(mid2:Stop)
        WITH stopA, stopB, departure_after, departure_before, stops_from_A, collect(DISTINCT mid2.name) AS stops_to_B
        
        // Common Stops
        WITH stopA, stopB, departure_after, departure_before,
             [s IN stops_from_A WHERE s IN stops_to_B] AS common_stops
        
        // Find connections through each common stop
        UNWIND common_stops AS transfer_stop
        
        MATCH (cd:CalendarDate)
        MATCH (orig:Stop {name: stopA})<-[:LOCATED_AT]-(st_orig:Stoptime)-[:PART_OF_TRIP]->(trip:Trip),
              (st_orig)-[:PRECEDES*1..50]->(st_dest:Stoptime)-[:LOCATED_AT]->(dest:Stop {name: transfer_stop})
          WHERE trip.service_id = cd.service_id
          AND st_orig.departure_time > departure_after
          AND st_orig.departure_time < departure_before
          AND st_dest.arrival_time_int > st_orig.departure_time_int
        
        // Now find second leg from transfer to destination
        MATCH (transfer:Stop {name: transfer_stop})<-[:LOCATED_AT]-(st_transfer:Stoptime)-[:PART_OF_TRIP]->(trip2:Trip),
              (st_transfer)-[:PRECEDES*1..50]->(st_final:Stoptime)-[:LOCATED_AT]->(final:Stop {name: stopB})
          WHERE trip2.service_id = cd.service_id
          AND st_transfer.departure_time_int >= st_dest.arrival_time_int
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
}


