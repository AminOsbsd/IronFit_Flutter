'use strict';
// IronFit – serveur sans dépendances (Node.js 22.13+ : SQLite intégré)
const http = require('http'), fs = require('fs'), path = require('path'), crypto = require('crypto'), os = require('os');
let DatabaseSync;
try { ({ DatabaseSync } = require('node:sqlite')); }
catch { console.error('\n  Node.js 22.13 ou plus récent est requis (https://nodejs.org, version LTS).\n'); process.exit(1); }

const PORT = process.env.PORT || 3000;
const SHOW_CODE = process.env.SHOW_RESET_CODE !== 'false'; // démo : affiche le code dans l'app (mettre false en production)
const DATA = path.join(__dirname, 'data'); fs.mkdirSync(DATA, { recursive: true });
const db = new DatabaseSync(path.join(DATA, 'gym.db'));

db.exec(`PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS plans(id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL DEFAULT 0, duration TEXT, descr TEXT);
CREATE TABLE IF NOT EXISTS promos(id INTEGER PRIMARY KEY, title TEXT NOT NULL, descr TEXT, discount INTEGER DEFAULT 0, until TEXT);
CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT NOT NULL, login TEXT NOT NULL UNIQUE COLLATE NOCASE, email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  phone TEXT, role TEXT NOT NULL CHECK(role IN('admin','coach','athlete')), pwd TEXT NOT NULL,
  plan_id INTEGER REFERENCES plans(id) ON DELETE SET NULL, sub_end TEXT, specialty TEXT, created TEXT DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS classes(id INTEGER PRIMARY KEY, day INTEGER NOT NULL, time TEXT NOT NULL, title TEXT NOT NULL,
  coach_id INTEGER REFERENCES users(id) ON DELETE SET NULL, spots INTEGER DEFAULT 10);
CREATE TABLE IF NOT EXISTS bookings(user_id INTEGER REFERENCES users(id) ON DELETE CASCADE, class_id INTEGER REFERENCES classes(id) ON DELETE CASCADE, PRIMARY KEY(user_id,class_id));
CREATE TABLE IF NOT EXISTS payments(id INTEGER PRIMARY KEY, member_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, amount REAL NOT NULL, method TEXT, paid_on TEXT, note TEXT);
CREATE TABLE IF NOT EXISTS equipment(id INTEGER PRIMARY KEY, name TEXT NOT NULL, category TEXT, qty INTEGER DEFAULT 1, status TEXT DEFAULT 'OK');
CREATE TABLE IF NOT EXISTS products(id INTEGER PRIMARY KEY, name TEXT NOT NULL, category TEXT, price REAL DEFAULT 0, stock INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS announcements(id INTEGER PRIMARY KEY, title TEXT NOT NULL, body TEXT, posted_on TEXT);
CREATE TABLE IF NOT EXISTS measures(id INTEGER PRIMARY KEY, member_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, measured_on TEXT, weight REAL, body_fat REAL, note TEXT);
CREATE TABLE IF NOT EXISTS checkins(id INTEGER PRIMARY KEY, member_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, checkin_on TEXT, note TEXT);
CREATE TABLE IF NOT EXISTS requests(id INTEGER PRIMARY KEY, member_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, plan_id INTEGER NOT NULL REFERENCES plans(id) ON DELETE CASCADE, status TEXT DEFAULT 'pending', created TEXT DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS resets(user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, code TEXT NOT NULL, expires INTEGER NOT NULL, tries INTEGER DEFAULT 0);
CREATE INDEX IF NOT EXISTS idx_classes_day ON classes(day,time);`);

// ---------- Sécurité ----------
const hash = p => { const s = crypto.randomBytes(16); return s.toString('hex') + ':' + crypto.scryptSync(p, s, 64).toString('hex'); };
const check = (p, st) => { const [s, h] = st.split(':'); return crypto.timingSafeEqual(crypto.scryptSync(p, Buffer.from(s, 'hex'), 64), Buffer.from(h, 'hex')); };
const SECRET = (() => { const f = path.join(DATA, 'secret'); try { return fs.readFileSync(f); } catch { const s = crypto.randomBytes(32); fs.writeFileSync(f, s); return s; } })();
const mac = b => crypto.createHmac('sha256', SECRET).update(b).digest('base64url');
const sign = o => { const b = Buffer.from(JSON.stringify(o)).toString('base64url'); return b + '.' + mac(b); };
const verify = t => { try { const [b, s] = t.split('.'); if (!crypto.timingSafeEqual(Buffer.from(s), Buffer.from(mac(b)))) return null; const o = JSON.parse(Buffer.from(b, 'base64url')); return o.exp > Date.now() ? o : null; } catch { return null; } };
const hits = new Map();
const limited = (ip, max = 10) => { const n = Date.now(), a = (hits.get(ip) || []).filter(t => n - t < 60000); a.push(n); hits.set(ip, a); return a.length > max; };

// ---------- Données ----------
const q = (sql, ...a) => db.prepare(sql).all(...a), one = (sql, ...a) => db.prepare(sql).get(...a), run = (sql, ...a) => db.prepare(sql).run(...a);
const pub = u => ({ id: u.id, name: u.name, login: u.login, email: u.email, phone: u.phone, role: u.role, plan_id: u.plan_id, sub_end: u.sub_end, specialty: u.specialty });
const err = (s, m) => ({ s, m });
const NUM = new Set(['price', 'discount', 'day', 'spots', 'coach_id', 'plan_id', 'member_id', 'amount', 'qty', 'stock', 'weight', 'body_fat']);
const val = (k, v) => v === '' || v == null ? null : NUM.has(k) ? Number(v) : String(v).trim();
const ENT = { plans: [['name', 'price', 'duration', 'descr'], ['admin']], promos: [['title', 'descr', 'discount', 'until'], ['admin']], classes: [['day', 'time', 'title', 'coach_id', 'spots'], ['admin', 'coach']],
  payments: [['member_id', 'amount', 'method', 'paid_on', 'note'], ['admin'], 'member_id'],
  equipment: [['name', 'category', 'qty', 'status'], ['admin', 'coach']],
  products: [['name', 'category', 'price', 'stock'], ['admin']],
  announcements: [['title', 'body', 'posted_on'], ['admin', 'coach']],
  measures: [['member_id', 'measured_on', 'weight', 'body_fat', 'note'], ['admin', 'coach'], 'member_id'],
  checkins: [['member_id', 'checkin_on', 'note'], ['admin', 'coach'], 'member_id'] };
const MEM = ['name', 'login', 'email', 'phone', 'plan_id', 'sub_end', 'specialty'];
const okMail = e => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e || '');
const okLogin = l => /^[a-z0-9_.-]{3,20}$/i.test(l || '');
const uniq = f => { try { return f(); } catch (e) { if (/UNIQUE/.test(e.message)) throw err(409, 'Identifiant ou e-mail déjà utilisé'); throw e; } };

const iso = d => d.toISOString().slice(0, 10);
function extend(from, duration) { // prolonge à partir de la fin actuelle (ou d'aujourd'hui si expiré)
  const t = iso(new Date()), d = new Date((from && from > t ? from : t) + 'T00:00:00Z');
  const s = String(duration || ''), mo = s.match(/(\d+)\s*mois/i), j = s.match(/(\d+)\s*j/i);
  if (mo) d.setUTCMonth(d.getUTCMonth() + +mo[1]); else if (j) d.setUTCDate(d.getUTCDate() + +j[1]);
  else d.setUTCDate(d.getUTCDate() + (/entr|séance/i.test(s) ? 1 : 30));
  return iso(d);
}
function activate(userId, planId, method) { // active/renouvelle un abonnement + enregistre le paiement
  const p = one('SELECT * FROM plans WHERE id=?', planId), u = one("SELECT * FROM users WHERE id=? AND role='athlete'", userId);
  if (!p || !u) throw err(404, 'Athlète ou tarif introuvable');
  run('UPDATE users SET plan_id=?, sub_end=? WHERE id=?', p.id, extend(u.sub_end, p.duration), u.id);
  run('INSERT INTO payments(member_id,amount,method,paid_on,note) VALUES(?,?,?,?,?)', u.id, p.price, method || 'Espèces', iso(new Date()), 'Abonnement ' + p.name);
}

function seed() {
  if (one('SELECT COUNT(*) n FROM users').n) return;
  const ins = (s, ...a) => Number(run(s, ...a).lastInsertRowid);
  const P = ['Séance|10|1 entrée|Accès salle pour une journée', 'Mensuel|60|1 mois|Salle + cours collectifs illimités', 'Trimestriel|160|3 mois|Salle + cours + bilan coach', 'Annuel|550|12 mois|Tout inclus + coaching mensuel']
    .map(x => { const [n, p, d, s] = x.split('|'); return ins('INSERT INTO plans(name,price,duration,descr) VALUES(?,?,?,?)', n, +p, d, s); });
  const u = (n, l, r, ex = [null, null, null]) => ins('INSERT INTO users(name,login,email,role,pwd,plan_id,sub_end,specialty) VALUES(?,?,?,?,?,?,?,?)', n, l, l + '@ironfit.local', r, hash(l === 'admin' ? 'admin123' : '1234'), ...ex);
  u('Administrateur', 'admin', 'admin');
  const c1 = u('Sami Ben Ali', 'sami', 'coach', [null, null, 'Musculation']), c2 = u('Leila Trabelsi', 'leila', 'coach', [null, null, 'Yoga & Pilates']);
  const a1 = u('Youssef Karray', 'youssef', 'athlete', [P[1], '2027-01-31', null]), a2 = u('Amira Jlassi', 'amira', 'athlete', [P[2], '2026-12-15', null]);
  [[0, '18:00', 'Musculation', c1, 15], [1, '19:00', 'Yoga', c2, 12], [2, '18:30', 'CrossFit', c1, 10], [3, '19:00', 'Pilates', c2, 12], [4, '17:00', 'Cardio HIIT', c1, 20], [5, '10:00', 'Stretching', c2, 15]]
    .forEach(c => run('INSERT INTO classes(day,time,title,coach_id,spots) VALUES(?,?,?,?,?)', ...c));
  run('INSERT INTO promos(title,descr,discount,until) VALUES(?,?,?,?)', 'Rentrée sportive', 'Sur l’abonnement trimestriel', 20, '2026-10-31');
  run('INSERT INTO payments(member_id,amount,method,paid_on,note) VALUES(?,?,?,?,?)', a1, 60, 'Espèces', '2026-09-01', 'Abonnement mensuel');
  run('INSERT INTO payments(member_id,amount,method,paid_on,note) VALUES(?,?,?,?,?)', a2, 160, 'Carte', '2026-09-10', 'Abonnement trimestriel');
  [['Tapis de course', 'Cardio', 6, 'OK'], ['Banc de musculation', 'Musculation', 8, 'OK'], ['Vélo elliptique', 'Cardio', 4, 'Maintenance']].forEach(e => run('INSERT INTO equipment(name,category,qty,status) VALUES(?,?,?,?)', ...e));
  [['Whey protéine 1kg', 'Nutrition', 75, 20], ['Gourde 750ml', 'Accessoires', 12, 40], ['Serviette sport', 'Accessoires', 8, 30]].forEach(e => run('INSERT INTO products(name,category,price,stock) VALUES(?,?,?,?)', ...e));
  run('INSERT INTO announcements(title,body,posted_on) VALUES(?,?,?)', 'Nouveaux horaires du week-end', 'La salle ouvre à 8h le samedi et le dimanche. Bon entraînement !', '2026-09-20');
  run('INSERT INTO measures(member_id,measured_on,weight,body_fat,note) VALUES(?,?,?,?,?)', a1, '2026-09-15', 82.5, 19.5, 'Début du programme');
  run('INSERT INTO checkins(member_id,checkin_on,note) VALUES(?,?,?)', a1, '2026-09-22', 'Musculation');
  run('INSERT INTO promos(title,descr,discount,until) VALUES(?,?,?,?)', 'Amenez un ami', 'Une séance offerte pour vous deux', 100, '2026-12-31');
}
seed();

// ---------- API ----------
async function api(req, u) {
  const p = u.pathname, m = req.method, ip = req.socket.remoteAddress;
  const b = ['POST', 'PUT'].includes(m) ? await body(req) : {};
  const session = () => { const t = verify((req.headers.authorization || '').slice(7)); const me = t && one('SELECT * FROM users WHERE id=?', t.id); if (!me) throw err(401, 'Session expirée'); return me; };
  const need = (me, roles) => { if (!roles.includes(me.role)) throw err(403, 'Action non autorisée'); };
  const login = me => ({ token: sign({ id: me.id, exp: Date.now() + 7 * 864e5 }), user: pub(me) });

  if (m === 'POST' && ['/api/login', '/api/signup', '/api/forgot', '/api/reset'].includes(p) && limited(ip)) throw err(429, 'Trop de tentatives, réessayez dans une minute');

  if (m === 'POST' && p === '/api/signup') {
    const { name, login: l, email, password } = b;
    if (!name || name.trim().length < 2) throw err(400, 'Nom invalide');
    if (!okLogin(l)) throw err(400, 'Identifiant : 3 à 20 caractères (lettres, chiffres, . _ -)');
    if (!okMail(email)) throw err(400, 'E-mail invalide');
    if (!password || password.length < 6) throw err(400, 'Mot de passe : 6 caractères minimum');
    const id = uniq(() => run('INSERT INTO users(name,login,email,role,pwd) VALUES(?,?,?,?,?)', name.trim(), l.trim(), email.trim(), 'athlete', hash(password)).lastInsertRowid);
    return login(one('SELECT * FROM users WHERE id=?', Number(id)));
  }
  if (m === 'POST' && p === '/api/login') {
    const me = one('SELECT * FROM users WHERE login=? OR email=?', b.login || '', b.login || '');
    if (!me || !check(String(b.password || ''), me.pwd)) throw err(401, 'Identifiant ou mot de passe incorrect');
    return login(me);
  }
  if (m === 'POST' && p === '/api/forgot') {
    const me = okMail(b.email) && one('SELECT * FROM users WHERE email=?', b.email);
    let devCode;
    if (me) {
      const code = String(crypto.randomInt(100000, 1000000));
      run('INSERT OR REPLACE INTO resets(user_id,code,expires,tries) VALUES(?,?,?,0)', me.id, hash(code), Date.now() + 15 * 60000);
      console.log(`\n  [Mot de passe oublié] Code pour ${me.email} : ${code} (valable 15 min)\n`);
      if (SHOW_CODE) devCode = code;
    }
    return { ok: true, devCode }; // même réponse si l'e-mail n'existe pas
  }
  if (m === 'POST' && p === '/api/reset') {
    const me = one('SELECT * FROM users WHERE email=?', b.email || ''), r = me && one('SELECT * FROM resets WHERE user_id=?', me.id);
    if (!r || r.expires < Date.now() || r.tries >= 5) throw err(400, 'Code invalide ou expiré');
    if (!check(String(b.code || ''), r.code)) { run('UPDATE resets SET tries=tries+1 WHERE user_id=?', me.id); throw err(400, 'Code invalide ou expiré'); }
    if (!b.password || b.password.length < 6) throw err(400, 'Mot de passe : 6 caractères minimum');
    run('UPDATE users SET pwd=? WHERE id=?', hash(b.password), me.id); run('DELETE FROM resets WHERE user_id=?', me.id);
    return { ok: true };
  }

  const me = session();

  // ---- Profil ----
  if (m === 'PUT' && p === '/api/profile') {
    const name = String(b.name || '').trim(), email = String(b.email || '').trim();
    if (name.length < 2) throw err(400, 'Nom invalide'); if (!okMail(email)) throw err(400, 'E-mail invalide');
    uniq(() => run('UPDATE users SET name=?,email=?,phone=? WHERE id=?', name, email, val('phone', b.phone), me.id));
    return pub(one('SELECT * FROM users WHERE id=?', me.id));
  }
  // ---- Statistiques (admin / coach) ----
  if (m === 'GET' && p === '/api/stats') {
    need(me, ['admin', 'coach']);
    const today = iso(new Date()), in7 = iso(new Date(Date.now() + 7 * 864e5));
    return {
      athletes: one("SELECT COUNT(*) n FROM users WHERE role='athlete'").n,
      active: one("SELECT COUNT(*) n FROM users WHERE role='athlete' AND sub_end>=?", today).n,
      expired: one("SELECT COUNT(*) n FROM users WHERE role='athlete' AND (sub_end IS NULL OR sub_end<?)", today).n,
      expiring: q("SELECT id,name,sub_end,plan_id FROM users WHERE role='athlete' AND sub_end BETWEEN ? AND ? ORDER BY sub_end", today, in7),
      lapsed: q("SELECT id,name,sub_end,plan_id FROM users WHERE role='athlete' AND sub_end<? ORDER BY sub_end DESC LIMIT 10", today),
      pending: one("SELECT COUNT(*) n FROM requests WHERE status='pending'").n,
      lowStock: q('SELECT id,name,stock FROM products WHERE stock<=5 ORDER BY stock'),
      maintenance: q("SELECT id,name,status FROM equipment WHERE status!='OK'"),
      checkinsToday: one('SELECT COUNT(*) n FROM checkins WHERE checkin_on=?', today).n,
      revenue: me.role === 'admin' ? q('SELECT substr(paid_on,1,7) m, SUM(amount) total FROM payments WHERE paid_on IS NOT NULL GROUP BY m ORDER BY m DESC LIMIT 6').reverse() : [],
      fill: q('SELECT c.id, c.title, c.day, c.time, c.spots, (SELECT COUNT(*) FROM bookings b WHERE b.class_id=c.id) taken FROM classes c ORDER BY taken*1.0/MAX(c.spots,1) DESC LIMIT 5'),
    };
  }
  // ---- Demandes d'abonnement ----
  if (p === '/api/requests' && m === 'GET') {
    if (me.role === 'athlete') return q('SELECT r.*, p.name plan_name, p.price FROM requests r JOIN plans p ON p.id=r.plan_id WHERE r.member_id=? ORDER BY r.id DESC', me.id);
    need(me, ['admin']);
    return q("SELECT r.*, p.name plan_name, p.price, u.name member_name FROM requests r JOIN plans p ON p.id=r.plan_id JOIN users u ON u.id=r.member_id WHERE r.status='pending' ORDER BY r.id");
  }
  if (p === '/api/requests' && m === 'POST') {
    need(me, ['athlete']);
    if (!one('SELECT 1 x FROM plans WHERE id=?', Number(b.plan_id))) throw err(404, 'Tarif introuvable');
    if (one("SELECT 1 x FROM requests WHERE member_id=? AND status='pending'", me.id)) throw err(409, 'Vous avez déjà une demande en attente');
    return { id: Number(run('INSERT INTO requests(member_id,plan_id) VALUES(?,?)', me.id, Number(b.plan_id)).lastInsertRowid) };
  }
  const rq = p.match(/^\/api\/requests\/(\d+)\/(approve|reject|cancel)$/);
  if (rq && m === 'POST') {
    const r = one("SELECT * FROM requests WHERE id=? AND status='pending'", +rq[1]); if (!r) throw err(404, 'Demande introuvable');
    if (rq[2] === 'cancel') { if (me.id !== r.member_id) throw err(403, 'Action non autorisée'); run("UPDATE requests SET status='cancelled' WHERE id=?", r.id); return { ok: true }; }
    need(me, ['admin']);
    if (rq[2] === 'approve') activate(r.member_id, r.plan_id, b.method);
    run('UPDATE requests SET status=? WHERE id=?', rq[2] === 'approve' ? 'approved' : 'rejected', r.id); return { ok: true };
  }
  const rn = p.match(/^\/api\/members\/(\d+)\/renew$/);
  if (rn && m === 'POST') { need(me, ['admin']); activate(+rn[1], Number(b.plan_id), b.method); return { ok: true }; }
  // ---- Participants d'une séance + pointage ----
  const pc = p.match(/^\/api\/classes\/(\d+)\/(participants|present)$/);
  if (pc) {
    need(me, ['admin', 'coach']);
    const c = one('SELECT * FROM classes WHERE id=?', +pc[1]); if (!c) throw err(404, 'Séance introuvable');
    const today = iso(new Date());
    if (m === 'GET' && pc[2] === 'participants') return q('SELECT u.id, u.name, u.phone, EXISTS(SELECT 1 FROM checkins k WHERE k.member_id=u.id AND k.checkin_on=? AND k.note=?) present FROM bookings b JOIN users u ON u.id=b.user_id WHERE b.class_id=? ORDER BY u.name', today, c.title, c.id);
    if (m === 'POST' && pc[2] === 'present') {
      if (!one("SELECT 1 x FROM users WHERE id=? AND role='athlete'", Number(b.member_id))) throw err(404, 'Athlète introuvable');
      if (!one('SELECT 1 x FROM checkins WHERE member_id=? AND checkin_on=? AND note=?', Number(b.member_id), today, c.title)) run('INSERT INTO checkins(member_id,checkin_on,note) VALUES(?,?,?)', Number(b.member_id), today, c.title);
      return { ok: true };
    }
  }
  if (m === 'GET' && p === '/api/me') return pub(me);
  if (m === 'POST' && p === '/api/password') {
    if (!check(String(b.old || ''), me.pwd)) throw err(400, 'Ancien mot de passe incorrect');
    if (!b.new || b.new.length < 6) throw err(400, 'Mot de passe : 6 caractères minimum');
    run('UPDATE users SET pwd=? WHERE id=?', hash(b.new), me.id); return { ok: true };
  }
  if (m === 'GET' && p === '/api/coaches') return q("SELECT id,name FROM users WHERE role='coach' ORDER BY name");
  if (m === 'GET' && p === '/api/classes') return q(`SELECT c.*, u.name coach_name, (SELECT COUNT(*) FROM bookings b WHERE b.class_id=c.id) taken,
    EXISTS(SELECT 1 FROM bookings b WHERE b.class_id=c.id AND b.user_id=?) mine FROM classes c LEFT JOIN users u ON u.id=c.coach_id ORDER BY day,time`, me.id);
  if (m === 'POST' && p === '/api/book') {
    need(me, ['athlete']); const c = one('SELECT * FROM classes WHERE id=?', Number(b.class_id)); if (!c) throw err(404, 'Séance introuvable');
    if (one('SELECT 1 x FROM bookings WHERE user_id=? AND class_id=?', me.id, c.id)) run('DELETE FROM bookings WHERE user_id=? AND class_id=?', me.id, c.id);
    else { if (!me.sub_end || me.sub_end < iso(new Date())) throw err(403, 'Abonnement actif requis pour réserver (voir Explorer → Tarifs)'); if (one('SELECT COUNT(*) n FROM bookings WHERE class_id=?', c.id).n >= c.spots) throw err(409, 'Séance complète'); run('INSERT INTO bookings VALUES(?,?)', me.id, c.id); }
    return { ok: true };
  }

  // CRUD générique : plans, promos, classes
  let x = p.match(new RegExp('^/api/(' + Object.keys(ENT).join('|') + ')(?:/(\\d+))?$'));
  if (x) {
    const [, t, id] = x, [cols, roles, own] = ENT[t];
    if (m === 'GET' && !id) return own ? q(`SELECT * FROM ${t} ${me.role === 'athlete' ? `WHERE ${own}=${me.id}` : ''} ORDER BY id DESC`) : q(`SELECT * FROM ${t} ORDER BY id`);
    need(me, roles);
    if (m === 'DELETE' && id) { run(`DELETE FROM ${t} WHERE id=?`, +id); return { ok: true }; }
    const v = cols.map(k => val(k, b[k]));
    if (['POST', 'PUT'].includes(m) && (v[0] == null || (t === 'classes' && (v[1] == null || v[2] == null)))) throw err(400, 'Champs obligatoires manquants');
    if (m === 'POST' && !id) return { id: Number(run(`INSERT INTO ${t}(${cols}) VALUES(${cols.map(() => '?')})`, ...v).lastInsertRowid) };
    if (m === 'PUT' && id) { run(`UPDATE ${t} SET ${cols.map(k => k + '=?')} WHERE id=?`, ...v, +id); return { ok: true }; }
  }
  // Membres (athlètes & coachs)
  x = p.match(/^\/api\/members(?:\/(\d+))?$/);
  if (x) {
    const id = x[1];
    if (m === 'GET') { need(me, ['admin', 'coach']); return q(`SELECT * FROM users WHERE role IN (${me.role === 'admin' ? "'athlete','coach'" : "'athlete'"}) ORDER BY name`).map(pub); }
    need(me, ['admin']);
    if (m === 'DELETE' && id) { run("DELETE FROM users WHERE id=? AND role!='admin'", +id); return { ok: true }; }
    const v = MEM.map(k => val(k, b[k])), role = b.role === 'coach' ? 'coach' : 'athlete';
    if (!v[0] || !okLogin(v[1]) || !okMail(v[2])) throw err(400, 'Nom, identifiant (3-20 car.) et e-mail valides requis');
    if (b.password && b.password.length < 6) throw err(400, 'Mot de passe : 6 caractères minimum');
    if (m === 'POST' && !id) {
      if (!b.password) throw err(400, 'Mot de passe obligatoire');
      return { id: uniq(() => Number(run(`INSERT INTO users(${MEM},role,pwd) VALUES(${MEM.map(() => '?')},?,?)`, ...v, role, hash(b.password)).lastInsertRowid)) };
    }
    if (m === 'PUT' && id) {
      uniq(() => run(`UPDATE users SET ${MEM.map(k => k + '=?')} WHERE id=? AND role!='admin'`, ...v, +id));
      if (b.password) run('UPDATE users SET pwd=? WHERE id=?', hash(b.password), +id);
      return { ok: true };
    }
  }
  throw err(404, 'Route inconnue');
}

// ---------- HTTP ----------
const body = req => new Promise((ok, ko) => { let d = ''; req.on('data', c => { d += c; if (d.length > 1e5) { ko(err(413, 'Requête trop grande')); req.destroy(); } }); req.on('end', () => { try { ok(d ? JSON.parse(d) : {}); } catch { ko(err(400, 'JSON invalide')); } }); });
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.svg': 'image/svg+xml', '.webmanifest': 'application/manifest+json', '.png': 'image/png' };
const PUB = path.join(__dirname, 'public');
http.createServer(async (req, res) => {
  // CORS : nécessaire si l'app Flutter tourne dans Chrome (Flutter Web)
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }
  const u = new URL(req.url, 'http://x');
  if (u.pathname.startsWith('/api/')) {
    let code = 200, out;
    try { out = await api(req, u); } catch (e) { if (e && e.s) { code = e.s; out = { error: e.m }; } else { console.error(e); code = 500; out = { error: 'Erreur serveur' }; } }
    res.writeHead(code, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); return res.end(JSON.stringify(out));
  }
  let f = path.normalize(path.join(PUB, u.pathname === '/' ? 'index.html' : u.pathname));
  if (!f.startsWith(PUB) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) f = path.join(PUB, 'index.html');
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' }); fs.createReadStream(f).pipe(res);
}).listen(PORT, '0.0.0.0', () => {
  const ips = Object.values(os.networkInterfaces()).flat().filter(i => i.family === 'IPv4' && !i.internal).map(i => i.address);
  console.log(`\n  💪 IronFit démarré\n  PC        : http://localhost:${PORT}\n  Téléphone : ${ips.map(i => `http://${i}:${PORT}`).join('  ') || '(non connecté au Wi-Fi)'}\n  Admin     : admin / admin123\n`);
});
