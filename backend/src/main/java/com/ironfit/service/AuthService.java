package com.ironfit.service;

import com.ironfit.dto.UserDtos.*;
import com.ironfit.security.CurrentUser;

/** Inscription, connexion, mot de passe oublié, profil et changement de mot de passe. */
public interface AuthService {
    AuthResponse signup(SignupRequest req);

    AuthResponse login(LoginRequest req);

    ForgotResponse forgot(ForgotRequest req);

    void reset(ResetRequest req);

    UserDto me(CurrentUser me);

    UserDto updateProfile(CurrentUser me, ProfileRequest req);

    TokenResponse changePassword(CurrentUser me, PasswordChangeRequest req);
}
