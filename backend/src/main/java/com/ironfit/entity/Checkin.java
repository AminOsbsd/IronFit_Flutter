package com.ironfit.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Présence d'un membre (date + intitulé du cours). */
@Entity
@Table(name = "checkins", indexes = @Index(name = "idx_checkins_member", columnList = "member_id,checkin_on"))
@Getter @Setter @NoArgsConstructor
public class Checkin {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User member;
    @Column(name = "checkin_on")
    private LocalDate checkinOn;
    @Column(length = 500)
    private String note;
}
