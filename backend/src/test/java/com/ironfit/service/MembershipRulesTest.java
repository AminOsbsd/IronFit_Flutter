package com.ironfit.service;
import org.junit.jupiter.api.Test;
import com.ironfit.entity.Plan;
import java.time.LocalDate;
import static org.assertj.core.api.Assertions.*;
class MembershipRulesTest {
 @Test void dayPassIsOneInclusiveDay(){Plan p=new Plan();p.setDuration("1 entrée");var date=LocalDate.of(2026,11,16);assertThat(MembershipRules.extend(null,p,date)).isEqualTo(date);assertThat(p.getAccessType()).isEqualTo("DAY_PASS");}
 @Test void futureAccessIsPreserved(){Plan p=new Plan();p.setDurationCount(1);p.setDurationUnit("MONTH");p.setAccessType("PERIOD");assertThat(MembershipRules.extend(LocalDate.of(2026,11,30),p,LocalDate.of(2026,11,16))).isEqualTo(LocalDate.of(2026,12,31));}
 @Test void unknownLegacyDurationIsNotInvented(){Plan p=new Plan();p.setDuration("special");assertThatThrownBy(()->MembershipRules.validate(p)).isInstanceOf(RuntimeException.class);}
}
