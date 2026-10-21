package com.ironfit.entity;

import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Demande d'abonnement : pending → approved / rejected / cancelled. */
@Entity
@Table(name = "requests")
@Getter @Setter @NoArgsConstructor
public class SubscriptionRequest {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User member;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "plan_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private Plan plan;
    @Column(nullable = false, length = 12)
    private String status = "pending";
    @CreationTimestamp
    @Column(updatable = false)
    private Instant created;
}
