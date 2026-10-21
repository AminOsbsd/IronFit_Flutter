package com.ironfit.dto;

import com.ironfit.entity.SubscriptionRequest;
import java.math.BigDecimal;
import java.time.Instant;

/** Demandes d'abonnement. */
public final class SubscriptionDtos {
    private SubscriptionDtos() {}

    public record RequestDto(Long id, Long memberId, Long planId, String status, Instant created, String planName, BigDecimal price, String memberName) {
        public static RequestDto of(SubscriptionRequest r, boolean withMember) {
            return new RequestDto(r.getId(), r.getMember().getId(), r.getPlan().getId(), r.getStatus(), r.getCreated(),
                    r.getPlan().getName(), r.getPlan().getPrice(), withMember ? r.getMember().getName() : null);
        }
    }

    public record CreateRequest(Long planId) {}

    public record ActionRequest(String method) {}
}
