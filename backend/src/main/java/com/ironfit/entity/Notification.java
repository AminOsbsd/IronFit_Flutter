package com.ironfit.entity;

import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Notification personnelle. */
@Entity
@Table(name = "notifications", indexes = @Index(name = "idx_notifications_user", columnList = "user_id,seen"))
@Getter @Setter @NoArgsConstructor
public class Notification {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User user;
    @Column(nullable = false, length = 200)
    private String title;
    @Column(length = 1000)
    private String body;
    @Column(nullable = false)
    private boolean seen = false;
    @CreationTimestamp
    @Column(updatable = false)
    private Instant created;

    public Notification(User user, String title, String body) { this.user = user; this.title = title; this.body = body; }
}
