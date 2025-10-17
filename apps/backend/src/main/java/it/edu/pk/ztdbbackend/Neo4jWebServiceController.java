package it.edu.pk.ztdbbackend;

import it.edu.pk.ztdbbackend.api.CalculatedResponse;
import it.edu.pk.ztdbbackend.api.MergedResponse;
import it.edu.pk.ztdbbackend.api.TimeTakenResponse;
import it.edu.pk.ztdbbackend.entity.*;
import it.edu.pk.ztdbbackend.repository.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Set;

@Slf4j
@RestController
@RequestMapping("/api")
public class Neo4jWebServiceController {
    @Autowired
    AgencyRepository agencyRepository;

    @Autowired
    RouteRepository routeRepository;

    @Autowired
    StopRepository stopRepository;

    @Autowired
    StoptimeRepository stoptimeRepository;

    @Autowired
    CalendarDateRepository calendarDateRepository;

    @Autowired
    TripRepository tripRepository;


    @GetMapping(path = "/agency/{agencyId}", produces = MediaType.APPLICATION_JSON_UTF8_VALUE)
    @ResponseBody
    //Example id: NJT
    public Agency getAgency(@PathVariable String agencyId, Model model) {
        return agencyRepository.findByAgencyIdWithDepth(agencyId,1);
    }

    @GetMapping(path = "/agency/{agencyId}/routes", produces = MediaType.APPLICATION_JSON_UTF8_VALUE)
    @ResponseBody
    //Example id: NJT
    public Set<Route> getAgencyRoutes(@PathVariable String agencyId, Model model) {
        Agency agency = agencyRepository.findByAgencyIdWithDepth(agencyId,1);
        return agency.routes;
    }

    @GetMapping(path = "/route/{routeId}", produces = MediaType.APPLICATION_JSON_UTF8_VALUE)
    @ResponseBody
    //Example id: 13
    public Route getRoute(@PathVariable String routeId, Model model) {
        return routeRepository.findByRouteIdWithDepth(routeId,1);
    }

    @GetMapping(path = "/stop/{stopName}", produces = MediaType.APPLICATION_JSON_UTF8_VALUE)
    @ResponseBody
    //Example name: WESTWOOD
    public Stop getStop(@PathVariable String stopName, Model model) {
        return stopRepository.findByNameWithDepth(stopName,1);
    }

    @GetMapping(path = "/stoptime/{id}", produces = MediaType.APPLICATION_JSON_UTF8_VALUE)
    @ResponseBody
    //Example id: 1270015
    public Stoptime getStopTime(@PathVariable Long id, Model model) {
        return stoptimeRepository.findByIdWithDepth(id, 1).get();

    }

    @GetMapping(path = "/trip/{tripId}", produces = MediaType.APPLICATION_JSON_UTF8_VALUE)
    @ResponseBody
    //Example id: 22
    public Trip getTrip(@PathVariable String tripId, Model model) {
        return tripRepository.findByTripIdWithDepth(tripId, 1);

    }

    @PostMapping("/load")
    @ResponseBody
    public TimeTakenResponse grabAndLoad() {

        long startTime = System.currentTimeMillis();
        log.info("Loading data from fetched zip file");
        agencyRepository.deleteAll();
        routeRepository.deleteAll();
        stopRepository.deleteAll();
        stoptimeRepository.deleteAll();
        tripRepository.deleteAll();
        calendarDateRepository.deleteAll();

        log.info("Loading agency");
        agencyRepository.loadNodes();

        log.info("Loading routes");
        routeRepository.loadNodes();

        log.info("Loading trips");
        tripRepository.loadNodes();

        log.info("Loading calendar dates");
        calendarDateRepository.loadNodes();

        log.info("Loading stops");
        stopRepository.addStops();

        log.info("Loading stoptimes");
        stopRepository.connectParentChild();

        log.info("Loading stoptimes");
        stoptimeRepository.addStopTimes();

        log.info("Stoptimes to int");
        stoptimeRepository.stopTimeToInt();

        log.info("Connecting stopSequences");
        stoptimeRepository.connectSequences();

        long endTime = System.currentTimeMillis();
        return new TimeTakenResponse(endTime - startTime, "GTFS data loading to Neo4j");
    }

    @PostMapping(value = "/trip/direct")
    public MergedResponse<List<TripProjection>, List<TripProjection>> planTripNoTransfer(@RequestBody TripPlan plan){
        long startTime = System.currentTimeMillis();
        var result = stoptimeRepository.getMyTrips(
                plan.getTravelDate(),
                plan.getOrigStation(),
                plan.getOrigArrivalTimeLow(),
                plan.getOrigArrivalTimeHigh(),
                plan.getDestStation(),
                plan.getDestArrivalTimeLow(),
                plan.getDestArrivalTimeHigh(),
                0, 100);

        long endTime = System.currentTimeMillis();

        return MergedResponse.<List<TripProjection>, List<TripProjection>>builder()
                .neo4jData(CalculatedResponse.of(result, endTime-startTime, "Trip plan connection for neo4j between " + plan.getOrigStation() + " and " + plan.getDestStation()))
                .neo4jData(CalculatedResponse.of(List.of(), 0, "Trip plan connection for postgresql between " + plan.getOrigStation() + " and " + plan.getDestStation()))
                .build();
    }

    @PostMapping(value = "/trip/nondirect")
    public MergedResponse<List<TripProjection>, List<TripProjection>>  planTripNonDirect(@RequestBody TripPlan plan){
        long startTime = System.currentTimeMillis();
        var result = stoptimeRepository.getMyTrips(
                plan.getTravelDate(),
                plan.getOrigStation(),
                plan.getOrigArrivalTimeLow(),
                plan.getOrigArrivalTimeHigh(),
                plan.getDestStation(),
                plan.getDestArrivalTimeLow(),
                plan.getDestArrivalTimeHigh(),
                0, 100);

        long endTime = System.currentTimeMillis();

        return MergedResponse.<List<TripProjection>, List<TripProjection>>builder()
                .neo4jData(CalculatedResponse.of(result, endTime-startTime, "Trip plan connection for neo4j between " + plan.getOrigStation() + " and " + plan.getDestStation()))
                .neo4jData(CalculatedResponse.of(List.of(), 0, "Trip plan connection for postgresql between " + plan.getOrigStation() + " and " + plan.getDestStation()))
                .build();
    }

}
