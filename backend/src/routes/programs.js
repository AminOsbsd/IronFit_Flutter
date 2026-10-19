'use strict';
// Programmes d'entraînement, exercices et séances réalisées.
//  - Programme personnel : coach_id NULL, créé et modifié par le membre lui-même.
//  - Programme de coaching : coach_id = auteur ; modifiable par ce coach tant que la relation est active.
// Un coach qui s'entraîne voit ses propres programmes (scope=personal) séparément de ceux qu'il écrit (scope=coaching).
const { fail, need, deny, pick, page, today, isAdmin, isCoach, isMember } = require('../util');

const PROGRAM = { title: ['text', true, 'Titre'], goal: ['text', false, 'Objectif'], notes: ['text', false, 'Notes'] };
const EXERCISE = { day: ['text', false, 'Jour'], name: ['text', true, 'Exercice'], sets: ['int', false, 'Séries'], reps: ['text', false, 'Répétitions'], load: ['text', false, 'Charge'], rest: ['text', false, 'Repos'], notes: ['text', false, 'Notes'], position: ['int', false, 'Ordre'] };
const WORKOUT = { program_id: ['id', false, 'Programme'], done_on: ['date', false, 'Date'], duration: ['int', false, 'Durée'], rpe: ['int', false, 'Difficulté'], notes: ['text', false, 'Notes'] };

module.exports = S => {
  const { d } = S;
  const LIST = `SELECT p.*, co.name coach_name, cl.name client_name,
      (SELECT COUNT(*) FROM exercises e WHERE e.program_id=p.id) exercises,
      (SELECT COUNT(*) FROM workouts w WHERE w.program_id=p.id) sessions,
      (SELECT MAX(w.done_on) FROM workouts w WHERE w.program_id=p.id) last_done
    FROM programs p LEFT JOIN users co ON co.id=p.coach_id JOIN users cl ON cl.id=p.client_id`;

  const program = id => { const p = d.one('SELECT * FROM programs WHERE id=?', id); if (!p) fail(404, 'Programme introuvable'); return p; };
  const isAuthor = (me, p) => p.coach_id != null && p.coach_id === me.id && isCoach(me) && S.coaches(me.id, p.client_id);
  const canRead = (me, p) => isAdmin(me) || p.client_id === me.id || isAuthor(me, p);
  const canEdit = (me, p) => (p.coach_id == null ? p.client_id === me.id : isAuthor(me, p));
  const editable = (id, me) => { const p = program(id); if (!canEdit(me, p)) deny(); return p; };
  const exercise = id => { const e = d.one('SELECT * FROM exercises WHERE id=?', id); if (!e) fail(404, 'Exercice introuvable'); return e; };
  const checkWorkout = w => {
    if (w.duration != null && (w.duration < 1 || w.duration > 600)) fail(400, 'Durée : 1 à 600 minutes');
    if (w.rpe != null && (w.rpe < 1 || w.rpe > 10)) fail(400, 'Difficulté : 1 à 10');
  };

  return [
    {
      method: 'GET', path: '/api/programs',
      handler: ({ me, query }) => {
        const scope = query.get('scope') || 'personal';
        if (scope === 'personal') { need(isMember(me)); return d.q(`${LIST} WHERE p.client_id=? ORDER BY p.active DESC, p.id DESC`, me.id); }
        if (scope === 'coaching') {
          need(isCoach(me));
          const client = Number(query.get('client_id')) || null;
          return d.q(`${LIST} WHERE p.coach_id=? AND (? IS NULL OR p.client_id=?)
            AND EXISTS(SELECT 1 FROM coach_clients cc WHERE cc.coach_id=p.coach_id AND cc.client_id=p.client_id AND cc.status='active')
            ORDER BY p.active DESC, p.id DESC`, me.id, client, client);
        }
        if (scope === 'all') { need(isAdmin(me)); const { limit, offset } = page(query); return d.q(`${LIST} ORDER BY p.id DESC LIMIT ? OFFSET ?`, limit, offset); }
        fail(400, 'Paramètre scope invalide');
      },
    },
    {
      method: 'GET', path: '/api/programs/:id',
      handler: ({ me, params }) => {
        const p = program(params.id);
        need(canRead(me, p));
        return {
          ...d.one(`${LIST} WHERE p.id=?`, p.id),
          can_edit: canEdit(me, p),
          can_log: p.client_id === me.id,
          can_comment: isAuthor(me, p),
          items: d.q('SELECT * FROM exercises WHERE program_id=? ORDER BY day, position, id', p.id),
          workouts: d.q('SELECT * FROM workouts WHERE program_id=? ORDER BY done_on DESC, id DESC LIMIT 30', p.id),
        };
      },
    },
    {
      method: 'POST', path: '/api/programs',
      handler: ({ me, body: b }) => {
        const v = pick(b, PROGRAM), client = b.client_id == null || b.client_id === '' ? me.id : Number(b.client_id);
        let coachId = null;
        if (client === me.id) need(isMember(me));
        else { need(isCoach(me) && S.coaches(me.id, client)); coachId = me.id; }
        const id = Number(d.run('INSERT INTO programs(client_id,coach_id,title,goal,notes) VALUES(?,?,?,?,?)', client, coachId, v.title, v.goal, v.notes).lastInsertRowid);
        if (coachId) S.notify(client, 'Nouveau programme', `${me.name} vous a préparé « ${v.title} ».`);
        return { id };
      },
    },
    {
      method: 'PUT', path: '/api/programs/:id',
      handler: ({ me, params, body: b }) => {
        const p = editable(params.id, me), v = pick(b, PROGRAM);
        const active = b.active == null ? p.active : (b.active === true || b.active === 1 || b.active === '1') ? 1 : 0;
        d.run('UPDATE programs SET title=?, goal=?, notes=?, active=? WHERE id=?', v.title, v.goal, v.notes, active, p.id);
        return { ok: true };
      },
    },
    { method: 'DELETE', path: '/api/programs/:id', handler: ({ me, params }) => { const p = editable(params.id, me); d.run('DELETE FROM programs WHERE id=?', p.id); return { ok: true }; } },
    {
      method: 'POST', path: '/api/programs/:id/exercises',
      handler: ({ me, params, body: b }) => {
        const p = editable(params.id, me), v = pick(b, EXERCISE);
        if (v.position == null) v.position = d.one('SELECT COUNT(*) n FROM exercises WHERE program_id=?', p.id).n;
        const cols = Object.keys(EXERCISE);
        return { id: Number(d.run(`INSERT INTO exercises(program_id,${cols}) VALUES(?,${cols.map(() => '?')})`, p.id, ...cols.map(k => v[k])).lastInsertRowid) };
      },
    },
    {
      method: 'PUT', path: '/api/exercises/:id',
      handler: ({ me, params, body: b }) => {
        const e = exercise(params.id); editable(e.program_id, me);
        const v = pick(b, EXERCISE), cols = Object.keys(EXERCISE);
        if (v.position == null) v.position = e.position;
        d.run(`UPDATE exercises SET ${cols.map(k => k + '=?')} WHERE id=?`, ...cols.map(k => v[k]), e.id);
        return { ok: true };
      },
    },
    { method: 'DELETE', path: '/api/exercises/:id', handler: ({ me, params }) => { const e = exercise(params.id); editable(e.program_id, me); d.run('DELETE FROM exercises WHERE id=?', e.id); return { ok: true }; } },

    // ---------- Séances réalisées ----------
    {
      method: 'GET', path: '/api/workouts',
      handler: ({ me, query }) => {
        const { limit, offset } = page(query, 100);
        const user = Number(query.get('user_id')) || me.id, prog = Number(query.get('program_id')) || null;
        const SEL = 'SELECT w.*, p.title program_title, p.coach_id FROM workouts w LEFT JOIN programs p ON p.id=w.program_id';
        if (user === me.id || isAdmin(me)) {
          return d.q(`${SEL} WHERE w.user_id=? AND (? IS NULL OR w.program_id=?) ORDER BY w.done_on DESC, w.id DESC LIMIT ? OFFSET ?`, user, prog, prog, limit, offset);
        }
        // Coach : uniquement les séances liées aux programmes qu'il a écrits pour ce client
        need(isCoach(me) && S.coaches(me.id, user));
        return d.q(`${SEL} WHERE w.user_id=? AND p.coach_id=? AND (? IS NULL OR w.program_id=?) ORDER BY w.done_on DESC, w.id DESC LIMIT ? OFFSET ?`, user, me.id, prog, prog, limit, offset);
      },
    },
    {
      method: 'POST', path: '/api/workouts',
      handler: ({ me, body: b }) => {
        need(isMember(me));
        const v = pick(b, WORKOUT);
        checkWorkout(v);
        if (v.done_on == null) v.done_on = today();
        if (v.done_on > today()) fail(400, 'La date ne peut pas être dans le futur');
        let p = null;
        if (v.program_id != null) { p = program(v.program_id); need(p.client_id === me.id); }
        const id = Number(d.run('INSERT INTO workouts(user_id,program_id,done_on,duration,rpe,notes) VALUES(?,?,?,?,?,?)', me.id, v.program_id, v.done_on, v.duration, v.rpe, v.notes).lastInsertRowid);
        if (p?.coach_id && S.coaches(p.coach_id, me.id)) S.notify(p.coach_id, 'Séance terminée', `${me.name} a réalisé « ${p.title} » (${v.done_on}).`);
        return { id };
      },
    },
    {
      method: 'DELETE', path: '/api/workouts/:id',
      handler: ({ me, params }) => {
        const w = d.one('SELECT * FROM workouts WHERE id=?', params.id);
        if (!w) fail(404, 'Séance introuvable');
        need(w.user_id === me.id);
        d.run('DELETE FROM workouts WHERE id=?', w.id);
        return { ok: true };
      },
    },
    {
      method: 'POST', path: '/api/workouts/:id/feedback',
      handler: ({ me, params, body: b }) => {
        const w = d.one('SELECT w.*, p.coach_id, p.client_id, p.title FROM workouts w JOIN programs p ON p.id=w.program_id WHERE w.id=?', params.id);
        if (!w) fail(404, 'Séance introuvable');
        need(isAuthor(me, w));
        const comment = String(b.comment || '').trim().slice(0, 1000) || null;
        d.run('UPDATE workouts SET coach_comment=? WHERE id=?', comment, w.id);
        if (comment) S.notify(w.user_id, 'Nouveau commentaire de votre coach', `${me.name} a commenté votre séance « ${w.title} ».`);
        return { ok: true };
      },
    },
  ];
};
