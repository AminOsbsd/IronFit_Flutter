package com.ironfit.repository;

import com.ironfit.entity.Workout;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface WorkoutRepository extends JpaRepository<Workout, Long> {
    @Query("select w from Workout w left join fetch w.program where w.program.id = :programId order by w.doneOn desc, w.id desc")
    List<Workout> findForProgram(@Param("programId") Long programId, Pageable page);

    /** Séances d'un membre ; {@code coachId} non nul : uniquement celles des programmes écrits par ce coach. */
    @Query("""
            select w from Workout w left join fetch w.program p
            where w.user.id = :userId
              and (:programId is null or p.id = :programId)
              and (:coachId is null or p.coach.id = :coachId)
            order by w.doneOn desc, w.id desc""")
    List<Workout> findForUser(@Param("userId") Long userId, @Param("programId") Long programId, @Param("coachId") Long coachId, Pageable page);

    /** [id du programme, nombre de séances, date de la dernière] */
    @Query("select w.program.id, count(w), max(w.doneOn) from Workout w where w.program.id in :ids group by w.program.id")
    List<Object[]> statsPerProgram(@Param("ids") Collection<Long> programIds);

    /** Dernière séance d'un client sur les programmes de ce coach. */
    @Query("select max(w.doneOn) from Workout w where w.user.id = :clientId and w.program.coach.id = :coachId")
    LocalDate lastForCoachAndClient(@Param("coachId") Long coachId, @Param("clientId") Long clientId);

    long countByDoneOnGreaterThanEqual(LocalDate from);

    @Query("""
            select count(w) from Workout w
            where w.program.coach.id = :coachId and w.doneOn >= :from and w.user.id in :clientIds""")
    long countForCoachSince(@Param("coachId") Long coachId, @Param("from") LocalDate from, @Param("clientIds") Collection<Long> clientIds);

    @Query("""
            select count(w) from Workout w
            where w.program.coach.id = :coachId and w.coachComment is null and w.user.id in :clientIds""")
    long countToReview(@Param("coachId") Long coachId, @Param("clientIds") Collection<Long> clientIds);
}
