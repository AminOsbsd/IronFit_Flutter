package com.ironfit.service.impl;

import com.ironfit.config.AppProperties;
import com.ironfit.dto.UserDtos.*;
import com.ironfit.entity.PasswordReset;
import com.ironfit.entity.Role;
import com.ironfit.entity.User;
import com.ironfit.exception.ApiException;
import com.ironfit.repository.PasswordResetRepository;
import com.ironfit.repository.UserRepository;
import com.ironfit.security.CurrentUser;
import com.ironfit.security.JwtService;
import com.ironfit.service.AccessService;
import com.ironfit.service.AuthService;
import com.ironfit.service.Texts;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class AuthServiceImpl implements AuthService {
    private static final Logger log = LoggerFactory.getLogger(AuthServiceImpl.class);
    private static final String BAD_CREDENTIALS = "Identifiant ou mot de passe incorrect";
    private static final String BAD_CODE = "Code invalide ou expiré";
    private static final String PASSWORD_RULE = "Mot de passe : 6 caractères minimum";

    private final UserRepository users;
    private final PasswordResetRepository resets;
    private final PasswordEncoder encoder;
    private final JwtService jwt;
    private final AccessService access;
    private final AppProperties props;
    private final SecureRandom random = new SecureRandom();
    /** Hachage factice : la connexion prend le même temps que l'identifiant existe ou non. */
    private final String dummyHash;

    public AuthServiceImpl(UserRepository users, PasswordResetRepository resets, PasswordEncoder encoder, JwtService jwt,
                           AccessService access, AppProperties props) {
        this.users = users;
        this.resets = resets;
        this.encoder = encoder;
        this.jwt = jwt;
        this.access = access;
        this.props = props;
        this.dummyHash = encoder.encode("ironfit-dummy-password");
    }

    private AuthResponse session(User u) { return new AuthResponse(jwt.issue(u), UserDto.of(u)); }

    private static void passwordRule(String p) {
        if (p == null || p.length() < 6 || p.length() > 200) throw ApiException.badRequest(PASSWORD_RULE);
    }

    @Override
    public AuthResponse signup(SignupRequest req) {
        String login = req.login().trim(), email = req.email().trim();
        if (users.existsByLoginIgnoreCase(login) || users.existsByEmailIgnoreCase(email)) throw ApiException.conflict("Identifiant ou e-mail déjà utilisé");
        User u = new User();
        u.setName(req.name().trim());
        u.setLogin(login);
        u.setEmail(email);
        u.setRole(Role.ATHLETE); // seul l'admin attribue le rôle coach
        u.setPasswordHash(encoder.encode(req.password()));
        return session(users.save(u));
    }

    @Override
    public AuthResponse login(LoginRequest req) {
        String id = Texts.clean(req.login()), password = req.password() == null ? "" : req.password();
        User u = id == null ? null : users.findByLoginOrEmail(id).orElse(null);
        boolean ok = encoder.matches(password, u == null ? dummyHash : u.getPasswordHash());
        if (u == null || !ok) throw ApiException.unauthorized(BAD_CREDENTIALS);
        if (!u.isActive()) throw ApiException.forbidden("Compte désactivé. Contactez l’accueil de la salle.");
        if (encoder.upgradeEncoding(u.getPasswordHash())) u.setPasswordHash(encoder.encode(password)); // compte importé : scrypt → bcrypt
        return session(u);
    }

    @Override
    public ForgotResponse forgot(ForgotRequest req) {
        String email = Texts.clean(req.email());
        User u = Texts.isEmail(email) ? users.findByEmailIgnoreCase(email).orElse(null) : null;
        String devCode = null;
        if (u != null) {
            String code = String.valueOf(100000 + random.nextInt(900000));
            PasswordReset r = resets.findByUserId(u.getId()).orElseGet(PasswordReset::new);
            r.setUser(u);
            r.setCodeHash(encoder.encode(code));
            r.setExpires(Instant.now().plus(Duration.ofMinutes(15)));
            r.setTries(0);
            resets.save(r);
            if (props.showResetCode()) {
                devCode = code;
                log.info("[Mot de passe oublié] code de démonstration généré pour le compte #{}", u.getId());
            } else {
                log.warn("[Mot de passe oublié] demande pour le compte #{} : aucun envoi d'e-mail n'est configuré", u.getId());
            }
        }
        return new ForgotResponse(true, devCode); // même réponse si l'e-mail est inconnu
    }

    @Override
    @Transactional(noRollbackFor = ApiException.class) // le compteur d'essais doit être enregistré même en cas d'échec
    public void reset(ResetRequest req) {
        String email = Texts.clean(req.email());
        User u = Texts.isEmail(email) ? users.findByEmailIgnoreCase(email).orElse(null) : null;
        PasswordReset r = u == null ? null : resets.findByUserId(u.getId()).orElse(null);
        if (r == null || r.getExpires().isBefore(Instant.now()) || r.getTries() >= 5) throw ApiException.badRequest(BAD_CODE);
        if (!encoder.matches(req.code() == null ? "" : req.code().trim(), r.getCodeHash())) {
            r.setTries(r.getTries() + 1);
            throw ApiException.badRequest(BAD_CODE);
        }
        passwordRule(req.password());
        u.setPasswordHash(encoder.encode(req.password()));
        u.setTokenVersion(u.getTokenVersion() + 1); // déconnecte les autres sessions
        resets.delete(r);
    }

    @Override
    @Transactional(readOnly = true)
    public UserDto me(CurrentUser me) { return UserDto.of(access.user(me.id())); }

    @Override
    public UserDto updateProfile(CurrentUser me, ProfileRequest req) {
        User u = access.user(me.id());
        String email = req.email().trim();
        if (users.existsByEmailIgnoreCaseAndIdNot(email, u.getId())) throw ApiException.conflict("Identifiant ou e-mail déjà utilisé");
        u.setName(req.name().trim());
        u.setEmail(email);
        u.setPhone(Texts.clean(req.phone()));
        if (u.isCoach() && req.specialty() != null) u.setSpecialty(Texts.clean(req.specialty()));
        return UserDto.of(u);
    }

    @Override
    public TokenResponse changePassword(CurrentUser me, PasswordChangeRequest req) {
        User u = access.user(me.id());
        if (!encoder.matches(req.old() == null ? "" : req.old(), u.getPasswordHash())) throw ApiException.badRequest("Ancien mot de passe incorrect");
        passwordRule(req.newPassword());
        u.setPasswordHash(encoder.encode(req.newPassword()));
        u.setTokenVersion(u.getTokenVersion() + 1); // révoque les anciens jetons
        users.saveAndFlush(u);
        return new TokenResponse(true, jwt.issue(u)); // remplace le jeton de la session courante
    }
}
