package com.ironfit.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Tarif / formule d'abonnement (durée libre : « 1 mois », « 15 jours », « 1 entrée »…). */
@Entity
@Table(name = "plans")
@Getter @Setter @NoArgsConstructor
public class Plan {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, length = 120)
    private String name;
    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal price = BigDecimal.ZERO;
    @Column(length = 60)
    private String duration;
    private String durationUnit;
    private Integer durationCount;
    private String accessType;
    @Column(length = 2000)
    private String descr;
    @Column(length = 3, columnDefinition = "varchar(3) default 'TND'") private String currency;
    public String getCurrency() { return currency == null ? "TND" : currency; }
}
