package com.ironfit.service.impl;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.RecordDtos.*;
import com.ironfit.entity.Checkin;
import com.ironfit.entity.Measure;
import com.ironfit.entity.Payment;
import com.ironfit.exception.ApiException;
import com.ironfit.repository.CheckinRepository;
import com.ironfit.repository.MeasureRepository;
import com.ironfit.repository.OffsetLimit;
import com.ironfit.repository.PaymentRepository;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import com.ironfit.service.MemberRecordService;
import com.ironfit.service.Texts;
import java.time.LocalDate;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class MemberRecordServiceImpl implements MemberRecordService {
    private static final String NOT_FOUND = "Élément introuvable";
    private final PaymentRepository payments;
    private final MeasureRepository measures;
    private final CheckinRepository checkins;
    private final AccessService access;

    public MemberRecordServiceImpl(PaymentRepository payments, MeasureRepository measures, CheckinRepository checkins, AccessService access) {
        this.payments = payments;
        this.measures = measures;
        this.checkins = checkins;
        this.access = access;
    }

    /** Portée de lecture : tous (admin) ou une liste d'identifiants de membres. */
    private record Scope(boolean all, List<Long> ids) {}

    private Scope scope(CurrentUser me, Long memberId, String scope, boolean coachAccess) {
        if (memberId != null) {
            boolean ok = me.isAdmin() || me.id().equals(memberId) || (coachAccess && access.coachOf(me, memberId));
            AccessService.require(ok);
            return new Scope(false, List.of(memberId));
        }
        if (me.isAdmin()) return new Scope(true, List.of(-1L));
        if ("clients".equals(scope)) {
            AccessService.require(coachAccess && me.isCoach());
            return new Scope(false, access.activeClientIdsOrNone(me.id()));
        }
        return new Scope(false, List.of(me.id()));
    }

    // ---------- Paiements (écriture : admin, vérifiée par le contrôleur) ----------
    @Override
    @Transactional(readOnly = true)
    public List<PaymentDto> payments(CurrentUser me, Long memberId, String scope, String q, Integer limit, Integer offset) {
        Scope s = scope(me, memberId, scope, false);
        return payments.search(s.all(), s.ids(), Texts.like(q), OffsetLimit.of(offset, limit, 500)).stream().map(PaymentDto::of).toList();
    }

    private void apply(Payment p, PaymentRequest r) {
        p.setMember(access.member(r.memberId()));
        p.setAmount(r.amount());
        p.setMethod(Texts.clean(r.method()));
        p.setPaidOn(r.paidOn());
        p.setNote(Texts.clean(r.note()));
    }

    @Override
    public IdResponse createPayment(PaymentRequest req) { Payment p = new Payment(); apply(p, req); return new IdResponse(payments.save(p).getId()); }

    @Override
    public void updatePayment(Long id, PaymentRequest req) { apply(payments.findById(id).orElseThrow(() -> ApiException.notFound(NOT_FOUND)), req); }

    @Override
    public void deletePayment(Long id) { payments.delete(payments.findById(id).orElseThrow(() -> ApiException.notFound(NOT_FOUND))); }

    // ---------- Mesures : admin, le membre pour lui-même, ou son coach actif ----------
    private void canWriteMeasure(CurrentUser me, Long memberId) {
        access.member(memberId);
        AccessService.require(me.isAdmin() || (memberId.equals(me.id()) && me.isMember()) || access.coachOf(me, memberId));
    }

    @Override
    @Transactional(readOnly = true)
    public List<MeasureDto> measures(CurrentUser me, Long memberId, String scope, String q, Integer limit, Integer offset) {
        Scope s = scope(me, memberId, scope, true);
        return measures.search(s.all(), s.ids(), Texts.like(q), OffsetLimit.of(offset, limit, 500)).stream().map(MeasureDto::of).toList();
    }

    private void apply(Measure m, MeasureRequest r) {
        m.setMember(access.member(r.memberId()));
        m.setMeasuredOn(r.measuredOn() == null ? LocalDate.now() : r.measuredOn());
        m.setWeight(r.weight());
        m.setBodyFat(r.bodyFat());
        m.setNote(Texts.clean(r.note()));
    }

    @Override
    public IdResponse createMeasure(CurrentUser me, MeasureRequest req) {
        canWriteMeasure(me, req.memberId());
        Measure m = new Measure();
        apply(m, req);
        return new IdResponse(measures.save(m).getId());
    }

    @Override
    public void updateMeasure(CurrentUser me, Long id, MeasureRequest req) {
        Measure m = measures.findById(id).orElseThrow(() -> ApiException.notFound(NOT_FOUND));
        canWriteMeasure(me, m.getMember().getId());
        canWriteMeasure(me, req.memberId());
        apply(m, req);
    }

    @Override
    public void deleteMeasure(CurrentUser me, Long id) {
        Measure m = measures.findById(id).orElseThrow(() -> ApiException.notFound(NOT_FOUND));
        canWriteMeasure(me, m.getMember().getId());
        measures.delete(m);
    }

    // ---------- Présences : l'accueil (admin) ou le coach de ce membre ----------
    private void canWriteCheckin(CurrentUser me, Long memberId) {
        access.member(memberId);
        AccessService.require(me.isAdmin() || access.coachOf(me, memberId));
    }

    @Override
    @Transactional(readOnly = true)
    public List<CheckinDto> checkins(CurrentUser me, Long memberId, String scope, String q, Integer limit, Integer offset) {
        Scope s = scope(me, memberId, scope, true);
        return checkins.search(s.all(), s.ids(), Texts.like(q), OffsetLimit.of(offset, limit, 500)).stream().map(CheckinDto::of).toList();
    }

    private void apply(Checkin c, CheckinRequest r) {
        c.setMember(access.member(r.memberId()));
        c.setCheckinOn(r.checkinOn() == null ? LocalDate.now() : r.checkinOn());
        c.setNote(Texts.clean(r.note()));
    }

    @Override
    public IdResponse createCheckin(CurrentUser me, CheckinRequest req) {
        canWriteCheckin(me, req.memberId());
        Checkin c = new Checkin();
        apply(c, req);
        return new IdResponse(checkins.save(c).getId());
    }

    @Override
    public void updateCheckin(CurrentUser me, Long id, CheckinRequest req) {
        Checkin c = checkins.findById(id).orElseThrow(() -> ApiException.notFound(NOT_FOUND));
        canWriteCheckin(me, c.getMember().getId());
        canWriteCheckin(me, req.memberId());
        apply(c, req);
    }

    @Override
    public void deleteCheckin(CurrentUser me, Long id) {
        Checkin c = checkins.findById(id).orElseThrow(() -> ApiException.notFound(NOT_FOUND));
        canWriteCheckin(me, c.getMember().getId());
        checkins.delete(c);
    }
}
