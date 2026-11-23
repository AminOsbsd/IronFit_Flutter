package com.ironfit.service;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import static org.assertj.core.api.Assertions.*;
class CurrencyTest {
 @Test void euroAmountsUseExactCents(){assertThat(StripeCheckoutService.eurMinor(new BigDecimal("60.00"))).isEqualTo(6000);assertThat(StripeCheckoutService.eurMinor(new BigDecimal("10.99"))).isEqualTo(1099);assertThatThrownBy(()->StripeCheckoutService.eurMinor(new BigDecimal("1.001"))).isInstanceOf(RuntimeException.class);}
}
