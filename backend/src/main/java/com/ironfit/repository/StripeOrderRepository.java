package com.ironfit.repository;
import com.ironfit.entity.StripeOrder;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface StripeOrderRepository extends JpaRepository<StripeOrder,String> {
 java.util.Optional<StripeOrder> findBySessionId(String sessionId);
 List<StripeOrder> findByMemberIdOrderByCreatedDesc(Long id);
 java.util.Optional<StripeOrder> findBySubscriptionId(String subscriptionId);
}
