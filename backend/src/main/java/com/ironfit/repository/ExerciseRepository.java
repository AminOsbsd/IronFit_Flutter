package com.ironfit.repository;

import com.ironfit.entity.Exercise;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ExerciseRepository extends JpaRepository<Exercise, Long> {
    @Query("select e from Exercise e where e.program.id = :programId order by e.day, e.position, e.id")
    List<Exercise> findForProgram(@Param("programId") Long programId);

    long countByProgramId(Long programId);

    /** [id du programme, nombre d'exercices] */
    @Query("select e.program.id, count(e) from Exercise e where e.program.id in :ids group by e.program.id")
    List<Object[]> countPerProgram(@Param("ids") Collection<Long> programIds);
}
