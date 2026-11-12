package com.ironfit.service.impl;

import com.ironfit.service.MailService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

/**
 * E-mails en texte brut. Spring ne crée le JavaMailSender que si {@code spring.mail.host} est défini :
 * sinon l'envoi est ignoré et la raison est renvoyée / journalisée.
 */
@Service
public class MailServiceImpl implements MailService {
    private static final Logger log = LoggerFactory.getLogger(MailServiceImpl.class);

    private final ObjectProvider<JavaMailSender> sender;
    private final String from;

    public MailServiceImpl(ObjectProvider<JavaMailSender> sender, @Value("${ironfit.mail.from:no-reply@ironfit.local}") String from) {
        this.sender = sender;
        this.from = from;
    }

    @Override
    @Async
    public void send(String to, String subject, String text) {
        sendNow(to, subject, text);   // le résultat est journalisé par sendNow
    }

    @Override
    public String sendNow(String to, String subject, String text) {
        JavaMailSender mailer = sender.getIfAvailable();
        if (mailer == null) {
            String why = "SMTP non configuré : backend/.env introuvable ou sans spring.mail.host (le backend doit être lancé depuis le dossier backend, puis redémarré)";
            log.warn("E-mail « {} » NON envoyé : {}", subject, why);
            return why;
        }
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(from);
            message.setTo(to);
            message.setSubject(subject);
            message.setText(text);
            mailer.send(message);
            log.info("E-mail « {} » envoyé à {}", subject, mask(to));
            return null;
        } catch (Exception e) {
            // Un échec d'e-mail ne doit jamais faire échouer l'action métier
            Throwable root = e;
            while (root.getCause() != null && root.getCause() != root) root = root.getCause();
            String why = e.getClass().getSimpleName() + " : " + (root.getMessage() == null ? e.getMessage() : root.getMessage());
            if (why.length() > 220) why = why.substring(0, 220) + "…";
            log.warn("Échec d'envoi de l'e-mail « {} » à {} : {}", subject, mask(to), why);
            return why;
        }
    }

    /** h***@gmail.com : l'adresse complète n'est pas écrite dans les journaux. */
    private static String mask(String email) {
        int at = email == null ? -1 : email.indexOf('@');
        return at < 1 ? "?" : email.charAt(0) + "***" + email.substring(at);
    }
}
