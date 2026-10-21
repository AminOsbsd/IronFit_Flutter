package com.ironfit;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/**
 * Point d'entrée de l'API IronFit (Spring Boot + MySQL).
 * Pas de comptes en mémoire : l'authentification passe uniquement par les jetons JWT.
 */
@SpringBootApplication(exclude = UserDetailsServiceAutoConfiguration.class)
@ConfigurationPropertiesScan
public class IronFitApplication {
    public static void main(String[] args) {
        SpringApplication.run(IronFitApplication.class, args);
    }
}
