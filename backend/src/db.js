'use strict';
// Base SQLite (module node:sqlite intégré à Node.js 22.13+), migrations versionnées et données initiales
const { DatabaseSync } = require('node:sqlite');
const { hash } = require('./security');

// Chaque entrée est appliquée une seule fois, dans l'ordre ; PRAGMA user_version mémorise la dernière appliquée.
// Ne jamais modifier une migration publiée : en ajouter une nouvelle à la fin.
const MIGRATIONS = [
  // 1 — schéma initial (v1 de l'application)
  `CREATE TABLE IF NOT EXISTS plans(id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL DEFAULT 0, duration TEXT, descr TEXT);
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
  CREATE INDEX IF NOT EXISTS idx_classes_day ON classes(day,time);`,

  // 2 — comptes activables, révocation des jetons, auteur des annonces, coaching, programmes, séances réalisées, notifications
  `ALTER TABLE users ADD COLUMN active INTEGER NOT NULL DEFAULT 1;
  ALTER TABLE users ADD COLUMN tv INTEGER NOT NULL DEFAULT 0;
  ALTER TABLE announcements ADD COLUMN author_id INTEGER REFERENCES users(id) ON DELETE SET NULL;
  CREATE TABLE coach_clients(id INTEGER PRIMARY KEY,
    coach_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, client_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN('pending','active','declined','ended')),
    created TEXT DEFAULT CURRENT_TIMESTAMP, updated TEXT DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(coach_id, client_id), CHECK(coach_id <> client_id));
  CREATE TABLE programs(id INTEGER PRIMARY KEY,
    client_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, coach_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    title TEXT NOT NULL, goal TEXT, notes TEXT, active INTEGER NOT NULL DEFAULT 1, created TEXT DEFAULT CURRENT_TIMESTAMP);
  CREATE TABLE exercises(id INTEGER PRIMARY KEY, program_id INTEGER NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    day TEXT, name TEXT NOT NULL, sets INTEGER, reps TEXT, load TEXT, rest TEXT, notes TEXT, position INTEGER NOT NULL DEFAULT 0);
  CREATE TABLE workouts(id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    program_id INTEGER REFERENCES programs(id) ON DELETE SET NULL, done_on TEXT NOT NULL, duration INTEGER, rpe INTEGER, notes TEXT,
    coach_comment TEXT, created TEXT DEFAULT CURRENT_TIMESTAMP);
  CREATE TABLE notifications(id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL, body TEXT, seen INTEGER NOT NULL DEFAULT 0, created TEXT DEFAULT CURRENT_TIMESTAMP);
  CREATE INDEX idx_cc_client ON coach_clients(client_id, status);
  CREATE INDEX idx_programs_client ON programs(client_id);
  CREATE INDEX idx_programs_coach ON programs(coach_id);
  CREATE INDEX idx_exercises_program ON exercises(program_id, position);
  CREATE INDEX idx_workouts_user ON workouts(user_id, done_on);
  CREATE INDEX idx_workouts_program ON workouts(program_id);
  CREATE INDEX idx_notifications_user ON notifications(user_id, seen);
  CREATE INDEX IF NOT EXISTS idx_payments_member ON payments(member_id);
  CREATE INDEX IF NOT EXISTS idx_measures_member ON measures(member_id);
  CREATE INDEX IF NOT EXISTS idx_checkins_member ON checkins(member_id, checkin_on);`,
];

function migrate(db) {
  const from = db.prepare('PRAGMA user_version').get().user_version;
  for (let v = from; v < MIGRATIONS.length; v++) {
    db.exec('BEGIN');
    try { db.exec(MIGRATIONS[v]); db.exec(`PRAGMA user_version=${v + 1}`); db.exec('COMMIT'); }
    catch (e) { db.exec('ROLLBACK'); throw new Error(`Migration ${v + 1} échouée : ${e.message}`); }
  }
  return { from, to: MIGRATIONS.length };
}

function openDb(file) {
  const db = new DatabaseSync(file);
  db.exec('PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=3000;');
  const migration = migrate(db);
  const cache = new Map();
  const prep = sql => { let s = cache.get(sql); if (!s) { s = db.prepare(sql); cache.set(sql, s); } return s; };
  return {
    raw: db,
    migration,
    q: (sql, ...a) => prep(sql).all(...a),
    one: (sql, ...a) => prep(sql).get(...a),
    run: (sql, ...a) => prep(sql).run(...a),
    tx(fn) { db.exec('BEGIN'); try { const r = fn(); db.exec('COMMIT'); return r; } catch (e) { db.exec('ROLLBACK'); throw e; } },
    close: () => db.close(),
  };
}

/** Crée le compte administrateur (et les données de démo si demandé) lorsque la base ne contient aucun utilisateur. */
function seed(d, cfg) {
  if (d.one('SELECT COUNT(*) n FROM users').n) return false;
  if (!cfg.adminPassword) throw new Error('Base vide : définissez ADMIN_PASSWORD pour créer le compte administrateur');
  d.tx(() => {
    const ins = (s, ...a) => Number(d.run(s, ...a).lastInsertRowid);
    const user = (n, l, r, pwd, plan = null, end = null, spec = null) =>
      ins('INSERT INTO users(name,login,email,role,pwd,plan_id,sub_end,specialty) VALUES(?,?,?,?,?,?,?,?)', n, l, l + '@ironfit.local', r, hash(pwd), plan, end, spec);
    const admin = user('Administrateur', 'admin', 'admin', cfg.adminPassword);
    if (!cfg.seedDemo) return;

    const iso = dt => dt.toISOString().slice(0, 10), inDays = n => iso(new Date(Date.now() + n * 864e5));
    const P = ['Séance|10|1 entrée|Accès salle pour une journée', 'Mensuel|60|1 mois|Salle + cours collectifs illimités', 'Trimestriel|160|3 mois|Salle + cours + bilan coach', 'Annuel|550|12 mois|Tout inclus + coaching mensuel']
      .map(x => { const [n, p, du, s] = x.split('|'); return ins('INSERT INTO plans(name,price,duration,descr) VALUES(?,?,?,?)', n, +p, du, s); });
    const sami = user('Sami Ben Ali', 'sami', 'coach', '1234', null, null, 'Musculation');
    // Leila est coach ET membre : elle a son propre abonnement et s'entraîne avec Sami
    const leila = user('Leila Trabelsi', 'leila', 'coach', '1234', P[1], inDays(45), 'Yoga & Pilates');
    const youssef = user('Youssef Karray', 'youssef', 'athlete', '1234', P[1], inDays(100));
    const amira = user('Amira Jlassi', 'amira', 'athlete', '1234', P[2], inDays(5));

    [[0, '18:00', 'Musculation', sami, 15], [1, '19:00', 'Yoga', leila, 12], [2, '18:30', 'CrossFit', sami, 10], [3, '19:00', 'Pilates', leila, 12], [4, '17:00', 'Cardio HIIT', sami, 20], [5, '10:00', 'Stretching', leila, 15]]
      .forEach(c => d.run('INSERT INTO classes(day,time,title,coach_id,spots) VALUES(?,?,?,?,?)', ...c));
    d.run('INSERT INTO promos(title,descr,discount,until) VALUES(?,?,?,?)', 'Rentrée sportive', 'Sur l’abonnement trimestriel', 20, inDays(30));
    d.run('INSERT INTO promos(title,descr,discount,until) VALUES(?,?,?,?)', 'Amenez un ami', 'Une séance offerte pour vous deux', 100, inDays(75));
    [[youssef, 60, 'Espèces', inDays(-30), 'Abonnement Mensuel'], [amira, 160, 'Carte', inDays(-85), 'Abonnement Trimestriel'], [leila, 60, 'Carte', inDays(-15), 'Abonnement Mensuel']]
      .forEach(p => d.run('INSERT INTO payments(member_id,amount,method,paid_on,note) VALUES(?,?,?,?,?)', ...p));
    [['Tapis de course', 'Cardio', 6, 'OK'], ['Banc de musculation', 'Musculation', 8, 'OK'], ['Vélo elliptique', 'Cardio', 4, 'Maintenance']].forEach(e => d.run('INSERT INTO equipment(name,category,qty,status) VALUES(?,?,?,?)', ...e));
    [['Whey protéine 1kg', 'Nutrition', 75, 20], ['Gourde 750ml', 'Accessoires', 12, 40], ['Serviette sport', 'Accessoires', 8, 3]].forEach(e => d.run('INSERT INTO products(name,category,price,stock) VALUES(?,?,?,?)', ...e));
    d.run('INSERT INTO announcements(title,body,posted_on,author_id) VALUES(?,?,?,?)', 'Nouveaux horaires du week-end', 'La salle ouvre à 8h le samedi et le dimanche. Bon entraînement !', inDays(-7), admin);
    [[youssef, inDays(-28), 82.5, 19.5, 'Début du programme'], [youssef, inDays(-14), 81.4, 18.9, 'Bilan 2 semaines'], [youssef, inDays(-1), 80.6, 18.2, 'Bilan mensuel'], [leila, inDays(-10), 58.2, 21.0, 'Bilan personnel']]
      .forEach(m => d.run('INSERT INTO measures(member_id,measured_on,weight,body_fat,note) VALUES(?,?,?,?,?)', ...m));
    d.run('INSERT INTO checkins(member_id,checkin_on,note) VALUES(?,?,?)', youssef, inDays(-3), 'Musculation');

    // Coaching : Sami suit Youssef et Leila ; Amira a une demande en attente auprès de Sami
    d.run("INSERT INTO coach_clients(coach_id,client_id,status) VALUES(?,?,'active')", sami, youssef);
    d.run("INSERT INTO coach_clients(coach_id,client_id,status) VALUES(?,?,'active')", sami, leila);
    d.run("INSERT INTO coach_clients(coach_id,client_id,status) VALUES(?,?,'pending')", sami, amira);
    const prog = ins('INSERT INTO programs(client_id,coach_id,title,goal,notes) VALUES(?,?,?,?,?)', youssef, sami, 'Prise de force — 4 semaines', 'Force', 'Échauffement 10 min avant chaque séance.');
    [['A', 'Squat', 4, '6-8', '70 kg', '2 min'], ['A', 'Développé couché', 4, '6-8', '60 kg', '2 min'], ['B', 'Soulevé de terre', 3, '5', '90 kg', '3 min'], ['B', 'Tractions', 3, 'max', null, '90 s']]
      .forEach((e, i) => d.run('INSERT INTO exercises(program_id,day,name,sets,reps,load,rest,position) VALUES(?,?,?,?,?,?,?,?)', prog, ...e, i));
    d.run('INSERT INTO workouts(user_id,program_id,done_on,duration,rpe,notes,coach_comment) VALUES(?,?,?,?,?,?,?)', youssef, prog, inDays(-2), 65, 7, 'Séance A, bonnes sensations', 'Bravo ! On augmente le squat de 2,5 kg la prochaine fois.');
    const perso = ins('INSERT INTO programs(client_id,coach_id,title,goal) VALUES(?,?,?,?)', leila, null, 'Mobilité du matin', 'Souplesse');
    d.run('INSERT INTO exercises(program_id,day,name,sets,reps,position) VALUES(?,?,?,?,?,?)', perso, null, 'Salutation au soleil', 3, '5', 0);
    d.run('INSERT INTO notifications(user_id,title,body) VALUES(?,?,?)', youssef, 'Nouveau commentaire de votre coach', 'Sami a commenté votre séance.');
  });
  return true;
}

module.exports = { openDb, seed, migrate, MIGRATIONS };
