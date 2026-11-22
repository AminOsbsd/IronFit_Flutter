package com.ironfit.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Réservation d'un cours par un membre (une seule par couple membre/cours). */
@Entity
@Table(name = "dated_bookings", uniqueConstraints = @UniqueConstraint(name = "uk_dated_booking", columnNames = {"user_id", "class_id", "session_date"}))
@Getter @Setter @NoArgsConstructor
public class DatedBooking {
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

    @Column(name="session_date", nullable=false)
    private java.time.LocalDate sessionDate;
    private boolean present = false;
    @Column(unique=true) private Long legacyBookingId;

    public DatedBooking(User user, ClassSession classSession) { this.user = user; this.classSession = classSession; }
}
