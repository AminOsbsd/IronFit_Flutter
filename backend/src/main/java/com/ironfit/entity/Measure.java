package com.ironfit.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Mesure physique (poids, masse grasse). */
@Entity
@Table(name = "measures", indexes = @Index(name = "idx_measures_member", columnList = "member_id"))
@Getter @Setter @NoArgsConstructor
public class Measure {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User member;
    @Column(name = "measured_on")
    private LocalDate measuredOn;
    private Double weight;
    @Column(name = "body_fat")
    private Double bodyFat;
    @Column(length = 500)
    private String note;
}
