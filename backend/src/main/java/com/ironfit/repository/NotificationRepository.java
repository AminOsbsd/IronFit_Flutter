package com.ironfit.repository;

import com.ironfit.entity.Notification;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface NotificationRepository extends JpaRepository<Notification, Long> {
    @Query("select n from Notification n where n.user.id = :userId order by n.id desc")
    List<Notification> findForUser(@Param("userId") Long userId, Pageable page);

    long countByUserIdAndSeenFalse(Long userId);

    @Modifying
    @Query("update Notification n set n.seen = true where n.id = :id and n.user.id = :userId")
    int markRead(@Param("id") Long id, @Param("userId") Long userId);

    @Modifying
    @Query("update Notification n set n.seen = true where n.user.id = :userId and n.seen = false")
    int markAllRead(@Param("userId") Long userId);
}
