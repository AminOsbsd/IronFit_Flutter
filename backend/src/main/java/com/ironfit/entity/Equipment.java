package com.ironfit.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Matériel de la salle. */
@Entity
@Table(name = "equipment")
@Getter @Setter @NoArgsConstructor
public class Equipment {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, length = 120)
    private String name;
    @Column(length = 60)
    private String category;
    private Integer qty = 1;
    @Column(length = 30)
    private String status = "OK";
}
