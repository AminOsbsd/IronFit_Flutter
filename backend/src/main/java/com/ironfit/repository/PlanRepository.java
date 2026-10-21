package com.ironfit.repository;

import com.ironfit.entity.Plan;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PlanRepository extends JpaRepository<Plan, Long> {
    @Query("""
            select p from Plan p
            where :q is null or lower(p.name) like :q or lower(coalesce(p.duration, '')) like :q or lower(coalesce(p.descr, '')) like :q
            order by p.id""")
    List<Plan> search(@Param("q") String q, Pageable page);
}
