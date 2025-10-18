package it.edu.pk.ztdbbackend.api;

import lombok.Data;

@Data
public class NonDirectTripPlan {
    private String destination;
    private String origin;
    private String departureAfter;
    private String departureBefore;
}
