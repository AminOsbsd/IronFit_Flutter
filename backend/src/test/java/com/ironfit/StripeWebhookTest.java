package com.ironfit;
import com.ironfit.entity.StripeOrder;
import com.ironfit.repository.StripeOrderRepository;
import com.ironfit.repository.PaymentRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.TestPropertySource;
import org.springframework.http.MediaType;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.HexFormat;
import static org.assertj.core.api.Assertions.assertThat;

@TestPropertySource(properties={"ironfit.stripe-secret-key=sk_test_educational_fixture","ironfit.stripe-test-mode=true","STRIPE_WEBHOOK_SECRET=whsec_fixture"})
class StripeWebhookTest extends ApiTestSupport {
 @Autowired StripeOrderRepository orders;
 @Autowired PaymentRepository payments;
 private StripeOrder order() {
  StripeOrder o=new StripeOrder();o.setId("fixture");o.setMemberId(id("youssef"));o.setPlanId(users.findById(id("youssef")).orElseThrow().planId());o.setPlanName("Existing plan");o.setDuration("1 mois");o.setSubtotal(60000L);o.setMode("payment");o.setSessionId("cs_test_fixture");return orders.save(o);
 }
 private String event(String paymentStatus, long amount, boolean live) {
  return "{\"id\":\"evt_fixture\",\"object\":\"event\",\"type\":\"checkout.session.completed\",\"livemode\":"+live+",\"data\":{\"object\":{\"id\":\"cs_test_fixture\",\"object\":\"checkout.session\",\"metadata\":{\"ironfit_order\":\"fixture\"},\"currency\":\"tnd\",\"payment_status\":\""+paymentStatus+"\",\"amount_subtotal\":"+amount+",\"amount_total\":"+amount+"}}}";
 }
 private int send(String body, boolean valid)throws Exception {
  String t=Long.toString(Instant.now().getEpochSecond());Mac mac=Mac.getInstance("HmacSHA256");mac.init(new SecretKeySpec("whsec_fixture".getBytes(StandardCharsets.UTF_8),"HmacSHA256"));String signature=HexFormat.of().formatHex(mac.doFinal((t+"."+body).getBytes(StandardCharsets.UTF_8)));
  return mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/payments/stripe/webhook").contentType(MediaType.APPLICATION_JSON).header("Stripe-Signature","t="+t+",v1="+(valid?signature:"invalid")).content(body)).andReturn().getResponse().getStatus();
 }
 @Test void signedPaymentFulfillsOnce()throws Exception {order();long before=payments.count();assertThat(send(event("paid",60000,false),true)).isEqualTo(200);assertThat(send(event("paid",60000,false),true)).isEqualTo(200);assertThat(payments.count()).isEqualTo(before+1);assertThat(orders.findById("fixture").orElseThrow().getStatus()).isEqualTo("paid");}
 @Test void invalidSignatureCannotActivate()throws Exception {order();long before=payments.count();assertThat(send(event("paid",60000,false),false)).isEqualTo(400);assertThat(payments.count()).isEqualTo(before);}
 @Test void unpaidSessionCannotActivate()throws Exception {order();long before=payments.count();assertThat(send(event("unpaid",60000,false),true)).isEqualTo(200);assertThat(payments.count()).isEqualTo(before);}
 @Test void liveEventRejected()throws Exception {order();assertThat(send(event("paid",60000,true),true)).isEqualTo(400);}
 @Test void wrongAmountRejected()throws Exception {order();assertThat(send(event("paid",100,false),true)).isEqualTo(400);}
 @Test void expiredSessionDoesNotActivate()throws Exception {order();long before=payments.count();String body=event("unpaid",60000,false).replace("checkout.session.completed","checkout.session.expired");assertThat(send(body,true)).isEqualTo(200);assertThat(orders.findById("fixture").orElseThrow().getStatus()).isEqualTo("expired");assertThat(payments.count()).isEqualTo(before);}
 @Test void failedSessionDoesNotActivate()throws Exception {order();long before=payments.count();String body=event("unpaid",60000,false).replace("checkout.session.completed","checkout.session.async_payment_failed");assertThat(send(body,true)).isEqualTo(200);assertThat(orders.findById("fixture").orElseThrow().getStatus()).isEqualTo("failed");assertThat(payments.count()).isEqualTo(before);}
 @Test void otherMemberCannotReadOrder()throws Exception {order();assertThat(get("payments/stripe/orders/fixture",login("admin")).status()).isIn(403,404);}
 @Test void recurringInvoiceFulfillsOnce()throws Exception {
  StripeOrder o=order();o.setMode("subscription");orders.save(o);
  long end=Instant.now().plusSeconds(60L*60*24*35).getEpochSecond();
  String body="{\"id\":\"evt_invoice\",\"object\":\"event\",\"type\":\"invoice.paid\",\"livemode\":false,\"data\":{\"object\":{\"id\":\"in_fixture\",\"currency\":\"tnd\",\"paid\":true,\"amount_paid\":60000,\"parent\":{\"subscription_details\":{\"metadata\":{\"ironfit_order\":\"fixture\"}}},\"lines\":{\"data\":[{\"period\":{\"end\":"+end+"}}]}}}}";
  long before=payments.count();assertThat(send(body,true)).isEqualTo(200);assertThat(send(body,true)).isEqualTo(200);assertThat(payments.count()).isEqualTo(before+1);
 }
 @Test void wrongCurrencyCannotActivate()throws Exception {order();long before=payments.count();assertThat(send(event("paid",60000,false).replace("tnd","eur"),true)).isEqualTo(400);assertThat(payments.count()).isEqualTo(before);}
 @Test void checkoutNeedsAuthentication()throws Exception {assertThat(post("payments/stripe/checkout",java.util.Map.of("plan_id",1,"request_id","aaaaaaaaaaaaaaaa"),null).status()).isEqualTo(401);}
 @Test void euroPaymentStoresCentsAndPreservesLegacyHistory()throws Exception {
  StripeOrder o=order();o.setCurrency("EUR");o.setSubtotal(6000L);orders.save(o);
  var legacy=new com.ironfit.entity.Payment();legacy.setMember(users.findById(id("youssef")).orElseThrow());legacy.setAmount(new java.math.BigDecimal("60.00"));legacy.setMethod("Espèces");payments.save(legacy);
  String body=event("paid",6000,false).replace("tnd","eur").replace("cs_test_fixture","cs_test_euro");
  o.setSessionId("cs_test_euro");orders.save(o);
  assertThat(send(body,true)).isEqualTo(200);
  var paid=payments.findAll().stream().filter(p->"cs_test_euro".equals(p.getStripeReference())).findFirst().orElseThrow();
  assertThat(paid.getCurrency()).isEqualTo("EUR");assertThat(paid.getAmountMinor()).isEqualTo(6000L);assertThat(paid.getAmount()).isEqualByComparingTo("60");
  var old=payments.findById(legacy.getId()).orElseThrow();assertThat(old.getCurrency()).isEqualTo("TND");assertThat(old.getAmount()).isEqualByComparingTo("60");
 }
 @Test void euroSubscriptionInvoiceStoresCents()throws Exception {
  StripeOrder o=order();o.setCurrency("EUR");o.setMode("subscription");orders.save(o);
  long end=Instant.now().plusSeconds(60L*60*24*35).getEpochSecond();
  String body="{\"id\":\"evt_euro_invoice\",\"object\":\"event\",\"type\":\"invoice.paid\",\"livemode\":false,\"data\":{\"object\":{\"id\":\"in_euro\",\"currency\":\"eur\",\"paid\":true,\"amount_paid\":6000,\"parent\":{\"subscription_details\":{\"metadata\":{\"ironfit_order\":\"fixture\"}}},\"lines\":{\"data\":[{\"period\":{\"end\":"+end+"}}]}}}}";
  assertThat(send(body,true)).isEqualTo(200);
  var paid=payments.findAll().stream().filter(p->"in_euro".equals(p.getStripeReference())).findFirst().orElseThrow();assertThat(paid.getCurrency()).isEqualTo("EUR");assertThat(paid.getAmount()).isEqualByComparingTo("60");
 }
}
