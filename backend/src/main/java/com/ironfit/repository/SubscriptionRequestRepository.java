package com.ironfit.repository;

import com.ironfit.entity.SubscriptionRequest;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SubscriptionRequestRepository extends JpaRepository<SubscriptionRequest, Long> {
    @Query("select r from SubscriptionRequest r join fetch r.plan where r.member.id = :memberId order by r.id desc")
    List<SubscriptionRequest> findForMember(@Param("memberId") Long memberId);

    @Query("select r from SubscriptionRequest r join fetch r.plan join fetch r.member where r.status = 'pending' order by r.id")
    List<SubscriptionRequest> findPending();

    boolean existsByMemberIdAndStatus(Long memberId, String status);

    long countByStatus(String status);
}
