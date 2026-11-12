package com.ironfit.repository;

import com.ironfit.entity.RetentionAlert;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RetentionAlertRepository extends JpaRepository<RetentionAlert, Long> {
    boolean existsByMemberIdAndSentOn(Long memberId, LocalDate sentOn);

    /** [id du membre, date de sa dernière relance] */
    @Query("select a.member.id, max(a.sentOn) from RetentionAlert a where a.member.id in :ids group by a.member.id")
    List<Object[]> lastSentByMember(@Param("ids") Collection<Long> ids);
}
