package it.edu.pk.ztdbbackend.entity.projection.trip;

import it.edu.pk.ztdbbackend.entity.Trip;
import org.springframework.data.rest.core.config.Projection;

@Projection(name = "TripNoBackrefs", types = { Trip.class })
public interface TripNoBackrefsPjcn {

    public String getTripId();
}
