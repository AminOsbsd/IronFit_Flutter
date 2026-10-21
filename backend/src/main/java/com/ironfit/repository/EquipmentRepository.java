package com.ironfit.repository;

import com.ironfit.entity.Equipment;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface EquipmentRepository extends JpaRepository<Equipment, Long> {
    @Query("""
            select e from Equipment e
            where :q is null or lower(e.name) like :q or lower(coalesce(e.category, '')) like :q or lower(coalesce(e.status, '')) like :q
            order by e.id""")
    List<Equipment> search(@Param("q") String q, Pageable page);

    List<Equipment> findByStatusNot(String status);
}
