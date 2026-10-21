package com.ironfit.exception;

import com.fasterxml.jackson.databind.exc.InvalidFormatException;
import com.fasterxml.jackson.databind.exc.MismatchedInputException;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authorization.AuthorizationDeniedException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

/** Transforme toutes les erreurs en JSON {@link ErrorResponse}, sans exposer de détail technique au client. */
@RestControllerAdvice
public class GlobalExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    private static ResponseEntity<ErrorResponse> reply(HttpStatus status, String message) {
        return ResponseEntity.status(status).body(ErrorResponse.of(status.value(), message));
    }

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ErrorResponse> api(ApiException e) { return reply(e.getStatus(), e.getMessage()); }

    /** @Valid : le premier message sert de message principal, tous les champs sont détaillés dans « fields ». */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> invalid(MethodArgumentNotValidException e) {
        Map<String, String> fields = new LinkedHashMap<>();
        for (FieldError f : e.getBindingResult().getFieldErrors()) fields.putIfAbsent(f.getField(), f.getDefaultMessage());
        String first = fields.isEmpty() ? "Requête invalide" : fields.values().iterator().next();
        return ResponseEntity.badRequest().body(new ErrorResponse(first, 400, Instant.now(), fields));
    }

    /** JSON mal formé ou valeur du mauvais type (ex. « abc » pour un poids). */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> unreadable(HttpMessageNotReadableException e) {
        if (e.getCause() instanceof MismatchedInputException m && !m.getPath().isEmpty()) {
            String field = m.getPath().get(m.getPath().size() - 1).getFieldName();
            if (field != null) return reply(HttpStatus.BAD_REQUEST, "Valeur invalide : " + field);
        }
        if (e.getCause() instanceof InvalidFormatException) return reply(HttpStatus.BAD_REQUEST, "Valeur invalide");
        return reply(HttpStatus.BAD_REQUEST, "JSON invalide");
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ErrorResponse> typeMismatch(MethodArgumentTypeMismatchException e) {
        return reply(HttpStatus.BAD_REQUEST, "Paramètre invalide : " + e.getName());
    }

    @ExceptionHandler({AccessDeniedException.class, AuthorizationDeniedException.class})
    public ResponseEntity<ErrorResponse> denied(RuntimeException e) { return reply(HttpStatus.FORBIDDEN, "Action non autorisée"); }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ErrorResponse> integrity(DataIntegrityViolationException e) {
        String msg = String.valueOf(e.getMostSpecificCause().getMessage()).toLowerCase();
        if (msg.contains("duplicate") || msg.contains("unique")) return reply(HttpStatus.CONFLICT, "Identifiant ou e-mail déjà utilisé");
        log.warn("Contrainte de base de données violée : {}", e.getMostSpecificCause().getClass().getSimpleName());
        return reply(HttpStatus.CONFLICT, "Opération impossible : données liées incohérentes");
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ErrorResponse> method(HttpRequestMethodNotSupportedException e) { return reply(HttpStatus.METHOD_NOT_ALLOWED, "Route inconnue"); }

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ErrorResponse> notFound(NoResourceFoundException e) { return reply(HttpStatus.NOT_FOUND, "Route inconnue"); }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> unexpected(Exception e, HttpServletRequest req) {
        log.error("Erreur inattendue sur {} {}", req.getMethod(), req.getRequestURI(), e);
        return reply(HttpStatus.INTERNAL_SERVER_ERROR, "Erreur serveur");
    }
}
