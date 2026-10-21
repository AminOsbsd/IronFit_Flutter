package com.ironfit.repository;

import com.ironfit.entity.Product;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProductRepository extends JpaRepository<Product, Long> {
    @Query("select p from Product p where :q is null or lower(p.name) like :q or lower(coalesce(p.category, '')) like :q order by p.id")
    List<Product> search(@Param("q") String q, Pageable page);

    List<Product> findByStockLessThanEqualOrderByStockAsc(int stock);
}
