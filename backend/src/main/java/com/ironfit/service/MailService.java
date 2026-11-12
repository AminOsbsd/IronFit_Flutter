package com.ironfit.service;

/** Envoi d'e-mails. Sans serveur SMTP configuré, l'envoi est simplement ignoré (journalisé). */
public interface MailService {
    /** Envoi en arrière-plan (copie des notifications) : ne bloque pas la requête et ne signale pas d'erreur. */
    void send(String to, String subject, String text);

    /** Envoi immédiat. Renvoie null si l'e-mail est parti, sinon la raison de l'échec (affichable à l'utilisateur). */
    String sendNow(String to, String subject, String text);

    /** Adresse utilisable : renseignée et non factice (les comptes de démo ont une adresse en @ironfit.local). */
    static boolean isRealAddress(String email) {
        return email != null && email.contains("@") && !email.toLowerCase().endsWith("@ironfit.local");
    }
}
