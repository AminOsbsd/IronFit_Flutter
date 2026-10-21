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

/** Compte utilisateur : administrateur, coach (également membre) ou membre. */
@Entity
@Table(name = "users")
@Getter @Setter @NoArgsConstructor
public class User {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, length = 80)
    private String name;
    @Column(nullable = false, unique = true, length = 20)
    private String login;
    @Column(nullable = false, unique = true, length = 120)
    private String email;
    @Column(length = 30)
    private String phone;
    @Column(nullable = false, length = 10)
    private Role role;
    /** Hachage bcrypt (ou scrypt hérité de l'ancienne base, converti en bcrypt à la connexion). */
    @Column(name = "password_hash", nullable = false, length = 200)
    private String passwordHash;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "plan_id")
    @OnDelete(action = OnDeleteAction.SET_NULL)
    private Plan plan;
    @Column(name = "sub_end")
    private LocalDate subEnd;
    @Column(length = 80)
    private String specialty;
    @Column(nullable = false)
    private boolean active = true;
    /** Version des jetons : l'incrémenter révoque toutes les sessions du compte. */
    @Column(name = "token_version", nullable = false)
    private int tokenVersion = 0;
    @CreationTimestamp
    @Column(updatable = false)
    private Instant created;

    public boolean isMember() { return role != null && role.isMember(); }
    public boolean isCoach() { return role == Role.COACH; }
    public boolean isAdmin() { return role == Role.ADMIN; }
    public Long planId() { return plan == null ? null : plan.getId(); }
}
