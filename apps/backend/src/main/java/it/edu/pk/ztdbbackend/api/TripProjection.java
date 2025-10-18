package it.edu.pk.ztdbbackend.api;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class TripProjection {
        private String startStop;
        private String startDeparture;
        private String tripId;
        private String endStop;
        private String endArrival;
        private Long travelTimeMinutes;
}
