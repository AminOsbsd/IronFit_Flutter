package com.ironfit.entity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.time.Instant;
@Entity @Getter @Setter
@Table(name="stripe_orders")
public class StripeOrder {
 @Id private String id;
 @Column(nullable=false) private Long memberId;
 @Column(nullable=false) private Long planId;
 private String planName;
 private String duration;
 private Boolean structuredDuration;
 private Long subtotal;
 private String mode;
 private String sessionId;
 @Column(length=2048) private String checkoutUrl;
 private String customerId;
 private String subscriptionId;
 private String status = "pending";
 private Instant created = Instant.now();
    @Column(length = 3, columnDefinition = "varchar(3) default 'TND'") private String currency;
    public String getCurrency() { return currency == null ? "TND" : currency; }
}
