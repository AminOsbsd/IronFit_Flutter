package com.ironfit.repository;

import com.ironfit.entity.Payment;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PaymentRepository extends JpaRepository<Payment, Long> {
    /** {@code all} vrai = tous les membres (admin), sinon uniquement {@code ids}. */
    @Query("""
            select p from Payment p join fetch p.member m
            where (:all = true or m.id in :ids)
              and (:q is null or lower(coalesce(p.note, '')) like :q or lower(coalesce(p.method, '')) like :q or lower(m.name) like :q)
            order by p.id desc""")
    List<Payment> search(@Param("all") boolean all, @Param("ids") Collection<Long> ids, @Param("q") String q, Pageable page);

    List<Payment> findByPaidOnGreaterThanEqual(LocalDate from);
}
