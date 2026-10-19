'use strict';
// Gestion des membres et coachs (admin), clients d'un coach, annuaire des coachs
const { hash } = require('../security');
const { fail, need, pub, pick, page, like, okMail, okLogin, okPassword, MEMBER_ROLES, isAdmin, isCoach } = require('../util');

const FIELDS = {
  name: ['text', true, 'Nom'], login: ['text', true, 'Identifiant'], email: ['text', true, 'E-mail'], phone: ['text', false, 'Téléphone'],
  plan_id: ['id', false, 'Abonnement'], sub_end: ['date', false, 'Fin d’abonnement'], specialty: ['text', false, 'Spécialité'],
};

module.exports = S => {
  const { d } = S;
  const target = id => { const u = d.one('SELECT * FROM users WHERE id=?', id); if (!u) fail(404, 'Utilisateur introuvable'); if (isAdmin(u)) fail(403, 'Le compte administrateur ne se gère pas ici'); return u; };

  function read(b) {
    const v = pick(b, FIELDS);
    if (v.name.length < 2 || v.name.length > 80) fail(400, 'Nom invalide');
    if (!okLogin(v.login)) fail(400, 'Identifiant : 3 à 20 caractères (lettres, chiffres, . _ -)');
    if (!okMail(v.email)) fail(400, 'E-mail invalide');
    if (v.phone && v.phone.length > 30) fail(400, 'Téléphone invalide');
    if (v.plan_id != null && !d.one('SELECT 1 x FROM plans WHERE id=?', v.plan_id)) fail(400, 'Abonnement introuvable');
    if (b.password && !okPassword(b.password)) fail(400, 'Mot de passe : 6 caractères minimum');
    const role = b.role == null || b.role === '' ? null : String(b.role);
    if (role != null && !MEMBER_ROLES.includes(role)) fail(400, 'Rôle invalide');
    return { v, role };
  }

  /** Un coach rétrogradé ou supprimé perd l'accès à ses clients : on clôt les relations et on prévient les clients. */
  function endCoaching(coachId, why) {
    for (const l of d.q("SELECT * FROM coach_clients WHERE coach_id=? AND status IN ('pending','active')", coachId)) {
      d.run("UPDATE coach_clients SET status='ended', updated=CURRENT_TIMESTAMP WHERE id=?", l.id);
      if (l.status === 'active') S.notify(l.client_id, 'Suivi coaching terminé', why);
    }
  }

  return [
    {
      // Admin : tous les membres et coachs. Coach : uniquement ses clients actifs.
      method: 'GET', path: '/api/members',
      handler: ({ me, query }) => {
        need(isAdmin(me) || isCoach(me));
        const { limit, offset } = page(query), where = [], args = [];
        if (isAdmin(me)) where.push("u.role IN ('athlete','coach')");
        else { where.push("u.id IN (SELECT client_id FROM coach_clients WHERE coach_id=? AND status='active')"); args.push(me.id); }
        const role = query.get('role');
        if (MEMBER_ROLES.includes(role)) { where.push('u.role=?'); args.push(role); }
        const active = query.get('active');
        if (active === '0' || active === '1') { where.push('u.active=?'); args.push(Number(active)); }
        const s = (query.get('q') || '').trim();
        if (s) { where.push("(u.name LIKE ? ESCAPE '\\' OR u.login LIKE ? ESCAPE '\\' OR u.email LIKE ? ESCAPE '\\' OR u.phone LIKE ? ESCAPE '\\')"); args.push(...Array(4).fill(like(s))); }
        return d.q(`SELECT u.*, p.name plan_name FROM users u LEFT JOIN plans p ON p.id=u.plan_id WHERE ${where.join(' AND ')} ORDER BY u.name COLLATE NOCASE LIMIT ? OFFSET ?`, ...args, limit, offset)
          .map(u => ({ ...pub(u), plan_name: u.plan_name }));
      },
    },
    {
      method: 'GET', path: '/api/members/:id',
      handler: ({ me, params }) => {
        const u = S.member(params.id);
        need(S.canSeeMember(me, u.id));
        return { ...pub(u), plan_name: d.one('SELECT name FROM plans WHERE id=?', u.plan_id)?.name ?? null };
      },
    },
    {
      method: 'POST', path: '/api/members',
      handler: ({ me, body: b }) => {
        need(isAdmin(me));
        const { v, role } = read(b);
        if (!b.password) fail(400, 'Mot de passe obligatoire');
        const cols = Object.keys(FIELDS);
        const id = d.run(`INSERT INTO users(${cols},role,pwd) VALUES(${cols.map(() => '?')},?,?)`, ...cols.map(k => v[k]), role || 'athlete', hash(b.password)).lastInsertRowid;
        return { id: Number(id) };
      },
    },
    {
      method: 'PUT', path: '/api/members/:id',
      handler: ({ me, params, body: b }) => {
        need(isAdmin(me));
        const u = target(params.id), { v, role } = read(b), cols = Object.keys(FIELDS);
        d.tx(() => {
          d.run(`UPDATE users SET ${cols.map(k => k + '=?')}, role=? WHERE id=?`, ...cols.map(k => v[k]), role || u.role, u.id);
          if (b.password) d.run('UPDATE users SET pwd=?, tv=tv+1 WHERE id=?', hash(b.password), u.id);
          if (u.role === 'coach' && role === 'athlete') endCoaching(u.id, `${u.name} n'est plus coach à la salle.`);
        });
        return { ok: true };
      },
    },
    {
      // Activer / désactiver un compte. La désactivation révoque immédiatement ses sessions.
      method: 'POST', path: '/api/members/:id/status',
      handler: ({ me, params, body: b }) => {
        need(isAdmin(me));
        const u = target(params.id), active = b.active === true || b.active === 1 || b.active === 'true';
        d.run(`UPDATE users SET active=?${active ? '' : ', tv=tv+1'} WHERE id=?`, active ? 1 : 0, u.id);
        return { ok: true, active };
      },
    },
    {
      method: 'DELETE', path: '/api/members/:id',
      handler: ({ me, params }) => {
        need(isAdmin(me));
        const u = target(params.id);
        d.tx(() => { if (isCoach(u)) endCoaching(u.id, `${u.name} a quitté la salle.`); d.run('DELETE FROM users WHERE id=?', u.id); });
        return { ok: true };
      },
    },
    {
      // Annuaire des coachs : visible par tous les utilisateurs connectés (pas de données de contact)
      method: 'GET', path: '/api/coaches',
      handler: () => d.q(`SELECT u.id, u.name, u.specialty,
          (SELECT COUNT(*) FROM classes c WHERE c.coach_id=u.id) classes,
          (SELECT COUNT(*) FROM coach_clients cc WHERE cc.coach_id=u.id AND cc.status='active') clients
        FROM users u WHERE u.role='coach' AND u.active=1 ORDER BY u.name COLLATE NOCASE`),
    },
  ];
};
