package com.ironfit.repository;

import com.ironfit.entity.Booking;
import com.ironfit.entity.User;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BookingRepository extends JpaRepository<Booking, Long> {
    Optional<Booking> findByUserIdAndClassSessionId(Long userId, Long classId);

    boolean existsByUserIdAndClassSessionId(Long userId, Long classId);

    long countByClassSessionId(Long classId);

    /** [id du cours, nombre de réservations] */
    @Query("select b.classSession.id, count(b) from Booking b group by b.classSession.id")
    List<Object[]> countPerClass();

    @Query("select b.classSession.id from Booking b where b.user.id = :userId")
    List<Long> classIdsBookedBy(@Param("userId") Long userId);

    @Query("select b.user from Booking b where b.classSession.id = :classId order by lower(b.user.name)")
    List<User> participants(@Param("classId") Long classId);
}
