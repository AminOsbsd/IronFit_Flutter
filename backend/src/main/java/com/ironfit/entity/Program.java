package com.ironfit.entity;

import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Programme d'entraînement : coach NULL = programme personnel du membre, sinon écrit par ce coach. */
@Entity
@Table(name = "programs", indexes = {@Index(name = "idx_programs_client", columnList = "client_id"), @Index(name = "idx_programs_coach", columnList = "coach_id")})
@Getter @Setter @NoArgsConstructor
public class Program {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "client_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User client;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "coach_id")
    @OnDelete(action = OnDeleteAction.SET_NULL)
    private User coach;
    @Column(nullable = false, length = 160)
    private String title;
    @Column(length = 160)
    private String goal;
    @Column(length = 2000)
    private String notes;
    @Column(nullable = false)
    private boolean active = true;
    @CreationTimestamp
    @Column(updatable = false)
    private Instant created;

    public Long coachId() { return coach == null ? null : coach.getId(); }
}
