package com.ironfit.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Cours collectif hebdomadaire (jour 0 = lundi). */
@Entity
@Table(name = "classes", indexes = @Index(name = "idx_classes_day", columnList = "week_day,start_time"))
@Getter @Setter @NoArgsConstructor
public class ClassSession {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "week_day", nullable = false)
    private Integer day;
    /** HH:MM */
    @Column(name = "start_time", nullable = false, length = 5)
    private String time;
    @Column(nullable = false, length = 120)
    private String title;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "coach_id")
    @OnDelete(action = OnDeleteAction.SET_NULL)
    private User coach;
    @Column(nullable = false)
    private Integer spots = 10;

    public Long coachId() { return coach == null ? null : coach.getId(); }
}
