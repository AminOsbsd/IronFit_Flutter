package com.ironfit.dto;

/** Réponses génériques. */
public final class CommonDtos {
    private CommonDtos() {}

    public record OkResponse(boolean ok) {
        public static final OkResponse OK = new OkResponse(true);
    }

    public record IdResponse(Long id) {}
}
