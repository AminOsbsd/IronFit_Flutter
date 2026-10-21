package com.ironfit.controller;

import com.ironfit.dto.CommonDtos.OkResponse;
import com.ironfit.dto.UserDtos.*;
import com.ironfit.security.CurrentUser;
import com.ironfit.security.RateLimiter;
import com.ironfit.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/** Authentification (routes publiques limitées en débit) et compte de l'utilisateur connecté. */
@RestController
@RequestMapping("/api")
public class AuthController {
    private final AuthService auth;
    private final RateLimiter limiter;

    public AuthController(AuthService auth, RateLimiter limiter) {
        this.auth = auth;
        this.limiter = limiter;
    }

    @PostMapping("/signup")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthResponse signup(@Valid @RequestBody SignupRequest body, HttpServletRequest req) {
        limiter.check(req);
        return auth.signup(body);
    }

    @PostMapping("/login")
    public AuthResponse login(@RequestBody LoginRequest body, HttpServletRequest req) {
        limiter.check(req);
        return auth.login(body);
    }

    @PostMapping("/forgot")
    public ForgotResponse forgot(@RequestBody ForgotRequest body, HttpServletRequest req) {
        limiter.check(req);
        return auth.forgot(body);
    }

    @PostMapping("/reset")
    public OkResponse reset(@RequestBody ResetRequest body, HttpServletRequest req) {
        limiter.check(req);
        auth.reset(body);
        return OkResponse.OK;
    }

    @GetMapping("/me")
    public UserDto me(@AuthenticationPrincipal CurrentUser me) { return auth.me(me); }

    @PutMapping("/profile")
    public UserDto profile(@AuthenticationPrincipal CurrentUser me, @Valid @RequestBody ProfileRequest body) { return auth.updateProfile(me, body); }

    @PostMapping("/password")
    public TokenResponse password(@AuthenticationPrincipal CurrentUser me, @RequestBody PasswordChangeRequest body, HttpServletRequest req) {
        limiter.check(req);
        return auth.changePassword(me, body);
    }
}
