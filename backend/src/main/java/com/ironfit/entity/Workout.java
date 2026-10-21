package com.ironfit.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDate;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Séance réalisée par un membre, éventuellement liée à un programme et commentée par le coach. */
@Entity
@Table(name = "workouts", indexes = {@Index(name = "idx_workouts_user", columnList = "user_id,done_on"), @Index(name = "idx_workouts_program", columnList = "program_id")})
@Getter @Setter @NoArgsConstructor
public class Workout {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User user;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "program_id")
    @OnDelete(action = OnDeleteAction.SET_NULL)
    private Program program;
    @Column(name = "done_on", nullable = false)
    private LocalDate doneOn;
    private Integer duration;
    private Integer rpe;
    @Column(length = 1000)
    private String notes;
    @Column(name = "coach_comment", length = 1000)
    private String coachComment;
    @CreationTimestamp
    @Column(updatable = false)
    private Instant created;
}
