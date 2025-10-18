package it.edu.pk.ztdbbackend.api;

import lombok.AllArgsConstructor;
import lombok.Data;

@AllArgsConstructor
@Data
public class TripOneStopProjection {

    private String startStop;
    private String startDeparture;
    private String transferStop;
    private String arrivalAtTransfer;
    private String departureFromTransfer;
    private String endStop;
    private String endArrival;
    private String firstTripId;
    private String secondTripId;
    private Integer firstLegMinutes;
    private Integer secondLegMinutes;
    private Integer totalTravelMinutes;
}
