package com.ironfit.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Réservation d'un cours par un membre (une seule par couple membre/cours). */
@Entity
@Table(name = "bookings", uniqueConstraints = @UniqueConstraint(name = "uk_booking", columnNames = {"user_id", "class_id"}))
@Getter @Setter @NoArgsConstructor
public class Booking {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User user;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "class_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private ClassSession classSession;

    public Booking(User user, ClassSession classSession) { this.user = user; this.classSession = classSession; }
}
