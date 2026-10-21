package com.ironfit.repository;

import com.ironfit.entity.Announcement;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AnnouncementRepository extends JpaRepository<Announcement, Long> {
    @Query("""
            select a from Announcement a left join fetch a.author u
            where :q is null or lower(a.title) like :q or lower(coalesce(a.body, '')) like :q or lower(coalesce(u.name, '')) like :q
            order by a.id desc""")
    List<Announcement> search(@Param("q") String q, Pageable page);
}
