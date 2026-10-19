'use strict';
// Relations coach ↔ client. Un coach n'accède aux données d'un membre que si la relation est « active ».
const { fail, need, isAdmin, isCoach, isMember } = require('../util');

module.exports = S => {
  const { d } = S;
  const SELECT = `SELECT cc.*, co.name coach_name, co.specialty coach_specialty, cl.name client_name, cl.login client_login,
      CASE WHEN cc.status='active' THEN cl.phone END client_phone, cl.sub_end client_sub_end,
      (SELECT MAX(w.done_on) FROM workouts w JOIN programs p ON p.id=w.program_id WHERE w.user_id=cc.client_id AND p.coach_id=cc.coach_id) last_workout
    FROM coach_clients cc JOIN users co ON co.id=cc.coach_id JOIN users cl ON cl.id=cc.client_id`;
  const link = id => { const l = d.one('SELECT * FROM coach_clients WHERE id=?', id); if (!l) fail(404, 'Relation introuvable'); return l; };
  const coach = id => { const u = d.one("SELECT * FROM users WHERE id=? AND role='coach' AND active=1", id); if (!u) fail(404, 'Coach introuvable'); return u; };
  const upsert = (coachId, clientId, status) => d.run(
    `INSERT INTO coach_clients(coach_id,client_id,status) VALUES(?,?,?)
     ON CONFLICT(coach_id,client_id) DO UPDATE SET status=excluded.status, updated=CURRENT_TIMESTAMP`, coachId, clientId, status);

  return [
    // Mes coachs (vue membre)
    { method: 'GET', path: '/api/coaching/mine', handler: ({ me }) => d.q(`${SELECT} WHERE cc.client_id=? ORDER BY cc.status='active' DESC, cc.updated DESC`, me.id) },
    {
      // Mes clients (vue coach) : demandes en attente et suivis actifs
      method: 'GET', path: '/api/coaching/clients',
      handler: ({ me }) => { need(isCoach(me)); return d.q(`${SELECT} WHERE cc.coach_id=? AND cc.status IN ('pending','active') ORDER BY cc.status='pending' DESC, cl.name COLLATE NOCASE`, me.id); },
    },
    {
      // Toutes les relations (admin)
      method: 'GET', path: '/api/coaching',
      handler: ({ me, query }) => {
        need(isAdmin(me));
        const st = query.get('status');
        return ['pending', 'active', 'declined', 'ended'].includes(st)
          ? d.q(`${SELECT} WHERE cc.status=? ORDER BY cc.updated DESC`, st)
          : d.q(`${SELECT} ORDER BY cc.status='active' DESC, cc.updated DESC`);
      },
    },
    {
      method: 'POST', path: '/api/coaching/request',
      handler: ({ me, body: b }) => {
        need(isMember(me));
        const c = coach(Number(b.coach_id));
        if (c.id === me.id) fail(400, 'Vous ne pouvez pas être votre propre coach');
        const cur = d.one('SELECT status FROM coach_clients WHERE coach_id=? AND client_id=?', c.id, me.id);
        if (cur?.status === 'active') fail(409, `${c.name} est déjà votre coach`);
        if (cur?.status === 'pending') fail(409, 'Demande déjà envoyée');
        upsert(c.id, me.id, 'pending');
        S.notify(c.id, 'Nouvelle demande de coaching', `${me.name} souhaite être suivi(e) par vous.`);
        return { ok: true };
      },
    },
    {
      method: 'POST', path: '/api/coaching/assign',
      handler: ({ me, body: b }) => {
        need(isAdmin(me));
        const c = coach(Number(b.coach_id)), m = S.member(Number(b.client_id));
        if (c.id === m.id) fail(400, 'Un coach ne peut pas être son propre client');
        upsert(c.id, m.id, 'active');
        S.notify(c.id, 'Nouveau client', `${m.name} vous a été attribué(e) par l’administration.`);
        S.notify(m.id, 'Coach attribué', `${c.name} assure désormais votre suivi.`);
        return { ok: true };
      },
    },
    {
      method: 'POST', path: '/api/coaching/:id/:action(accept|decline|end)',
      handler: ({ me, params }) => {
        const l = link(params.id), { action } = params;
        const names = d.one('SELECT co.name coach, cl.name client FROM users co, users cl WHERE co.id=? AND cl.id=?', l.coach_id, l.client_id);
        if (action === 'accept' || action === 'decline') {
          need(me.id === l.coach_id && isCoach(me));
          if (l.status !== 'pending') fail(409, 'Cette demande a déjà été traitée');
          d.run('UPDATE coach_clients SET status=?, updated=CURRENT_TIMESTAMP WHERE id=?', action === 'accept' ? 'active' : 'declined', l.id);
          S.notify(l.client_id, action === 'accept' ? 'Demande de coaching acceptée' : 'Demande de coaching refusée', `${names.coach} a ${action === 'accept' ? 'accepté' : 'décliné'} votre demande.`);
          return { ok: true };
        }
        // Fin du suivi (ou annulation d'une demande) : le coach, le client ou l'admin
        need(me.id === l.coach_id || me.id === l.client_id || isAdmin(me));
        if (!['pending', 'active'].includes(l.status)) fail(409, 'Relation déjà terminée');
        d.run("UPDATE coach_clients SET status='ended', updated=CURRENT_TIMESTAMP WHERE id=?", l.id);
        if (l.status === 'active') {
          if (me.id !== l.client_id) S.notify(l.client_id, 'Suivi coaching terminé', `Votre suivi avec ${names.coach} est terminé.`);
          if (me.id !== l.coach_id) S.notify(l.coach_id, 'Suivi coaching terminé', `${names.client} n’est plus suivi(e) par vous.`);
        }
        return { ok: true };
      },
    },
  ];
};
