package com.ironfit.service;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.RecordDtos.*;
import com.ironfit.security.CurrentUser;
import java.util.List;

/**
 * Données rattachées à un membre. Lecture : soi-même par défaut ; {@code memberId} = un membre précis (soi, son client, ou admin) ;
 * {@code scope=clients} = tous les clients actifs du coach ; l'admin voit tout.
 */
public interface MemberRecordService {
    List<PaymentDto> payments(CurrentUser me, Long memberId, String scope, String q, Integer limit, Integer offset);
    IdResponse createPayment(PaymentRequest req);
    void updatePayment(Long id, PaymentRequest req);
    void deletePayment(Long id);

    List<MeasureDto> measures(CurrentUser me, Long memberId, String scope, String q, Integer limit, Integer offset);
    IdResponse createMeasure(CurrentUser me, MeasureRequest req);
    void updateMeasure(CurrentUser me, Long id, MeasureRequest req);
    void deleteMeasure(CurrentUser me, Long id);

    List<CheckinDto> checkins(CurrentUser me, Long memberId, String scope, String q, Integer limit, Integer offset);
    IdResponse createCheckin(CurrentUser me, CheckinRequest req);
    void updateCheckin(CurrentUser me, Long id, CheckinRequest req);
    void deleteCheckin(CurrentUser me, Long id);
}
