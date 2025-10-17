package it.edu.pk.ztdbbackend.api;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class TimeTakenResponse {
    private long seconds;
    private String description;
}
