package com.ironfit.dto;

import java.math.BigDecimal;

/** Contrats Stripe limités au mode test éducatif. */
public final class StripeDtos {
    private StripeDtos() {}

    public record CreateIntentRequest(Long planId) {}

    public record PaymentIntentResponse(
            String paymentIntentId,
            String clientSecret,
            Long amountMinor,
            BigDecimal subtotal,
            BigDecimal tax,
            BigDecimal total,
            String currency,
            String invoiceId,
            String publishableKey) {}
}