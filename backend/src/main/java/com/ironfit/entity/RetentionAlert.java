package com.ironfit.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Relance envoyée à un membre à risque (historique + anti-spam : une relance par jour, une par semaine en automatique). */
@Entity
@Table(name = "retention_alerts", indexes = @Index(name = "idx_retention_member", columnList = "member_id,sent_on"))
@Getter @Setter @NoArgsConstructor
public class RetentionAlert {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User member;
    @Column(name = "sent_on", nullable = false)
    private LocalDate sentOn;
    /** Score au moment de la relance. */
    @Column(nullable = false)
    private int score;
    /** auto (analyse nocturne), coach ou admin (relance manuelle). */
    @Column(nullable = false, length = 10)
    private String source;

    public RetentionAlert(User member, LocalDate sentOn, int score, String source) {
        this.member = member;
        this.sentOn = sentOn;
        this.score = score;
        this.source = source;
    }
}
