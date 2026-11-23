package com.ironfit.controller;
import com.ironfit.service.StripeCheckoutService;
import com.ironfit.security.CurrentUser;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.util.*;
@RestController @RequestMapping("/api/payments/stripe")
public class StripePaymentController {
 private final StripeCheckoutService service;
 public StripePaymentController(StripeCheckoutService service){this.service=service;}
 public record CheckoutRequest(Long planId,String requestId){}
 @PostMapping("/checkout") public Map<String,Object> checkout(@AuthenticationPrincipal CurrentUser user,@RequestBody CheckoutRequest request)throws Exception{return service.checkout(user,request.planId(),request.requestId());}
 @GetMapping("/orders/{id}") public Map<String,Object> status(@AuthenticationPrincipal CurrentUser user,@PathVariable String id)throws Exception{return service.status(user,id);}
 @PostMapping("/orders/{id}/cancel") public Map<String,Boolean> cancel(@AuthenticationPrincipal CurrentUser user,@PathVariable String id)throws Exception{service.cancel(user,id);return Map.of("canceled",true);}
 @PostMapping("/orders/{id}/reconcile") public Map<String,Object> reconcile(@AuthenticationPrincipal CurrentUser user,@PathVariable String id)throws Exception{return service.reconcile(user,id);}
 @GetMapping("/history") public List<Map<String,Object>> history(@AuthenticationPrincipal CurrentUser user){return service.history(user);}
 @PostMapping("/portal") public Map<String,String> portal(@AuthenticationPrincipal CurrentUser user)throws Exception{return service.portal(user);}
 @PostMapping("/webhook") public Map<String,Boolean> webhook(@RequestBody String payload,@RequestHeader(value="Stripe-Signature",required=false) String signature)throws Exception{service.webhook(payload,signature);return Map.of("received",true);}
}
