package com.ironfit.service;

import com.ironfit.dto.ClassDtos.*;
import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.security.CurrentUser;
import java.util.List;

/** Planning hebdomadaire, réservations, participants et pointage. */
public interface ClassService {
    List<ClassDto> list(CurrentUser me, java.time.LocalDate week);
    default List<ClassDto> list(CurrentUser me) { return list(me, null); }

    IdResponse create(CurrentUser me, ClassRequest req);

    void update(CurrentUser me, Long id, ClassRequest req);

    void delete(CurrentUser me, Long id);

    /** Réserve ou annule (bascule). */
    BookResponse book(CurrentUser me, Long classId, java.time.LocalDate date, Boolean booked);
    default BookResponse book(CurrentUser me, Long classId) { return book(me,classId,null,null); }

    List<ParticipantDto> participants(CurrentUser me, Long classId, java.time.LocalDate date);

    void markPresent(CurrentUser me, Long classId, Long memberId, java.time.LocalDate date);
}
