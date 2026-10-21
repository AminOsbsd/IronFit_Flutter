package com.ironfit.repository;

import com.ironfit.entity.ClassSession;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ClassSessionRepository extends JpaRepository<ClassSession, Long> {
    @Query("select c from ClassSession c left join fetch c.coach order by c.day, c.time")
    List<ClassSession> findAllWithCoach();

    @Query("select c from ClassSession c where c.coach.id = :coachId order by c.day, c.time")
    List<ClassSession> findByCoach(@Param("coachId") Long coachId);

    long countByCoachId(Long coachId);
}
