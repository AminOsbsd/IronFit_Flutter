'use strict';
// Demandes d'abonnement (membre → admin) et renouvellement par l'admin
const { fail, need, today, extend, isAdmin, isMember } = require('../util');

const METHODS = ['Espèces', 'Carte', 'Virement', 'Chèque'];

module.exports = S => {
  const { d } = S;

  /** Active / prolonge l'abonnement d'un membre (athlète ou coach) et enregistre le paiement correspondant. */
  function activate(userId, planId, method) {
    const p = d.one('SELECT * FROM plans WHERE id=?', planId), u = d.one("SELECT * FROM users WHERE id=? AND role IN ('athlete','coach')", userId);
    if (!p || !u) fail(404, 'Membre ou tarif introuvable');
    const end = extend(u.sub_end, p.duration);
    d.run('UPDATE users SET plan_id=?, sub_end=? WHERE id=?', p.id, end, u.id);
    d.run('INSERT INTO payments(member_id,amount,method,paid_on,note) VALUES(?,?,?,?,?)', u.id, p.price, METHODS.includes(method) ? method : 'Espèces', today(), 'Abonnement ' + p.name);
    S.notify(u.id, 'Abonnement activé', `${p.name} — valable jusqu’au ${end}.`);
  }

  return [
    {
      method: 'GET', path: '/api/requests',
      handler: ({ me }) => {
        if (!isAdmin(me)) return d.q('SELECT r.*, p.name plan_name, p.price FROM requests r JOIN plans p ON p.id=r.plan_id WHERE r.member_id=? ORDER BY r.id DESC', me.id);
        return d.q("SELECT r.*, p.name plan_name, p.price, u.name member_name FROM requests r JOIN plans p ON p.id=r.plan_id JOIN users u ON u.id=r.member_id WHERE r.status='pending' ORDER BY r.id");
      },
    },
    {
      method: 'POST', path: '/api/requests',
      handler: ({ me, body: b }) => {
        need(isMember(me));
        if (!d.one('SELECT 1 x FROM plans WHERE id=?', Number(b.plan_id))) fail(404, 'Tarif introuvable');
        if (d.one("SELECT 1 x FROM requests WHERE member_id=? AND status='pending'", me.id)) fail(409, 'Vous avez déjà une demande en attente');
        return { id: Number(d.run('INSERT INTO requests(member_id,plan_id) VALUES(?,?)', me.id, Number(b.plan_id)).lastInsertRowid) };
      },
    },
    {
      method: 'POST', path: '/api/requests/:id/:action(approve|reject|cancel)',
      handler: ({ me, params, body: b }) => {
        const r = d.one("SELECT * FROM requests WHERE id=? AND status='pending'", params.id);
        if (!r) fail(404, 'Demande introuvable');
        if (params.action === 'cancel') {
          need(me.id === r.member_id);
          d.run("UPDATE requests SET status='cancelled' WHERE id=?", r.id);
          return { ok: true };
        }
        need(isAdmin(me));
        d.tx(() => {
          if (params.action === 'approve') activate(r.member_id, r.plan_id, b.method);
          else S.notify(r.member_id, 'Demande d’abonnement refusée', 'Rapprochez-vous de l’accueil pour plus d’informations.');
          d.run('UPDATE requests SET status=? WHERE id=?', params.action === 'approve' ? 'approved' : 'rejected', r.id);
        });
        return { ok: true };
      },
    },
    {
      method: 'POST', path: '/api/members/:id/renew',
      handler: ({ me, params, body: b }) => { need(isAdmin(me)); d.tx(() => activate(params.id, Number(b.plan_id), b.method)); return { ok: true }; },
    },
  ];
};
