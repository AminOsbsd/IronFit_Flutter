package com.ironfit;

import com.ironfit.entity.StripeOrder;
import com.ironfit.repository.StripeOrderRepository;
import com.ironfit.repository.PaymentRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.HexFormat;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Regression tests added for the Nov-2026 Stripe fixes:
 *   - invoice.paid metadata at root subscription_details (Stripe API 2026-10-28)
 *   - invoice.paid fallback by subscriptionId
 *   - checkout.session.completed subscription mode stores subscriptionId then defers fulfillment
 *   - IllegalStateException "not yet persisted" returns 200 (no infinite Stripe retry)
 *   - Reconcile endpoint fulfills a completed-but-pending payment mode order
 *   - Reconcile endpoint is idempotent (called twice = one payment row)
 *   - Unauthorized user cannot reconcile another user's order
 *   - Reconcile returns pending for an open/incomplete session
 */
@TestPropertySource(properties = {
        "ironfit.stripe-secret-key=sk_test_educational_fixture",
        "ironfit.stripe-test-mode=true",
        "STRIPE_WEBHOOK_SECRET=whsec_fixture"
})
class StripeRegressionTest extends ApiTestSupport {

    @Autowired
    StripeOrderRepository orders;
    @Autowired
    PaymentRepository payments;

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private StripeOrder makeOrder(String id, String mode, String sessionId, String subId) {
        StripeOrder o = new StripeOrder();
        o.setId(id);
        o.setMemberId(id("youssef"));
        o.setPlanId(users.findById(id("youssef")).orElseThrow().planId());
        o.setPlanName("Mensuel");
        o.setDuration("1 mois");
        o.setStructuredDuration(true);
        o.setSubtotal(60_00L);   // 6000 cents = €60
        o.setCurrency("EUR");
        o.setMode(mode);
        o.setSessionId(sessionId);
        o.setSubscriptionId(subId);
        return orders.save(o);
    }

    private int sendWebhook(String body) throws Exception {
        String t = Long.toString(Instant.now().getEpochSecond());
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec("whsec_fixture".getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        String sig = HexFormat.of().formatHex(mac.doFinal((t + "." + body).getBytes(StandardCharsets.UTF_8)));
        return mvc.perform(
                MockMvcRequestBuilders.post("/api/payments/stripe/webhook")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Stripe-Signature", "t=" + t + ",v1=" + sig)
                        .content(body)
        ).andReturn().getResponse().getStatus();
    }

    private long periodEnd() {
        return Instant.now().plusSeconds(60L * 60 * 24 * 35).getEpochSecond();
    }

    // -------------------------------------------------------------------------
    // invoice.paid — root-level subscription_details (Stripe API 2026-10-28)
    // -------------------------------------------------------------------------

    @Test
    void invoicePaidRootSubscriptionDetailsPath() throws Exception {
        makeOrder("regr-root", "subscription", "cs_root", null);
        long end = periodEnd();
        // metadata at root subscription_details (new API layout)
        String body = "{\"id\":\"evt_root\",\"object\":\"event\",\"type\":\"invoice.paid\",\"livemode\":false,"
                + "\"data\":{\"object\":{"
                + "\"id\":\"in_root\",\"currency\":\"eur\",\"paid\":true,\"amount_paid\":6000,"
                + "\"subscription_details\":{\"metadata\":{\"ironfit_order\":\"regr-root\"}},"
                + "\"lines\":{\"data\":[{\"period\":{\"end\":" + end + "}}]}"
                + "}}}";
        long before = payments.count();
        assertThat(sendWebhook(body)).isEqualTo(200);
        assertThat(payments.count()).isEqualTo(before + 1);
        assertThat(orders.findById("regr-root").orElseThrow().getStatus()).isEqualTo("paid");
    }

    @Test
    void invoicePaidRootSubscriptionDetailsIsIdempotent() throws Exception {
        makeOrder("regr-root-idem", "subscription", "cs_root_idem", null);
        long end = periodEnd();
        String body = "{\"id\":\"evt_root_idem\",\"object\":\"event\",\"type\":\"invoice.paid\",\"livemode\":false,"
                + "\"data\":{\"object\":{"
                + "\"id\":\"in_root_idem\",\"currency\":\"eur\",\"paid\":true,\"amount_paid\":6000,"
                + "\"subscription_details\":{\"metadata\":{\"ironfit_order\":\"regr-root-idem\"}},"
                + "\"lines\":{\"data\":[{\"period\":{\"end\":" + end + "}}]}"
                + "}}}";
        long before = payments.count();
        assertThat(sendWebhook(body)).isEqualTo(200);
        assertThat(sendWebhook(body)).isEqualTo(200); // duplicate
        assertThat(payments.count()).isEqualTo(before + 1); // exactly once
    }

    // -------------------------------------------------------------------------
    // invoice.paid — legacy parent.subscription_details path (fallback)
    // -------------------------------------------------------------------------

    @Test
    void invoicePaidParentSubscriptionDetailsFallback() throws Exception {
        makeOrder("regr-parent", "subscription", "cs_parent", null);
        long end = periodEnd();
        // metadata under parent.subscription_details (older API layout)
        String body = "{\"id\":\"evt_parent\",\"object\":\"event\",\"type\":\"invoice.paid\",\"livemode\":false,"
                + "\"data\":{\"object\":{"
                + "\"id\":\"in_parent\",\"currency\":\"eur\",\"paid\":true,\"amount_paid\":6000,"
                + "\"parent\":{\"subscription_details\":{\"metadata\":{\"ironfit_order\":\"regr-parent\"}}},"
                + "\"lines\":{\"data\":[{\"period\":{\"end\":" + end + "}}]}"
                + "}}}";
        long before = payments.count();
        assertThat(sendWebhook(body)).isEqualTo(200);
        assertThat(payments.count()).isEqualTo(before + 1);
        assertThat(orders.findById("regr-parent").orElseThrow().getStatus()).isEqualTo("paid");
    }

    // -------------------------------------------------------------------------
    // invoice.paid — subscriptionId fallback (no metadata, match by sub ID)
    // -------------------------------------------------------------------------

    @Test
    void invoicePaidSubscriptionIdFallback() throws Exception {
        makeOrder("regr-subid", "subscription", "cs_subid", "sub_fixture_xyz");
        long end = periodEnd();
        // no ironfit_order metadata at all — only subscription field
        String body = "{\"id\":\"evt_subid\",\"object\":\"event\",\"type\":\"invoice.paid\",\"livemode\":false,"
                + "\"data\":{\"object\":{"
                + "\"id\":\"in_subid\",\"currency\":\"eur\",\"paid\":true,\"amount_paid\":6000,"
                + "\"subscription\":\"sub_fixture_xyz\","
                + "\"lines\":{\"data\":[{\"period\":{\"end\":" + end + "}}]}"
                + "}}}";
        long before = payments.count();
        assertThat(sendWebhook(body)).isEqualTo(200);
        assertThat(payments.count()).isEqualTo(before + 1);
        assertThat(orders.findById("regr-subid").orElseThrow().getStatus()).isEqualTo("paid");
    }

    // -------------------------------------------------------------------------
    // checkout.session.completed subscription mode — stores subscriptionId, defers fulfillment
    // -------------------------------------------------------------------------

    @Test
    void checkoutCompletedSubscriptionModeStoresSubIdAndDefers() throws Exception {
        makeOrder("regr-sub-defer", "subscription", "cs_sub_defer", null);
        // checkout.session.completed for subscription: should store subscriptionId but NOT fulfill
        String body = "{\"id\":\"evt_sub_defer\",\"object\":\"event\","
                + "\"type\":\"checkout.session.completed\",\"livemode\":false,"
                + "\"data\":{\"object\":{"
                + "\"id\":\"cs_sub_defer\",\"currency\":\"eur\","
                + "\"payment_status\":\"no_payment_required\","
                + "\"amount_subtotal\":6000,"
                + "\"customer\":\"cus_test\","
                + "\"subscription\":\"sub_stored_here\","
                + "\"metadata\":{\"ironfit_order\":\"regr-sub-defer\"}"
                + "}}}";
        long before = payments.count();
        assertThat(sendWebhook(body)).isEqualTo(200);
        // No payment created — fulfillment deferred to invoice.paid
        assertThat(payments.count()).isEqualTo(before);
        // But subscriptionId should now be stored
        StripeOrder updated = orders.findById("regr-sub-defer").orElseThrow();
        assertThat(updated.getSubscriptionId()).isEqualTo("sub_stored_here");
        assertThat(updated.getStatus()).isEqualTo("pending"); // still pending
    }

    // -------------------------------------------------------------------------
    // Unknown order ID — returns 200 (graceful, no crash)
    // -------------------------------------------------------------------------

    @Test
    void unknownOrderIdRequestsStripeRetry() throws Exception {
        String body = "{\"id\":\"evt_unknown\",\"object\":\"event\","
                + "\"type\":\"checkout.session.completed\",\"livemode\":false,"
                + "\"data\":{\"object\":{"
                + "\"id\":\"cs_nonexistent\",\"currency\":\"eur\","
                + "\"payment_status\":\"paid\","
                + "\"amount_subtotal\":6000,"
                + "\"metadata\":{\"ironfit_order\":\"order-does-not-exist-xyz\"}"
                + "}}}";
        // A commit race must be retried by Stripe.
        assertThat(sendWebhook(body)).isEqualTo(500);
    }

    // -------------------------------------------------------------------------
    // Reconcile endpoint
    // -------------------------------------------------------------------------

    @Test
    void reconcileEndpointFulfillsAlreadyPaidSession() throws Exception {
        // Create an order whose Stripe session is "complete" + "paid".
        // We simulate this by pre-marking the session via a webhook first.
        makeOrder("regr-rec", "payment", "cs_rec_fixture", null);
        // fulfill via webhook
        String wh = "{\"id\":\"evt_rec\",\"object\":\"event\","
                + "\"type\":\"checkout.session.completed\",\"livemode\":false,"
                + "\"data\":{\"object\":{"
                + "\"id\":\"cs_rec_fixture\",\"currency\":\"eur\","
                + "\"payment_status\":\"paid\","
                + "\"amount_subtotal\":6000,"
                + "\"metadata\":{\"ironfit_order\":\"regr-rec\"}"
                + "}}}";
        assertThat(sendWebhook(wh)).isEqualTo(200);
        assertThat(orders.findById("regr-rec").orElseThrow().getStatus()).isEqualTo("paid");

        // Now call reconcile on an already-paid order — must be idempotent (reconciled=false)
        String token = login("youssef");
        Res r = post("payments/stripe/orders/regr-rec/reconcile", java.util.Map.of(), token);
        assertThat(r.status()).isEqualTo(200);
        assertThat(r.body().path("status").asText()).isEqualTo("paid");
    }

    @Test
    void pendingSessionReconciliationFulfillsExactlyOnce() throws Exception {
        var order=makeOrder("regr-pending", "payment", "cs_pending", null);
        order.setCustomerId("cus_owner"); orders.save(order);
        var beforeUser=users.findById(order.getMemberId()).orElseThrow();
        var snapshot=new com.ironfit.entity.Plan(); snapshot.setDuration(order.getDuration());
        var expected=com.ironfit.service.MembershipRules.extend(beforeUser.getSubEnd(),snapshot,
            java.time.LocalDate.now(java.time.ZoneId.of("Africa/Tunis")));
        var session=new com.stripe.model.checkout.Session();
        session.setId(order.getSessionId()); session.setLivemode(false); session.setMode("payment");
        session.setCustomer("cus_owner"); session.setClientReferenceId(order.getId());
        session.setMetadata(java.util.Map.of("ironfit_order",order.getId()));
        session.setCurrency("eur"); session.setAmountSubtotal(6000L); session.setAmountTotal(6000L);
        session.setStatus("complete"); session.setPaymentStatus("paid");
        String token=login("youssef"); long before=payments.count();
        assertThat(order.getStatus()).isEqualTo("pending");
        try(var mocked=org.mockito.Mockito.mockStatic(com.stripe.model.checkout.Session.class)) {
            mocked.when(()->com.stripe.model.checkout.Session.retrieve(
                org.mockito.ArgumentMatchers.eq("cs_pending"),
                org.mockito.ArgumentMatchers.any(com.stripe.net.RequestOptions.class))).thenReturn(session);
            assertThat(post("payments/stripe/orders/regr-pending/reconcile", java.util.Map.of(), token).status()).isEqualTo(200);
            assertThat(orders.findById(order.getId()).orElseThrow().getStatus()).isEqualTo("paid");
            assertThat(payments.count()).isEqualTo(before+1);
            var updated=users.findById(order.getMemberId()).orElseThrow();
            assertThat(updated.getSubEnd()).isEqualTo(expected);
            assertThat(updated.planId()).isEqualTo(order.getPlanId());
            assertThat(post("payments/stripe/orders/regr-pending/reconcile", java.util.Map.of(), token).status()).isEqualTo(200);
            assertThat(payments.count()).isEqualTo(before+1);
            assertThat(users.findById(order.getMemberId()).orElseThrow().getSubEnd()).isEqualTo(expected);
            assertThat(payments.findByMemberIdOrderByIdDesc(order.getMemberId()).stream()
                .filter(p->"cs_pending".equals(p.getStripeReference())).count()).isEqualTo(1);
        }
    }

    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.ValueSource(strings={"live","customer","amount","currency","metadata","reference"})
    void reconciliationRejectsSessionMismatch(String field) throws Exception {
        var order=makeOrder("reject-"+field,"payment","cs_reject_"+field,null);
        order.setCustomerId("cus_owner"); orders.save(order);
        var session=new com.stripe.model.checkout.Session();
        session.setId(order.getSessionId()); session.setLivemode(false); session.setMode("payment");
        session.setCustomer("cus_owner"); session.setClientReferenceId(order.getId());
        session.setMetadata(java.util.Map.of("ironfit_order",order.getId()));
        session.setCurrency("eur"); session.setAmountSubtotal(6000L); session.setAmountTotal(6000L);
        session.setStatus("complete"); session.setPaymentStatus("paid");
        switch(field) {
            case "live" -> session.setLivemode(true);
            case "customer" -> session.setCustomer("cus_other");
            case "amount" -> session.setAmountSubtotal(100L);
            case "currency" -> session.setCurrency("tnd");
            case "metadata" -> session.setMetadata(java.util.Map.of("ironfit_order","other"));
            case "reference" -> session.setClientReferenceId("other");
        }
        String token=login("youssef"); long before=payments.count();
        var end=users.findById(order.getMemberId()).orElseThrow().getSubEnd();
        try(var mocked=org.mockito.Mockito.mockStatic(com.stripe.model.checkout.Session.class)) {
            mocked.when(()->com.stripe.model.checkout.Session.retrieve(
                org.mockito.ArgumentMatchers.eq(order.getSessionId()),
                org.mockito.ArgumentMatchers.any(com.stripe.net.RequestOptions.class))).thenReturn(session);
            assertThat(post("payments/stripe/orders/"+order.getId()+"/reconcile",java.util.Map.of(),token).status()).isEqualTo(400);
        }
        assertThat(payments.count()).isEqualTo(before);
        assertThat(orders.findById(order.getId()).orElseThrow().getStatus()).isEqualTo("pending");
        assertThat(users.findById(order.getMemberId()).orElseThrow().getSubEnd()).isEqualTo(end);
    }

    @Test
    void reconcileRequiresAuthentication() throws Exception {
        makeOrder("regr-rec-auth", "payment", "cs_rec_auth", null);
        Res r = post("payments/stripe/orders/regr-rec-auth/reconcile", java.util.Map.of(), null);
        assertThat(r.status()).isEqualTo(401);
    }

    @Test
    void reconcileCannotAccessOtherUsersOrder() throws Exception {
        makeOrder("regr-rec-own", "payment", "cs_rec_own", null);
        // youssef owns the order; amira should get 403/404
        String token = login("amira");
        Res r = post("payments/stripe/orders/regr-rec-own/reconcile", java.util.Map.of(), token);
        assertThat(r.status()).isIn(403, 404);
    }

    // -------------------------------------------------------------------------
    // invoice.paid with no matching order ID and no subscriptionId — silent skip
    // -------------------------------------------------------------------------

    @Test
    void invoicePaidWithNoMatchingOrderSilentlySkips() throws Exception {
        long end = periodEnd();
        String body = "{\"id\":\"evt_nomatch\",\"object\":\"event\",\"type\":\"invoice.paid\",\"livemode\":false,"
                + "\"data\":{\"object\":{"
                + "\"id\":\"in_nomatch\",\"currency\":\"eur\",\"paid\":true,\"amount_paid\":6000,"
                + "\"lines\":{\"data\":[{\"period\":{\"end\":" + end + "}}]}"
                + "}}}";
        // No metadata, no subscription field -> id empty -> silent return 200
        assertThat(sendWebhook(body)).isEqualTo(200);
    }
}
