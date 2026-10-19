'use strict';
// Tests d'intégration de l'API : chaque suite démarre un serveur sur un port libre avec une base temporaire.
//   npm test   (ou : node --test)
const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs'), os = require('os'), path = require('path');
const { start } = require('../server');
const { openDb, MIGRATIONS } = require('../src/db');

async function boot(extra = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ironfit-test-'));
  const app = start({ DATA_DIR: dir, PORT: '0', HOST: '127.0.0.1', QUIET: 'true', RATE_LIMIT: '1000', ADMIN_PASSWORD: 'admin123', SEED_DEMO: 'true', ...extra });
  await app.ready;
  const base = `http://127.0.0.1:${app.server.address().port}/api/`;
  const call = async (method, p, body, token) => {
    const r = await fetch(base + p, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) }, body: body === undefined ? undefined : typeof body === 'string' ? body : JSON.stringify(body) });
    return { status: r.status, body: await r.json() };
  };
  const login = async (l, p = '1234') => { const r = await call('POST', 'login', { login: l, password: p }); assert.equal(r.status, 200, `connexion ${l} : ${JSON.stringify(r.body)}`); return r.body.token; };
  const ids = Object.fromEntries(app.d.q('SELECT login, id FROM users').map(u => [u.login, u.id]));
  return { app, call, login, ids, close: async () => { await app.close(); fs.rmSync(dir, { recursive: true, force: true }); } };
}

describe('Authentification et sessions', () => {
  let t;
  before(async () => { t = await boot(); });
  after(() => t.close());

  test('connexion valide / invalide', async () => {
    assert.equal((await t.call('POST', 'login', { login: 'admin', password: 'admin123' })).status, 200);
    const bad = await t.call('POST', 'login', { login: 'admin', password: 'nope' });
    assert.equal(bad.status, 401);
    assert.equal((await t.call('POST', 'login', { login: 'inconnu', password: 'x' })).status, 401);
  });

  test('les routes protégées exigent un jeton valide et non falsifié', async () => {
    assert.equal((await t.call('GET', 'me')).status, 401);
    const tok = await t.login('youssef');
    assert.equal((await t.call('GET', 'me', undefined, tok)).body.login, 'youssef');
    const [b, s] = tok.split('.');
    const forged = Buffer.from(JSON.stringify({ id: t.ids.admin, tv: 0, exp: Date.now() + 1e6 })).toString('base64url') + '.' + s;
    assert.equal((await t.call('GET', 'me', undefined, forged)).status, 401);
    assert.ok(b);
  });

  test('inscription : validation et rôle membre imposé', async () => {
    assert.equal((await t.call('POST', 'signup', { name: 'A', login: 'ab', email: 'x', password: '1' })).status, 400);
    const r = await t.call('POST', 'signup', { name: 'Nouveau Membre', login: 'nouveau', email: 'nouveau@test.tn', password: 'secret1', role: 'admin' });
    assert.equal(r.status, 200);
    assert.equal(r.body.user.role, 'athlete');
    assert.equal((await t.call('POST', 'signup', { name: 'Doublon', login: 'NOUVEAU', email: 'autre@test.tn', password: 'secret1' })).status, 409);
  });

  test('changer de mot de passe révoque les anciens jetons', async () => {
    const old = await t.login('amira');
    const r = await t.call('POST', 'password', { old: '1234', new: 'nouveau1' }, old);
    assert.equal(r.status, 200);
    assert.equal((await t.call('GET', 'me', undefined, old)).status, 401);
    assert.equal((await t.call('GET', 'me', undefined, r.body.token)).status, 200);
    assert.equal((await t.call('POST', 'login', { login: 'amira', password: 'nouveau1' })).status, 200);
  });

  test('mot de passe oublié : code, essais limités, réinitialisation', async () => {
    const f = await t.call('POST', 'forgot', { email: 'leila@ironfit.local' });
    assert.match(f.body.devCode, /^\d{6}$/);
    assert.equal((await t.call('POST', 'reset', { email: 'leila@ironfit.local', code: '000000', password: 'abcdef' })).status, 400);
    assert.equal((await t.call('POST', 'reset', { email: 'leila@ironfit.local', code: f.body.devCode, password: 'abcdef' })).status, 200);
    assert.equal((await t.call('POST', 'login', { login: 'leila', password: 'abcdef' })).status, 200);
    // e-mail inconnu : même réponse
    assert.deepEqual((await t.call('POST', 'forgot', { email: 'personne@test.tn' })).body.ok, true);
  });

  test('désactivation : sessions coupées et connexion refusée', async () => {
    const admin = await t.login('admin', 'admin123'), y = await t.login('youssef');
    assert.equal((await t.call('POST', `members/${t.ids.youssef}/status`, { active: false }, admin)).status, 200);
    assert.equal((await t.call('GET', 'me', undefined, y)).status, 401);
    assert.equal((await t.call('POST', 'login', { login: 'youssef', password: '1234' })).status, 403);
    await t.call('POST', `members/${t.ids.youssef}/status`, { active: true }, admin);
    assert.equal((await t.call('POST', 'login', { login: 'youssef', password: '1234' })).status, 200);
  });

  test('erreurs HTTP : 404, 405, JSON invalide', async () => {
    const tok = await t.login('youssef');
    assert.equal((await t.call('GET', 'nimporte', undefined, tok)).status, 404);
    assert.equal((await t.call('PUT', 'me', {}, tok)).status, 405);
    assert.equal((await t.call('POST', 'login', '{oops')).status, 400);
  });
});

describe('Limitation de débit', () => {
  test('trop de tentatives de connexion → 429', async () => {
    const t = await boot({ RATE_LIMIT: '3' });
    try {
      const codes = [];
      for (let i = 0; i < 5; i++) codes.push((await t.call('POST', 'login', { login: 'x', password: 'y' })).status);
      assert.deepEqual(codes, [401, 401, 401, 429, 429]);
    } finally { await t.close(); }
  });
});

describe('Contrôle d’accès par rôle', () => {
  let t, admin, coach, member;
  before(async () => { t = await boot(); admin = await t.login('admin', 'admin123'); coach = await t.login('sami'); member = await t.login('youssef'); });
  after(() => t.close());

  test('un membre ne peut pas accéder aux fonctions de gestion', async () => {
    for (const [m, p, b] of [['GET', 'members'], ['GET', 'stats'], ['POST', 'plans', { name: 'X', price: 1 }], ['POST', 'members', {}], ['GET', 'equipment'], ['GET', 'coaching'], ['POST', 'announcements', { title: 'x' }]]) {
      assert.equal((await t.call(m, p, b, member)).status, 403, `${m} ${p}`);
    }
  });

  test('un coach ne peut pas faire d’actions réservées à l’admin', async () => {
    assert.equal((await t.call('POST', 'plans', { name: 'X', price: 1 }, coach)).status, 403);
    assert.equal((await t.call('POST', 'members', { name: 'Xx', login: 'xxx', email: 'x@x.tn', password: '123456' }, coach)).status, 403);
    assert.equal((await t.call('POST', `members/${t.ids.amira}/status`, { active: false }, coach)).status, 403);
    assert.equal((await t.call('GET', 'requests', undefined, coach)).body.every(r => r.member_id === t.ids.sami), true);
  });

  test('paiements : chacun ne voit que les siens, l’admin voit tout', async () => {
    const all = (await t.call('GET', 'payments', undefined, admin)).body;
    assert.ok(all.length >= 3);
    assert.ok((await t.call('GET', 'payments', undefined, member)).body.every(p => p.member_id === t.ids.youssef));
    assert.equal((await t.call('GET', 'payments', undefined, coach)).body.length, 0);
    assert.equal((await t.call('GET', `payments?member_id=${t.ids.youssef}`, undefined, coach)).status, 403);
  });

  test('l’admin gère les utilisateurs, recherche et pagination', async () => {
    const list = (await t.call('GET', 'members?q=karray', undefined, admin)).body;
    assert.deepEqual(list.map(u => u.login), ['youssef']);
    assert.ok(!('pwd' in list[0]) && !('tv' in list[0]));
    assert.equal((await t.call('GET', 'members?limit=2', undefined, admin)).body.length, 2);
    const r = await t.call('POST', 'members', { name: 'Coach Test', login: 'coachtest', email: 'ct@test.tn', password: '123456', role: 'coach', specialty: 'Boxe' }, admin);
    assert.equal(r.status, 200);
    assert.ok((await t.call('GET', 'coaches', undefined, member)).body.some(c => c.name === 'Coach Test'));
    assert.equal((await t.call('PUT', `members/${t.ids.admin}`, { name: 'Pirate', login: 'admin', email: 'a@a.tn' }, admin)).status, 403);
  });
});

describe('Coachs et clients : isolation des données', () => {
  let t, admin, sami, leila, youssef, amira;
  before(async () => {
    t = await boot();
    [admin, sami, leila, youssef, amira] = [await t.login('admin', 'admin123'), await t.login('sami'), await t.login('leila'), await t.login('youssef'), await t.login('amira')];
  });
  after(() => t.close());

  test('un coach ne voit que ses clients actifs', async () => {
    const names = (await t.call('GET', 'members', undefined, sami)).body.map(u => u.login).sort();
    assert.deepEqual(names, ['leila', 'youssef']); // Amira : demande en attente seulement
    assert.equal((await t.call('GET', `members/${t.ids.amira}`, undefined, sami)).status, 403);
    assert.equal((await t.call('GET', 'members', undefined, leila)).body.length, 0);
  });

  test('mesures : accès limité au membre, à son coach et à l’admin', async () => {
    assert.equal((await t.call('GET', `measures?member_id=${t.ids.youssef}`, undefined, sami)).status, 200);
    assert.equal((await t.call('GET', `measures?member_id=${t.ids.youssef}`, undefined, leila)).status, 403);
    assert.equal((await t.call('GET', `measures?member_id=${t.ids.youssef}`, undefined, amira)).status, 403);
    assert.equal((await t.call('POST', 'measures', { member_id: t.ids.amira, weight: 60 }, sami)).status, 403);
    assert.equal((await t.call('POST', 'measures', { member_id: t.ids.admin, weight: 60 }, sami)).status, 404);
    assert.equal((await t.call('POST', 'measures', { member_id: t.ids.youssef, weight: 80 }, sami)).status, 200);
    assert.equal((await t.call('POST', 'measures', { member_id: t.ids.youssef, weight: 'abc' }, sami)).status, 400);
    // le membre peut suivre ses propres mesures
    assert.equal((await t.call('POST', 'measures', { member_id: t.ids.amira, weight: 61 }, amira)).status, 200);
    const clients = (await t.call('GET', 'measures?scope=clients', undefined, sami)).body;
    assert.ok(clients.every(m => [t.ids.youssef, t.ids.leila].includes(m.member_id)));
  });

  test('demande de coaching → acceptation → accès ; fin du suivi → plus d’accès', async () => {
    const pending = (await t.call('GET', 'coaching/clients', undefined, sami)).body.find(l => l.client_id === t.ids.amira);
    assert.equal(pending.status, 'pending');
    assert.equal(pending.client_phone, null);
    assert.equal((await t.call('POST', `coaching/${pending.id}/accept`, undefined, leila)).status, 403);
    assert.equal((await t.call('POST', `coaching/${pending.id}/accept`, undefined, sami)).status, 200);
    assert.equal((await t.call('GET', `measures?member_id=${t.ids.amira}`, undefined, sami)).status, 200);
    const notes = (await t.call('GET', 'notifications', undefined, amira)).body;
    assert.ok(notes.items.some(n => /acceptée/.test(n.title)) && notes.unread >= 1);
    assert.equal((await t.call('POST', `coaching/${pending.id}/end`, undefined, amira)).status, 200);
    assert.equal((await t.call('GET', `measures?member_id=${t.ids.amira}`, undefined, sami)).status, 403);
  });

  test('un membre ne peut pas se choisir lui-même ni un non-coach', async () => {
    assert.equal((await t.call('POST', 'coaching/request', { coach_id: t.ids.leila }, leila)).status, 400);
    assert.equal((await t.call('POST', 'coaching/request', { coach_id: t.ids.youssef }, amira)).status, 404);
    assert.equal((await t.call('POST', 'coaching/request', { coach_id: t.ids.leila }, youssef)).status, 200);
    assert.equal((await t.call('POST', 'coaching/request', { coach_id: t.ids.leila }, youssef)).status, 409);
  });

  test('rétrograder un coach clôt ses suivis et prévient ses clients', async () => {
    const t2 = await boot();
    try {
      const a = await t2.login('admin', 'admin123'), s = await t2.login('sami'), y = await t2.login('youssef');
      const u = (await t2.call('GET', 'members?q=sami', undefined, a)).body[0];
      assert.equal((await t2.call('PUT', `members/${u.id}`, { ...u, role: 'athlete' }, a)).status, 200);
      assert.equal((await t2.call('GET', 'members', undefined, s)).status, 403);
      assert.ok((await t2.call('GET', 'notifications', undefined, y)).body.items.some(n => /terminé/.test(n.title)));
      assert.equal((await t2.call('GET', 'coaching/mine', undefined, y)).body.find(l => l.coach_id === u.id).status, 'ended');
    } finally { await t2.close(); }
  });

  test('l’admin attribue un coach directement', async () => {
    assert.equal((await t.call('POST', 'coaching/assign', { coach_id: t.ids.leila, client_id: t.ids.amira }, admin)).status, 200);
    assert.ok((await t.call('GET', 'members', undefined, leila)).body.some(u => u.id === t.ids.amira));
    assert.equal((await t.call('POST', 'coaching/assign', { coach_id: t.ids.leila, client_id: t.ids.amira }, sami)).status, 403);
  });
});

describe('Coach qui est aussi membre (double rôle)', () => {
  let t, sami, leila, youssef;
  before(async () => { t = await boot(); sami = await t.login('sami'); leila = await t.login('leila'); youssef = await t.login('youssef'); });
  after(() => t.close());

  test('un coach abonné réserve un cours, mais pas le sien', async () => {
    const classes = (await t.call('GET', 'classes', undefined, leila)).body;
    const other = classes.find(c => c.coach_id === t.ids.sami), own = classes.find(c => c.coach_id === t.ids.leila);
    assert.equal((await t.call('POST', 'book', { class_id: other.id }, leila)).body.booked, true);
    assert.equal((await t.call('POST', 'book', { class_id: own.id }, leila)).status, 400);
    // Sami n'a pas d'abonnement : réservation refusée
    assert.equal((await t.call('POST', 'book', { class_id: own.id }, sami)).status, 403);
  });

  test('un coach peut demander un abonnement comme un membre', async () => {
    assert.equal((await t.call('POST', 'requests', { plan_id: 2 }, sami)).status, 200);
  });

  test('programmes personnels et programmes de coaching restent séparés', async () => {
    const personal = (await t.call('GET', 'programs?scope=personal', undefined, leila)).body;
    assert.deepEqual(personal.map(p => p.title), ['Mobilité du matin']);
    assert.equal((await t.call('GET', 'programs?scope=coaching', undefined, leila)).body.length, 0);
    const coaching = (await t.call('GET', 'programs?scope=coaching', undefined, sami)).body;
    assert.ok(coaching.every(p => p.coach_id === t.ids.sami) && coaching.length === 1);
    assert.equal((await t.call('GET', 'programs?scope=personal', undefined, sami)).body.length, 0);
    assert.equal((await t.call('GET', 'programs?scope=coaching', undefined, youssef)).status, 403);
  });

  test('cycle complet : programme du coach → séance du client → commentaire', async () => {
    const p = await t.call('POST', 'programs', { title: 'Gainage', goal: 'Tonus', client_id: t.ids.leila }, sami);
    assert.equal(p.status, 200);
    assert.equal((await t.call('POST', `programs/${p.body.id}/exercises`, { name: 'Planche', sets: 3, reps: '45 s' }, sami)).status, 200);
    // Leila (cliente ici) voit le programme dans son espace perso mais ne peut pas le modifier
    const detail = (await t.call('GET', `programs/${p.body.id}`, undefined, leila)).body;
    assert.equal(detail.can_edit, false);
    assert.equal(detail.can_log, true);
    assert.equal(detail.items.length, 1);
    assert.equal((await t.call('PUT', `programs/${p.body.id}`, { title: 'Hack' }, leila)).status, 403);
    // Youssef (autre client de Sami) n'y a pas accès
    assert.equal((await t.call('GET', `programs/${p.body.id}`, undefined, youssef)).status, 403);
    const w = await t.call('POST', 'workouts', { program_id: p.body.id, duration: 30, rpe: 6, notes: 'Dur !' }, leila);
    assert.equal(w.status, 200);
    assert.ok((await t.call('GET', 'notifications', undefined, sami)).body.items.some(n => /Séance terminée/.test(n.title)));
    assert.equal((await t.call('POST', `workouts/${w.body.id}/feedback`, { comment: 'Top' }, youssef)).status, 403);
    assert.equal((await t.call('POST', `workouts/${w.body.id}/feedback`, { comment: 'Top' }, sami)).status, 200);
    const logs = (await t.call('GET', `workouts?user_id=${t.ids.leila}`, undefined, sami)).body;
    assert.deepEqual(logs.map(l => l.coach_comment), ['Top']); // pas ses séances personnelles
    assert.equal((await t.call('GET', `workouts?user_id=${t.ids.leila}`, undefined, youssef)).status, 403);
  });

  test('validation des séances réalisées', async () => {
    assert.equal((await t.call('POST', 'workouts', { duration: 9999 }, youssef)).status, 400);
    assert.equal((await t.call('POST', 'workouts', { done_on: '2999-01-01' }, youssef)).status, 400);
    const perso = (await t.call('GET', 'programs?scope=personal', undefined, leila)).body[0];
    assert.equal((await t.call('POST', 'workouts', { program_id: perso.id }, youssef)).status, 403);
  });
});

describe('Cours, annonces et intégrité des données', () => {
  let t, admin, sami, leila, youssef;
  before(async () => { t = await boot(); admin = await t.login('admin', 'admin123'); sami = await t.login('sami'); leila = await t.login('leila'); youssef = await t.login('youssef'); });
  after(() => t.close());

  test('validation des cours et propriété du coach', async () => {
    assert.equal((await t.call('POST', 'classes', { day: 9, time: '18:00', title: 'X' }, sami)).status, 400);
    assert.equal((await t.call('POST', 'classes', { day: 1, time: '25:00', title: 'X' }, sami)).status, 400);
    assert.equal((await t.call('POST', 'classes', { day: 1, time: '18:00', title: 'X', spots: 0 }, sami)).status, 400);
    const c = await t.call('POST', 'classes', { day: 1, time: '07:00', title: 'Boxe', coach_id: t.ids.leila }, sami);
    const mine = (await t.call('GET', 'classes', undefined, sami)).body.find(x => x.id === c.body.id);
    assert.equal(mine.coach_id, t.ids.sami); // le coach ne peut créer que pour lui-même
    const leilaClass = (await t.call('GET', 'classes', undefined, sami)).body.find(x => x.coach_id === t.ids.leila);
    assert.equal((await t.call('DELETE', `classes/${leilaClass.id}`, undefined, sami)).status, 403);
    assert.equal((await t.call('GET', `classes/${leilaClass.id}/participants`, undefined, sami)).status, 403);
  });

  test('supprimer un cours prévient les membres inscrits', async () => {
    const c = (await t.call('GET', 'classes', undefined, youssef)).body.find(x => x.coach_id === t.ids.sami);
    await t.call('POST', 'book', { class_id: c.id }, youssef);
    assert.equal((await t.call('DELETE', `classes/${c.id}`, undefined, admin)).status, 200);
    assert.ok((await t.call('GET', 'notifications', undefined, youssef)).body.items.some(n => n.title === 'Séance annulée'));
  });

  test('pointage : seulement les inscrits du cours', async () => {
    const c = (await t.call('GET', 'classes', undefined, sami)).body.find(x => x.coach_id === t.ids.sami);
    assert.equal((await t.call('POST', `classes/${c.id}/present`, { member_id: t.ids.amira }, sami)).status, 404);
  });

  test('annonces : un coach ne modifie que les siennes, les membres sont notifiés', async () => {
    const adminAnn = (await t.call('GET', 'announcements', undefined, sami)).body[0];
    assert.equal((await t.call('DELETE', `announcements/${adminAnn.id}`, undefined, sami)).status, 403);
    const a = await t.call('POST', 'announcements', { title: 'Cours offert', body: 'Samedi' }, sami);
    assert.equal((await t.call('PUT', `announcements/${a.body.id}`, { title: 'Cours offert !' }, sami)).status, 200);
    assert.equal((await t.call('DELETE', `announcements/${a.body.id}`, undefined, leila)).status, 403);
    assert.ok((await t.call('GET', 'notifications', undefined, youssef)).body.items.some(n => /Cours offert/.test(n.title)));
  });

  test('demande d’abonnement → validation admin → abonnement prolongé + paiement', async () => {
    const amira = await t.login('amira');
    const before = (await t.call('GET', 'me', undefined, amira)).body.sub_end;
    const r = await t.call('POST', 'requests', { plan_id: 2 }, amira);
    assert.equal((await t.call('POST', 'requests', { plan_id: 2 }, amira)).status, 409);
    assert.equal((await t.call('POST', `requests/${r.body.id}/approve`, { method: 'Carte' }, sami)).status, 403);
    assert.equal((await t.call('POST', `requests/${r.body.id}/approve`, { method: 'Carte' }, admin)).status, 200);
    const after = (await t.call('GET', 'me', undefined, amira)).body.sub_end;
    assert.ok(after > before);
    assert.ok((await t.call('GET', 'payments', undefined, amira)).body.some(p => p.method === 'Carte'));
  });

  test('statistiques : globales pour l’admin, limitées pour le coach', async () => {
    const a = (await t.call('GET', 'stats', undefined, admin)).body, c = (await t.call('GET', 'stats', undefined, sami)).body;
    assert.ok('revenue' in a && !('revenue' in c));
    assert.equal(c.clients, 2);
  });
});

describe('Migrations', () => {
  test('une base v1 existante est migrée sans perte', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ironfit-mig-'));
    const file = path.join(dir, 'gym.db');
    const { DatabaseSync } = require('node:sqlite');
    const raw = new DatabaseSync(file);
    raw.exec(MIGRATIONS[0]);
    raw.exec("INSERT INTO users(name,login,email,role,pwd) VALUES('Ancien','ancien','a@a.tn','athlete','x')");
    raw.close();
    const d = openDb(file);
    assert.deepEqual(d.migration, { from: 0, to: MIGRATIONS.length });
    const u = d.one("SELECT * FROM users WHERE login='ancien'");
    assert.equal(u.active, 1);
    assert.equal(u.tv, 0);
    assert.ok(d.one("SELECT name FROM sqlite_master WHERE name='coach_clients'"));
    d.close();
    fs.rmSync(dir, { recursive: true, force: true });
  });
});
