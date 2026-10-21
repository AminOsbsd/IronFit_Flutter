package com.ironfit.controller;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.CommonDtos.OkResponse;
import com.ironfit.dto.RecordDtos.*;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.MemberRecordService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * Paiements, mesures et présences. Paramètres de lecture : member_id (un membre), scope=clients (clients du coach), q, limit, offset.
 */
@RestController
@RequestMapping("/api")
public class MemberRecordController {
    private final MemberRecordService records;

    public MemberRecordController(MemberRecordService records) { this.records = records; }

    // ---------- Paiements ----------
    @GetMapping("/payments")
    public List<PaymentDto> payments(@AuthenticationPrincipal CurrentUser me, @RequestParam(name = "member_id", required = false) Long memberId,
                                     @RequestParam(required = false) String scope, @RequestParam(required = false) String q,
                                     @RequestParam(required = false) Integer limit, @RequestParam(required = false) Integer offset) {
        return records.payments(me, memberId, scope, q, limit, offset);
    }

    @PostMapping("/payments")
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse createPayment(@Valid @RequestBody PaymentRequest body) { return records.createPayment(body); }

    @PutMapping("/payments/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public OkResponse updatePayment(@PathVariable Long id, @Valid @RequestBody PaymentRequest body) { records.updatePayment(id, body); return OkResponse.OK; }

    @DeleteMapping("/payments/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public OkResponse deletePayment(@PathVariable Long id) { records.deletePayment(id); return OkResponse.OK; }

    // ---------- Mesures ----------
    @GetMapping("/measures")
    public List<MeasureDto> measures(@AuthenticationPrincipal CurrentUser me, @RequestParam(name = "member_id", required = false) Long memberId,
                                     @RequestParam(required = false) String scope, @RequestParam(required = false) String q,
                                     @RequestParam(required = false) Integer limit, @RequestParam(required = false) Integer offset) {
        return records.measures(me, memberId, scope, q, limit, offset);
    }

    @PostMapping("/measures")
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse createMeasure(@AuthenticationPrincipal CurrentUser me, @Valid @RequestBody MeasureRequest body) { return records.createMeasure(me, body); }

    @PutMapping("/measures/{id}")
    public OkResponse updateMeasure(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id, @Valid @RequestBody MeasureRequest body) {
        records.updateMeasure(me, id, body);
        return OkResponse.OK;
    }

    @DeleteMapping("/measures/{id}")
    public OkResponse deleteMeasure(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id) { records.deleteMeasure(me, id); return OkResponse.OK; }

    // ---------- Présences ----------
    @GetMapping("/checkins")
    public List<CheckinDto> checkins(@AuthenticationPrincipal CurrentUser me, @RequestParam(name = "member_id", required = false) Long memberId,
                                     @RequestParam(required = false) String scope, @RequestParam(required = false) String q,
                                     @RequestParam(required = false) Integer limit, @RequestParam(required = false) Integer offset) {
        return records.checkins(me, memberId, scope, q, limit, offset);
    }

    @PostMapping("/checkins")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse createCheckin(@AuthenticationPrincipal CurrentUser me, @Valid @RequestBody CheckinRequest body) { return records.createCheckin(me, body); }

    @PutMapping("/checkins/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    public OkResponse updateCheckin(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id, @Valid @RequestBody CheckinRequest body) {
        records.updateCheckin(me, id, body);
        return OkResponse.OK;
    }

    @DeleteMapping("/checkins/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    public OkResponse deleteCheckin(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id) { records.deleteCheckin(me, id); return OkResponse.OK; }
}
