package it.edu.pk.ztdbbackend.entity;

import lombok.Data;
import org.springframework.data.neo4j.core.schema.Id;
import org.springframework.data.neo4j.core.schema.Node;
import org.springframework.data.neo4j.core.schema.Property;
import org.springframework.data.neo4j.core.schema.Relationship;

import java.util.Set;

@Node
@Data
public class Calendar {

    @Id
    @Property(name="id")
    private Long id;

    @Property(name="service_id")
    private String serviceId;

    @Property(name="monday")
    private boolean monday;

    @Property(name="tuesday")
    private boolean tuesday;

    @Property(name="wednesday")
    private boolean wednesday;

    @Property(name="thursday")
    private boolean thursday;

    @Property(name="friday")
    private boolean friday;

    @Property(name="saturday")
    private boolean saturday;

    @Property(name="sunday")
    private boolean sunday;

    @Property(name="start_date")
    private String startDate;

    @Property(name="end_date")
    private String endDate;

    @Relationship(type = "TRIP_CALENDAR", direction = Relationship.Direction.INCOMING)
    public Set<Trip> trips;
}

