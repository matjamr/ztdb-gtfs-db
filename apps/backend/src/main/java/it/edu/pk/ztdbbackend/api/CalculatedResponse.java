package it.edu.pk.ztdbbackend.api;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class CalculatedResponse<T> {
    private T data;
    private long seconds;
    private String description;

    public static <T> CalculatedResponse<T> of(T result, long l, String description) {
        return new  CalculatedResponse<>(result, l, null);
    }
}
