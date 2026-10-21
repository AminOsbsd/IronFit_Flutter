package com.ironfit.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.regex.Pattern;
import org.bouncycastle.crypto.generators.SCrypt;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * bcrypt pour tous les nouveaux mots de passe.
 * Reconnaît aussi le format de l'ancienne API Node.js (« selHex:hashHex », scrypt N=16384, r=8, p=1, 64 octets)
 * afin que les comptes importés de SQLite puissent se connecter ; {@link #upgradeEncoding} signale qu'il faut rehacher.
 */
public class PasswordHasher implements PasswordEncoder {
    private static final Pattern LEGACY = Pattern.compile("^[0-9a-f]{32}:[0-9a-f]{128}$");
    private final BCryptPasswordEncoder bcrypt = new BCryptPasswordEncoder();

    @Override
    public String encode(CharSequence raw) { return bcrypt.encode(raw); }

    @Override
    public boolean matches(CharSequence raw, String stored) {
        if (raw == null || stored == null) return false;
        if (LEGACY.matcher(stored).matches()) return legacyMatches(raw.toString(), stored);
        return stored.startsWith("$2") && bcrypt.matches(raw, stored);
    }

    @Override
    public boolean upgradeEncoding(String stored) { return stored == null || !stored.startsWith("$2"); }

    private static boolean legacyMatches(String raw, String stored) {
        String[] parts = stored.split(":");
        byte[] salt = HexFormat.of().parseHex(parts[0]), expected = HexFormat.of().parseHex(parts[1]);
        byte[] actual = SCrypt.generate(raw.getBytes(StandardCharsets.UTF_8), salt, 16384, 8, 1, 64);
        return MessageDigest.isEqual(actual, expected);
    }
}
