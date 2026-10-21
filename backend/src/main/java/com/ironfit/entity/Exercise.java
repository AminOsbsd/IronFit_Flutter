package com.ironfit.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Ligne d'un programme (bloc/jour, séries, répétitions, charge, repos). */
@Entity
@Table(name = "exercises", indexes = @Index(name = "idx_exercises_program", columnList = "program_id,position"))
@Getter @Setter @NoArgsConstructor
public class Exercise {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "program_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private Program program;
    /** Bloc / jour libre (« A », « Lundi »…). « day » est réservé dans certaines bases : colonne day_label. */
    @Column(name = "day_label", length = 40)
    private String day;
    @Column(nullable = false, length = 120)
    private String name;
    private Integer sets;
    @Column(length = 40)
    private String reps;
    /** « load » est un mot réservé MySQL : colonne load_text, champ JSON « load ». */
    @Column(name = "load_text", length = 40)
    private String load;
    @Column(length = 40)
    private String rest;
    @Column(length = 500)
    private String notes;
    @Column(nullable = false)
    private int position = 0;
}
