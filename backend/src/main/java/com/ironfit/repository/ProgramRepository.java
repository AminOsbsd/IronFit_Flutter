package com.ironfit.repository;

import com.ironfit.entity.Program;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProgramRepository extends JpaRepository<Program, Long> {
    /** Programmes reçus ou personnels d'un membre. */
    @Query("select p from Program p join fetch p.client left join fetch p.coach where p.client.id = :clientId order by p.active desc, p.id desc")
    List<Program> findPersonal(@Param("clientId") Long clientId);

    /** Programmes écrits par un coach pour ses clients actifs (éventuellement un seul client). */
    @Query("""
            select p from Program p join fetch p.client left join fetch p.coach
            where p.coach.id = :coachId and (:clientId is null or p.client.id = :clientId)
              and exists (select 1 from CoachClient cc where cc.coach = p.coach and cc.client = p.client and cc.status = 'active')
            order by p.active desc, p.id desc""")
    List<Program> findCoaching(@Param("coachId") Long coachId, @Param("clientId") Long clientId);

    @Query("select p from Program p join fetch p.client left join fetch p.coach order by p.id desc")
    List<Program> findAllWithUsers(Pageable page);

    @Query("""
            select count(p) from Program p
            where p.coach.id = :coachId and p.active = true
              and exists (select 1 from CoachClient cc where cc.coach = p.coach and cc.client = p.client and cc.status = 'active')""")
    long countActiveForCoach(@Param("coachId") Long coachId);
}
