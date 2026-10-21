package com.ironfit.exception;

import org.springframework.http.HttpStatus;

/** Erreur métier renvoyée au client avec un code HTTP et un message lisible (en français). */
public class ApiException extends RuntimeException {
    private final HttpStatus status;

    public ApiException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    public HttpStatus getStatus() { return status; }

    public static ApiException badRequest(String message) { return new ApiException(HttpStatus.BAD_REQUEST, message); }
    public static ApiException notFound(String message) { return new ApiException(HttpStatus.NOT_FOUND, message); }
    public static ApiException conflict(String message) { return new ApiException(HttpStatus.CONFLICT, message); }
    public static ApiException forbidden(String message) { return new ApiException(HttpStatus.FORBIDDEN, message); }
    public static ApiException forbidden() { return forbidden("Action non autorisée"); }
    public static ApiException unauthorized(String message) { return new ApiException(HttpStatus.UNAUTHORIZED, message); }
    public static ApiException tooManyRequests() { return new ApiException(HttpStatus.TOO_MANY_REQUESTS, "Trop de tentatives, réessayez dans une minute"); }
}
