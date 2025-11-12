package it.edu.pk.ztdbbackend.entity;

import lombok.Data;
import lombok.EqualsAndHashCode;
import org.springframework.data.neo4j.core.schema.Property;
import org.springframework.data.neo4j.core.schema.Id;
import org.springframework.data.neo4j.core.schema.Node;
import org.springframework.data.neo4j.core.schema.Relationship;

import java.util.Set;


@Node
@Data
@EqualsAndHashCode(onlyExplicitlyIncluded = true)
public class Stoptime {
    @Id
    @EqualsAndHashCode.Include
    private Long id;

    @Property(name="arrival_time")
    private String arrivalTime;

    @Property(name="stop_sequence")
    private int stopSequence;

    @Property(name="departure_time_int")
    private int departureTimeInt;

    @Property(name="arrival_time_int")
    private int arrivalTimeInt;

    @Property(name="departure_time")
    private String departureTime;

    @Relationship(type = "STOPTIME_STOP", direction = Relationship.Direction.OUTGOING)
    private Set<Stop> stops;

    @Relationship(type = "STOPTIME_TRIP")
    public Set<Trip> trips;

}
