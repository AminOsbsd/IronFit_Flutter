'use strict';
// Tableaux de bord : vue globale pour l'admin, vue limitée à ses clients et ses cours pour un coach
const { need, iso, today, isAdmin, isCoach } = require('../util');

module.exports = S => {
  const { d } = S;
  const n = (sql, ...a) => d.one(sql, ...a).n;

  function admin() {
    const t = today(), in7 = iso(new Date(Date.now() + 7 * 864e5)), ago7 = iso(new Date(Date.now() - 7 * 864e5));
    const M = "role IN ('athlete','coach')";
    return {
      athletes: n(`SELECT COUNT(*) n FROM users WHERE ${M}`),
      coaches: n("SELECT COUNT(*) n FROM users WHERE role='coach'"),
      active: n(`SELECT COUNT(*) n FROM users WHERE ${M} AND sub_end>=?`, t),
      expired: n(`SELECT COUNT(*) n FROM users WHERE role='athlete' AND (sub_end IS NULL OR sub_end<?)`, t),
      disabled: n(`SELECT COUNT(*) n FROM users WHERE ${M} AND active=0`),
      expiring: d.q(`SELECT id,name,sub_end,plan_id FROM users WHERE ${M} AND sub_end BETWEEN ? AND ? ORDER BY sub_end`, t, in7),
      lapsed: d.q(`SELECT id,name,sub_end,plan_id FROM users WHERE ${M} AND sub_end<? ORDER BY sub_end DESC LIMIT 10`, t),
      pending: n("SELECT COUNT(*) n FROM requests WHERE status='pending'"),
      coachings: n("SELECT COUNT(*) n FROM coach_clients WHERE status='active'"),
      pendingCoachings: n("SELECT COUNT(*) n FROM coach_clients WHERE status='pending'"),
      workouts7d: n('SELECT COUNT(*) n FROM workouts WHERE done_on>=?', ago7),
      bookings: n('SELECT COUNT(*) n FROM bookings'),
      lowStock: d.q('SELECT id,name,stock FROM products WHERE stock<=5 ORDER BY stock'),
      maintenance: d.q("SELECT id,name,status FROM equipment WHERE status!='OK'"),
      checkinsToday: n('SELECT COUNT(*) n FROM checkins WHERE checkin_on=?', t),
      revenue: d.q('SELECT substr(paid_on,1,7) m, SUM(amount) total FROM payments WHERE paid_on IS NOT NULL GROUP BY m ORDER BY m DESC LIMIT 6').reverse(),
      fill: d.q('SELECT c.id, c.title, c.day, c.time, c.spots, (SELECT COUNT(*) FROM bookings b WHERE b.class_id=c.id) taken FROM classes c ORDER BY taken*1.0/MAX(c.spots,1) DESC LIMIT 5'),
    };
  }

  function coach(me) {
    const t = today(), in7 = iso(new Date(Date.now() + 7 * 864e5)), ago7 = iso(new Date(Date.now() - 7 * 864e5));
    const CL = "SELECT client_id FROM coach_clients WHERE coach_id=? AND status='active'";
    return {
      clients: n(`SELECT COUNT(*) n FROM (${CL})`, me.id),
      pendingClients: n("SELECT COUNT(*) n FROM coach_clients WHERE coach_id=? AND status='pending'", me.id),
      programs: n(`SELECT COUNT(*) n FROM programs WHERE coach_id=? AND active=1 AND client_id IN (${CL})`, me.id, me.id),
      workouts7d: n(`SELECT COUNT(*) n FROM workouts w JOIN programs p ON p.id=w.program_id WHERE p.coach_id=? AND w.done_on>=? AND w.user_id IN (${CL})`, me.id, ago7, me.id),
      toReview: n(`SELECT COUNT(*) n FROM workouts w JOIN programs p ON p.id=w.program_id WHERE p.coach_id=? AND w.coach_comment IS NULL AND w.user_id IN (${CL})`, me.id, me.id),
      expiring: d.q(`SELECT id,name,sub_end FROM users WHERE id IN (${CL}) AND sub_end BETWEEN ? AND ? ORDER BY sub_end`, me.id, t, in7),
      maintenance: d.q("SELECT id,name,status FROM equipment WHERE status!='OK'"),
      fill: d.q('SELECT c.id, c.title, c.day, c.time, c.spots, (SELECT COUNT(*) FROM bookings b WHERE b.class_id=c.id) taken FROM classes c WHERE c.coach_id=? ORDER BY c.day, c.time', me.id),
    };
  }

  return [{ method: 'GET', path: '/api/stats', handler: ({ me }) => { need(isAdmin(me) || isCoach(me)); return isAdmin(me) ? admin() : coach(me); } }];
};
