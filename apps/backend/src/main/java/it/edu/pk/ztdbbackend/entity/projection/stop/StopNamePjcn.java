package it.edu.pk.ztdbbackend.entity.projection.stop;

import it.edu.pk.ztdbbackend.entity.Stop;
import org.springframework.data.rest.core.config.Projection;

@Projection(name = "StopName", types = { Stop.class })
public interface StopNamePjcn {
    public String getName();
}
