package com.ironfit.repository;

import com.ironfit.entity.Promo;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PromoRepository extends JpaRepository<Promo, Long> {
    @Query("select p from Promo p where :q is null or lower(p.title) like :q or lower(coalesce(p.descr, '')) like :q order by p.id")
    List<Promo> search(@Param("q") String q, Pageable page);
}
