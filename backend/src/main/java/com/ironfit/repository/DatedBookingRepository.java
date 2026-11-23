package com.ironfit.repository;

import com.ironfit.entity.DatedBooking;
import com.ironfit.entity.User;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DatedBookingRepository extends JpaRepository<DatedBooking, Long> {
    Optional<DatedBooking> findByUserIdAndClassSessionId(Long userId, Long classId);

    boolean existsByUserIdAndClassSessionId(Long userId, Long classId);

    long countByClassSessionId(Long classId);

    /** [id du cours, nombre de réservations] */
    @Query("select b.classSession.id, count(b) from DatedBooking b group by b.classSession.id")
    List<Object[]> countPerClass();

    @Query("select b.classSession.id from DatedBooking b where b.user.id = :userId")
    List<Long> classIdsBookedBy(@Param("userId") Long userId);

    @Query("select b.user from DatedBooking b where b.classSession.id = :classId order by lower(b.user.name)")
    List<User> participants(@Param("classId") Long classId);
    Optional<DatedBooking> findByUserIdAndClassSessionIdAndSessionDate(Long userId, Long classId, java.time.LocalDate date);
    long countByClassSessionIdAndSessionDate(Long classId, java.time.LocalDate date);
    List<DatedBooking> findByClassSessionIdAndSessionDate(Long classId, java.time.LocalDate date);
    List<DatedBooking> findTop10ByUserIdAndSessionDateGreaterThanEqualOrderBySessionDateAsc(Long userId, java.time.LocalDate date);
    boolean existsByLegacyBookingId(Long id);
}
