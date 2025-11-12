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
public class Trip {

    @Id
    @Property(name="id")
    @EqualsAndHashCode.Include
    private String tripId;

    @Property(name="service_id")
    private String serviceId;

    @Relationship(type = "TRIP_ROUTE")
    public Set<Route> routes;

    @Relationship(type = "STOPTIME_TRIP", direction = Relationship.Direction.INCOMING)
    public Set<Stoptime> stoptimes;

    @Relationship(type = "TRIP_SERVICE")
    public Set<CalendarDate> calendarDates;

    @Relationship(type = "TRIP_CALENDAR")
    public Set<Calendar> calendars;

}
