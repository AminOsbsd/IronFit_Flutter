package com.ironfit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import com.ironfit.config.DataInitializer;
import com.ironfit.repository.PlanRepository;
import com.ironfit.repository.PaymentRepository;
import java.math.BigDecimal;
import static org.assertj.core.api.Assertions.*;
class CurrencyMigrationTest extends ApiTestSupport {
 @Autowired DataInitializer initializer;
 @Autowired PlanRepository plans;
 @Autowired PaymentRepository payments;
 @Test void approvedPricesMigrateOnceAndHistoryKeepsTnd() {
  var plan=plans.findAll().stream().filter(p->p.getName().equals("Mensuel")).findFirst().orElseThrow();
  plan.setCurrency("TND");plan.setPrice(new BigDecimal("99"));plans.save(plan);
  var old=payments.findAll().get(0);var original=old.getAmount();
  initializer.run(null);
  var migrated=plans.findById(plan.getId()).orElseThrow();assertThat(migrated.getCurrency()).isEqualTo("EUR");assertThat(migrated.getPrice()).isEqualByComparingTo("60");
  var history=payments.findById(old.getId()).orElseThrow();assertThat(history.getCurrency()).isEqualTo("TND");assertThat(history.getAmount()).isEqualByComparingTo(original);assertThat(history.getAmountMinor()).isEqualTo(original.movePointRight(3).longValueExact());
  migrated.setPrice(new BigDecimal("61"));plans.save(migrated);initializer.run(null);
  assertThat(plans.findById(plan.getId()).orElseThrow().getPrice()).isEqualByComparingTo("61");
 }
}
