package com.ironfit.retention;

import com.ironfit.service.RetentionService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Analyse automatique des membres à risque, chaque jour à 8 h par défaut (ironfit.retention.cron).
 * Désactivable avec ironfit.retention.enabled=false (c'est le cas dans les tests).
 */
@Component
@ConditionalOnProperty(prefix = "ironfit.retention", name = "enabled", havingValue = "true", matchIfMissing = true)
public class RetentionJob {
    private static final Logger log = LoggerFactory.getLogger(RetentionJob.class);

    private final RetentionService retention;

    public RetentionJob(RetentionService retention) { this.retention = retention; }

    @Scheduled(cron = "${ironfit.retention.cron:0 0 8 * * *}")
    public void nightly() {
        try {
            retention.runNightly();
        } catch (Exception e) {
            log.error("Analyse de rétention en échec", e);   // ne jamais laisser une exception tuer la planification
        }
    }
}
