package com.ironfit.entity;

import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import org.hibernate.annotations.UpdateTimestamp;

/** Relation coach ↔ client : pending, active, declined, ended. Un coach n'accède aux données d'un membre que si elle est active. */
@Entity
@Table(name = "coach_clients",
        uniqueConstraints = @UniqueConstraint(name = "uk_coach_client", columnNames = {"coach_id", "client_id"}),
        indexes = @Index(name = "idx_cc_client", columnList = "client_id,status"))
@Getter @Setter @NoArgsConstructor
public class CoachClient {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "coach_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User coach;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "client_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User client;
    @Column(nullable = false, length = 10)
    private String status = "pending";
    @CreationTimestamp
    @Column(updatable = false)
    private Instant created;
    @UpdateTimestamp
    private Instant updated;
}
