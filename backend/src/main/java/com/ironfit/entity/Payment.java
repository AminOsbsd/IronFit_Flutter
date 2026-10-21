package com.ironfit.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Paiement d'un membre. */
@Entity
@Table(name = "payments", indexes = @Index(name = "idx_payments_member", columnList = "member_id"))
@Getter @Setter @NoArgsConstructor
public class Payment {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User member;
    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;
    @Column(length = 30)
    private String method;
    @Column(name = "paid_on")
    private LocalDate paidOn;
    @Column(length = 500)
    private String note;
}
