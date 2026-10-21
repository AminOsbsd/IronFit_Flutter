package com.ironfit.config;

import com.fasterxml.jackson.databind.cfg.CoercionAction;
import com.fasterxml.jackson.databind.cfg.CoercionInputShape;
import org.springframework.boot.autoconfigure.jackson.Jackson2ObjectMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Une chaîne vide envoyée par un formulaire (« ») est lue comme null pour les nombres, dates et identifiants. */
@Configuration
public class JacksonConfig {
    @Bean
    public Jackson2ObjectMapperBuilderCustomizer emptyStringsAsNull() {
        return builder -> builder.postConfigurer(mapper ->
                mapper.coercionConfigDefaults().setCoercion(CoercionInputShape.EmptyString, CoercionAction.AsNull));
    }
}
