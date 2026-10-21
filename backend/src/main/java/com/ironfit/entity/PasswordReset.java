package com.ironfit.entity;

import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Code de réinitialisation du mot de passe (haché, 15 minutes, 5 essais). */
@Entity
@Table(name = "resets")
@Getter @Setter @NoArgsConstructor
public class PasswordReset {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User user;
    @Column(name = "code_hash", nullable = false, length = 200)
    private String codeHash;
    @Column(nullable = false)
    private Instant expires;
    @Column(nullable = false)
    private int tries = 0;
}
