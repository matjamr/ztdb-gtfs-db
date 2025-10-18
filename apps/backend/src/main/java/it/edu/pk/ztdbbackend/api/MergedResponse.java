package it.edu.pk.ztdbbackend.api;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class MergedResponse<T, R> {
    CalculatedResponse<T> neo4jData;
    CalculatedResponse<R> postgresData;
}
