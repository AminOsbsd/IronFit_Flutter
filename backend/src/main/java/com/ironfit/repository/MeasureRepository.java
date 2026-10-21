package com.ironfit.repository;

import com.ironfit.entity.Measure;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MeasureRepository extends JpaRepository<Measure, Long> {
    @Query("""
            select x from Measure x join fetch x.member m
            where (:all = true or m.id in :ids)
              and (:q is null or lower(coalesce(x.note, '')) like :q or lower(m.name) like :q)
            order by x.id desc""")
    List<Measure> search(@Param("all") boolean all, @Param("ids") Collection<Long> ids, @Param("q") String q, Pageable page);
}
