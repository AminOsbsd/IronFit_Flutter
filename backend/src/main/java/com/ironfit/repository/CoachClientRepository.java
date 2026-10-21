package com.ironfit.repository;

import com.ironfit.entity.CoachClient;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CoachClientRepository extends JpaRepository<CoachClient, Long> {
    boolean existsByCoachIdAndClientIdAndStatus(Long coachId, Long clientId, String status);

    Optional<CoachClient> findByCoachIdAndClientId(Long coachId, Long clientId);

    @Query("select cc.client.id from CoachClient cc where cc.coach.id = :coachId and cc.status = 'active'")
    List<Long> activeClientIds(@Param("coachId") Long coachId);

    @Query("select cc from CoachClient cc join fetch cc.coach join fetch cc.client where cc.client.id = :clientId")
    List<CoachClient> findForClient(@Param("clientId") Long clientId);

    @Query("select cc from CoachClient cc join fetch cc.coach join fetch cc.client where cc.coach.id = :coachId and cc.status in :statuses")
    List<CoachClient> findForCoach(@Param("coachId") Long coachId, @Param("statuses") Collection<String> statuses);

    @Query("select cc from CoachClient cc join fetch cc.coach join fetch cc.client where :status is null or cc.status = :status")
    List<CoachClient> findAllWithUsers(@Param("status") String status);

    long countByStatus(String status);

    long countByCoachIdAndStatus(Long coachId, String status);
}
