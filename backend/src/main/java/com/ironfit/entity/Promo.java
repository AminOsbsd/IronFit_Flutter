package com.ironfit.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Promotion / offre. */
@Entity
@Table(name = "promos")
@Getter @Setter @NoArgsConstructor
public class Promo {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, length = 160)
    private String title;
    @Column(length = 2000)
    private String descr;
    private Integer discount = 0;
    @Column(name = "valid_until")
    private LocalDate until;
}
