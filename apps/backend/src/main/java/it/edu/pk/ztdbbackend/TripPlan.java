package it.edu.pk.ztdbbackend;

import lombok.Data;

@Data
public class TripPlan {
    private String travelDate;
    private String origStation;
    private String origArrivalTimeLow;
    private String origArrivalTimeHigh;
    private String destStation;
    private String destArrivalTimeLow;
    private String destArrivalTimeHigh;
}
