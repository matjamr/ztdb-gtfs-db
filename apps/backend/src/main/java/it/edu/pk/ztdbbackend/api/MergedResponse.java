package it.edu.pk.ztdbbackend.api;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class MergedResponse<T, R> {
    CalculatedResponse<T> neo4jData;
    CalculatedResponse<R> postgresData;
}
