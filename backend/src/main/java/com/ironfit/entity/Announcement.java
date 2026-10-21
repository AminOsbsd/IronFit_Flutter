package com.ironfit.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/** Annonce publiée par l'administration ou un coach. */
@Entity
@Table(name = "announcements")
@Getter @Setter @NoArgsConstructor
public class Announcement {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, length = 160)
    private String title;
    @Column(length = 2000)
    private String body;
    @Column(name = "posted_on")
    private LocalDate postedOn;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id")
    @OnDelete(action = OnDeleteAction.SET_NULL)
    private User author;

    public Long authorId() { return author == null ? null : author.getId(); }
}
