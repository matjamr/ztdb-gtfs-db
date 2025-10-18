package it.edu.pk.ztdbbackend.entity;

import lombok.Data;
import org.springframework.data.neo4j.core.schema.Id;
import org.springframework.data.neo4j.core.schema.Node;
import org.springframework.data.neo4j.core.schema.Property;

@Node
@Data
public class Stop {

    @Property(name="name")
    private String name;

    @Property(name="lon")
    private double longitude;

    @Property(name="lat")
    private double latitude;

    @Id
    @Property(name="id")
    private String stopId;

}
