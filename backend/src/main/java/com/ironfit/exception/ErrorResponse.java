package com.ironfit.exception;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.time.Instant;
import java.util.Map;

/**
 * Format unique des erreurs : {"error": "...", "status": 400, "timestamp": "...", "fields": {...}}.
 * L'application Flutter affiche le champ « error ».
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ErrorResponse(String error, int status, Instant timestamp, Map<String, String> fields) {
    public static ErrorResponse of(int status, String error) { return new ErrorResponse(error, status, Instant.now(), null); }
}
