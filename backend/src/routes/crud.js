'use strict';
// CRUD générique. Chaque entité déclare ses colonnes (type, obligatoire, libellé) et ses règles :
//  read(me, query)        → [clause WHERE, paramètres] pour filtrer la liste (ou refus)
//  write(me, row, old)    → contrôle création (old = null), modification, suppression (row = null) ;
//                           peut renvoyer des colonnes imposées par le serveur (ex. auteur).
const { fail, deny, need, pick, page, like, today, isAdmin, isCoach, isMember } = require('../util');

module.exports = S => {
  const { d } = S;
  const ALL = () => ['1=1', []];
  const STAFF = me => { need(isAdmin(me) || isCoach(me)); return ['1=1', []]; };
  const ADMIN_W = me => need(isAdmin(me));
  const STAFF_W = me => need(isAdmin(me) || isCoach(me));
  const CLIENTS = "SELECT client_id FROM coach_clients WHERE coach_id=? AND status='active'";

  /** Tables rattachées à un membre : chacun voit les siennes, l'admin tout, le coach ses clients (si `coach`). */
  const memberRead = coach => (me, query) => {
    const mid = Number(query.get('member_id')) || null;
    if (mid) { if (!(isAdmin(me) || me.id === mid || (coach && isCoach(me) && S.coaches(me.id, mid)))) deny(); return ['t.member_id=?', [mid]]; }
    if (isAdmin(me)) return ['1=1', []];
    if (query.get('scope') === 'clients') { need(coach && isCoach(me)); return [`t.member_id IN (${CLIENTS})`, [me.id]]; }
    return ['t.member_id=?', [me.id]];
  };
  const memberTarget = id => S.member(id); // la ligne doit viser un membre existant (pas l'admin)
  const coachOf = (me, id) => isCoach(me) && S.coaches(me.id, id);
  const each = (row, old, fn) => { if (row) fn(row.member_id); if (old) fn(old.member_id); };

  const ENT = {
    plans: { cols: { name: ['text', true, 'Nom'], price: ['num', true, 'Prix'], duration: ['text', false, 'Durée'], descr: ['text', false, 'Description'] }, read: ALL, write: ADMIN_W },
    promos: { cols: { title: ['text', true, 'Titre'], descr: ['text', false, 'Description'], discount: ['pct', false, 'Réduction'], until: ['date', false, 'Date limite'] }, read: ALL, write: ADMIN_W },
    products: { cols: { name: ['text', true, 'Produit'], category: ['text', false, 'Catégorie'], price: ['num', true, 'Prix'], stock: ['int', false, 'Stock'] }, read: ALL, write: ADMIN_W },
    equipment: {
      cols: { name: ['text', true, 'Nom'], category: ['text', false, 'Catégorie'], qty: ['int', false, 'Quantité'], status: ['text', false, 'État'] },
      read: STAFF,
      write: (me, row) => { STAFF_W(me); if (row?.status && !['OK', 'Maintenance', 'Hors service'].includes(row.status)) fail(400, 'État invalide'); },
    },
    classes: {
      cols: { day: ['day', true, 'Jour'], time: ['time', true, 'Heure'], title: ['text', true, 'Activité'], coach_id: ['id', false, 'Coach'], spots: ['int', false, 'Places'] },
      read: ALL,
      write: (me, row, old) => {
        STAFF_W(me);
        if (isCoach(me)) { if (old && old.coach_id !== me.id) fail(403, 'Vous ne pouvez modifier que vos propres séances'); if (row) row.coach_id = me.id; }
        if (!row) return;
        if (row.coach_id != null && !d.one("SELECT 1 x FROM users WHERE id=? AND role='coach'", row.coach_id)) fail(400, 'Coach introuvable');
        if (row.spots == null) row.spots = 10;
        if (row.spots < 1 || row.spots > 500) fail(400, 'Places : 1 à 500');
      },
      after: (me, row, old) => {
        if (!old) return;
        const msg = !row ? ['Séance annulée', `« ${old.title} » (${old.time}) a été retirée du planning.`]
          : row.day !== old.day || row.time !== old.time ? ['Séance modifiée', `« ${row.title} » a lieu désormais à ${row.time}.`] : null;
        if (msg) for (const b of d.q('SELECT user_id FROM bookings WHERE class_id=?', old.id)) S.notify(b.user_id, ...msg);
      },
    },
    announcements: {
      cols: { title: ['text', true, 'Titre'], body: ['text', false, 'Message'], posted_on: ['date', false, 'Date'] },
      join: ', u.name author_name FROM announcements t LEFT JOIN users u ON u.id=t.author_id',
      read: ALL,
      write: (me, row, old) => {
        STAFF_W(me);
        if (isCoach(me) && old && old.author_id !== me.id) fail(403, 'Vous ne pouvez modifier que vos propres annonces');
        if (row && !row.posted_on) row.posted_on = today();
        return old ? {} : { author_id: me.id };
      },
      after: (me, row, old) => {
        if (old || !row) return;
        d.run("INSERT INTO notifications(user_id,title,body) SELECT id, ?, ? FROM users WHERE role IN ('athlete','coach') AND active=1 AND id<>?", 'Annonce : ' + row.title, row.body, me.id);
      },
    },
    payments: {
      member: true,
      cols: { member_id: ['id', true, 'Membre'], amount: ['num', true, 'Montant'], method: ['text', false, 'Mode'], paid_on: ['date', false, 'Date'], note: ['text', false, 'Note'] },
      read: memberRead(false),
      write: (me, row) => { ADMIN_W(me); if (row) memberTarget(row.member_id); },
    },
    measures: {
      member: true,
      cols: { member_id: ['id', true, 'Membre'], measured_on: ['date', false, 'Date'], weight: ['num', false, 'Poids'], body_fat: ['pct', false, 'Masse grasse'], note: ['text', false, 'Note'] },
      read: memberRead(true),
      // Admin, le membre pour lui-même, ou son coach actif
      write: (me, row, old) => {
        each(row, old, id => { memberTarget(id); need(isAdmin(me) || (id === me.id && isMember(me)) || coachOf(me, id)); });
        if (row && row.weight != null && (row.weight < 20 || row.weight > 400)) fail(400, 'Poids : 20 à 400 kg');
        if (row && !row.measured_on) row.measured_on = today();
      },
    },
    checkins: {
      member: true,
      cols: { member_id: ['id', true, 'Membre'], checkin_on: ['date', false, 'Date'], note: ['text', false, 'Note'] },
      read: memberRead(true),
      // Pointage par l'accueil (admin) ou par le coach de ce membre
      write: (me, row, old) => { each(row, old, id => { memberTarget(id); need(isAdmin(me) || coachOf(me, id)); }); if (row && !row.checkin_on) row.checkin_on = today(); },
    },
  };

  const names = Object.keys(ENT).join('|');
  const entity = t => ENT[t];
  const row = (t, id) => { const r = d.one(`SELECT * FROM ${t} WHERE id=?`, id); if (!r) fail(404, 'Élément introuvable'); return r; };

  function save(me, t, b, old) {
    const e = entity(t), v = pick(b, e.cols);
    const forced = e.write(me, v, old) || {};
    const data = { ...v, ...forced }, cols = Object.keys(data);
    let id;
    d.tx(() => {
      if (old) { d.run(`UPDATE ${t} SET ${cols.map(k => k + '=?')} WHERE id=?`, ...cols.map(k => data[k]), old.id); id = old.id; }
      else id = Number(d.run(`INSERT INTO ${t}(${cols}) VALUES(${cols.map(() => '?')})`, ...cols.map(k => data[k])).lastInsertRowid);
      e.after?.(me, { ...data, id }, old);
    });
    return id;
  }

  return [
    {
      method: 'GET', path: `/api/:t(${names})`,
      handler: ({ me, query, params }) => {
        const e = entity(params.t), [where, args] = e.read(me, query), { limit, offset } = page(query);
        const from = e.join || (e.member ? ` , u.name member_name FROM ${params.t} t LEFT JOIN users u ON u.id=t.member_id` : ` FROM ${params.t} t`);
        const s = (query.get('q') || '').trim(), search = [], sargs = [];
        if (s) {
          for (const [k, [type]] of Object.entries(e.cols)) if (type === 'text' || type === 'date') { search.push(`t.${k} LIKE ? ESCAPE '\\'`); sargs.push(like(s)); }
          if (e.member || e.join) { search.push("u.name LIKE ? ESCAPE '\\'"); sargs.push(like(s)); }
        }
        const order = e.member || e.join ? 't.id DESC' : 't.id';
        return d.q(`SELECT t.*${from} WHERE ${where}${search.length ? ` AND (${search.join(' OR ')})` : ''} ORDER BY ${order} LIMIT ? OFFSET ?`, ...args, ...sargs, limit, offset);
      },
    },
    { method: 'POST', path: `/api/:t(${names})`, handler: ({ me, params, body }) => ({ id: save(me, params.t, body, null) }) },
    { method: 'PUT', path: `/api/:t(${names})/:id`, handler: ({ me, params, body }) => { save(me, params.t, body, row(params.t, params.id)); return { ok: true }; } },
    {
      method: 'DELETE', path: `/api/:t(${names})/:id`,
      handler: ({ me, params }) => {
        const e = entity(params.t), old = row(params.t, params.id);
        e.write(me, null, old);
        // `after` avant la suppression : les lignes liées (réservations…) disparaissent en cascade
        d.tx(() => { e.after?.(me, null, old); d.run(`DELETE FROM ${params.t} WHERE id=?`, old.id); });
        return { ok: true };
      },
    },
  ];
};
