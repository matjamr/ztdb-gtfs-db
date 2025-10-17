package it.edu.pk.ztdbbackend.entity.projection.stoptime;

import it.edu.pk.ztdbbackend.entity.Stoptime;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.rest.core.config.Projection;

@Projection(name = "TripPlanResult", types = { Stoptime.class })
public interface TripPlanResultPjcn {

    public String getArrivalTime();
    public String getDepartureTime();
    public int getStopSequence();

    @Value("#{target.stops.iterator().next().getName()}")
    public String getStopName();

    //public Set<StopNamePjcn> getStops();

    @Value("#{target.trips.iterator().next().getTripId()}")
    public String getTripId();

    //Set<TripNoBackrefsPjcn> getTrips();
}
