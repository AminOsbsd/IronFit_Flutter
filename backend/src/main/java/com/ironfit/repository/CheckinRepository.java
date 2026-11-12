package com.ironfit.repository;

import com.ironfit.entity.Checkin;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CheckinRepository extends JpaRepository<Checkin, Long> {
    @Query("""
            select x from Checkin x join fetch x.member m
            where (:all = true or m.id in :ids)
              and (:q is null or lower(coalesce(x.note, '')) like :q or lower(m.name) like :q)
            order by x.id desc""")
    List<Checkin> search(@Param("all") boolean all, @Param("ids") Collection<Long> ids, @Param("q") String q, Pageable page);

    boolean existsByMemberIdAndCheckinOnAndNote(Long memberId, LocalDate date, String note);

    long countByCheckinOn(LocalDate date);

    @Query("select x.member.id from Checkin x where x.checkinOn = :date and x.note = :note")
    List<Long> memberIdsPresent(@Param("date") LocalDate date, @Param("note") String note);

    // ---- Rétention : agrégats par membre ----

    /** [id du membre, date de sa dernière présence] */
    @Query("select x.member.id, max(x.checkinOn) from Checkin x where x.member.id in :ids group by x.member.id")
    List<Object[]> lastByMember(@Param("ids") Collection<Long> ids);

    /** [id du membre, nombre de présences depuis la date donnée] */
    @Query("select x.member.id, count(x) from Checkin x where x.member.id in :ids and x.checkinOn >= :from group by x.member.id")
    List<Object[]> countSinceByMember(@Param("ids") Collection<Long> ids, @Param("from") LocalDate from);
}
