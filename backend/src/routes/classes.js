'use strict';
// Planning des cours collectifs, réservations, participants et pointage des présences
// (création / modification / suppression des cours : voir crud.js)
const { fail, need, today, isAdmin, isMember } = require('../util');

module.exports = S => {
  const { d } = S;
  const cls = id => { const c = d.one('SELECT * FROM classes WHERE id=?', id); if (!c) fail(404, 'Séance introuvable'); return c; };
  // Seuls l'admin et le coach qui anime la séance voient ses participants
  const manage = (me, c) => need(isAdmin(me) || (c.coach_id != null && c.coach_id === me.id));

  return [
    {
      method: 'GET', path: '/api/classes',
      handler: ({ me }) => d.q(`SELECT c.*, u.name coach_name, u.specialty coach_specialty,
          (SELECT COUNT(*) FROM bookings b WHERE b.class_id=c.id) taken,
          EXISTS(SELECT 1 FROM bookings b WHERE b.class_id=c.id AND b.user_id=?) mine
        FROM classes c LEFT JOIN users u ON u.id=c.coach_id ORDER BY c.day, c.time`, me.id),
    },
    {
      // Réserver / annuler (bascule). Ouvert aux membres, y compris les coachs qui s'entraînent.
      method: 'POST', path: '/api/book',
      handler: ({ me, body: b }) => {
        need(isMember(me));
        const c = cls(Number(b.class_id));
        if (d.one('SELECT 1 x FROM bookings WHERE user_id=? AND class_id=?', me.id, c.id)) {
          d.run('DELETE FROM bookings WHERE user_id=? AND class_id=?', me.id, c.id);
          return { ok: true, booked: false };
        }
        if (c.coach_id === me.id) fail(400, 'Vous animez cette séance');
        if (!me.sub_end || me.sub_end < today()) fail(403, 'Abonnement actif requis pour réserver (voir Explorer → Tarifs)');
        if (d.one('SELECT COUNT(*) n FROM bookings WHERE class_id=?', c.id).n >= c.spots) fail(409, 'Séance complète');
        d.run('INSERT INTO bookings(user_id,class_id) VALUES(?,?)', me.id, c.id);
        return { ok: true, booked: true };
      },
    },
    {
      method: 'GET', path: '/api/classes/:id/participants',
      handler: ({ me, params }) => {
        const c = cls(params.id); manage(me, c);
        return d.q(`SELECT u.id, u.name, u.phone,
            EXISTS(SELECT 1 FROM checkins k WHERE k.member_id=u.id AND k.checkin_on=? AND k.note=?) present
          FROM bookings b JOIN users u ON u.id=b.user_id WHERE b.class_id=? ORDER BY u.name COLLATE NOCASE`, today(), c.title, c.id);
      },
    },
    {
      method: 'POST', path: '/api/classes/:id/present',
      handler: ({ me, params, body: b }) => {
        const c = cls(params.id); manage(me, c);
        const member = Number(b.member_id);
        if (!d.one('SELECT 1 x FROM bookings WHERE user_id=? AND class_id=?', member, c.id)) fail(404, 'Ce membre n’a pas réservé cette séance');
        if (c.day !== (new Date().getDay() + 6) % 7) fail(400, 'Le pointage se fait le jour de la séance');
        if (!d.one('SELECT 1 x FROM checkins WHERE member_id=? AND checkin_on=? AND note=?', member, today(), c.title)) {
          d.run('INSERT INTO checkins(member_id,checkin_on,note) VALUES(?,?,?)', member, today(), c.title);
        }
        return { ok: true };
      },
    },
  ];
};
