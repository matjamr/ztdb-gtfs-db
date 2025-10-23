package it.edu.pk.ztdbbackend.api;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class TripsAtStopProjection {
    private String stopName;
    private String tripId;
    private String arrivalTime;
    private String departureTime;
}