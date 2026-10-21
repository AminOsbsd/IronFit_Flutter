package com.ironfit.service;

import java.util.Locale;

/** Petites aides de nettoyage des saisies. */
public final class Texts {
    private Texts() {}

    /** Chaîne rognée, ou null si vide. */
    public static String clean(String s) {
        if (s == null) return null;
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    /** Motif LIKE insensible à la casse (« %texte% »), ou null si pas de recherche. */
    public static String like(String q) {
        String t = clean(q);
        if (t == null) return null;
        String escaped = t.toLowerCase(Locale.ROOT).replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
        return "%" + escaped + "%";
    }

    public static boolean isEmail(String s) {
        return s != null && s.length() <= 120 && s.matches("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");
    }
}
