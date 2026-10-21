'use strict';
// Migration unique : ancienne base SQLite (backend/data/gym.db) → script SQL pour MySQL / MariaDB (ironfit_db).
//
//   node tools/sqlite-to-mysql.js data/gym.db > ironfit-import.sql
//   mysql -u root ironfit_db < ironfit-import.sql        (ou phpMyAdmin → Importer)
//
// Prérequis : le schéma MySQL existe (lancer une fois le backend Spring Boot sur ironfit_db).
// ATTENTION : le script VIDE les tables d'IronFit avant d'insérer les données de l'ancienne base.
// La base SQLite est ouverte en lecture seule. Nécessite Node.js 22.13+ (module node:sqlite intégré).
const { DatabaseSync } = require('node:sqlite');

const file = process.argv[2];
if (!file) { console.error('Usage : node tools/sqlite-to-mysql.js <chemin/vers/gym.db> > ironfit-import.sql'); process.exit(1); }
const db = new DatabaseSync(file, { readOnly: true });

// table MySQL ← table SQLite, colonnes [colonne MySQL, colonne SQLite, valeur par défaut si absente (ancienne v1)]
const TABLES = [
  ['plans', 'plans', [['id'], ['name'], ['price'], ['duration'], ['descr']]],
  ['promos', 'promos', [['id'], ['title'], ['descr'], ['discount'], ['valid_until', 'until']]],
  ['users', 'users', [['id'], ['name'], ['login'], ['email'], ['phone'], ['role'], ['password_hash', 'pwd'], ['plan_id'], ['sub_end'], ['specialty'],
    ['created'], ['active', 'active', 1], ['token_version', 'tv', 0]]],
  ['classes', 'classes', [['id'], ['week_day', 'day'], ['start_time', 'time'], ['title'], ['coach_id'], ['spots']]],
  ['bookings', 'bookings', [['user_id'], ['class_id']]],
  ['payments', 'payments', [['id'], ['member_id'], ['amount'], ['method'], ['paid_on'], ['note']]],
  ['equipment', 'equipment', [['id'], ['name'], ['category'], ['qty'], ['status']]],
  ['products', 'products', [['id'], ['name'], ['category'], ['price'], ['stock']]],
  ['announcements', 'announcements', [['id'], ['title'], ['body'], ['posted_on'], ['author_id', 'author_id', null]]],
  ['measures', 'measures', [['id'], ['member_id'], ['measured_on'], ['weight'], ['body_fat'], ['note']]],
  ['checkins', 'checkins', [['id'], ['member_id'], ['checkin_on'], ['note']]],
  ['requests', 'requests', [['id'], ['member_id'], ['plan_id'], ['status'], ['created']]],
  ['coach_clients', 'coach_clients', [['id'], ['coach_id'], ['client_id'], ['status'], ['created'], ['updated']]],
  ['programs', 'programs', [['id'], ['client_id'], ['coach_id'], ['title'], ['goal'], ['notes'], ['active'], ['created']]],
  ['exercises', 'exercises', [['id'], ['program_id'], ['day_label', 'day'], ['name'], ['sets'], ['reps'], ['load_text', 'load'], ['rest'], ['notes'], ['position']]],
  ['workouts', 'workouts', [['id'], ['user_id'], ['program_id'], ['done_on'], ['duration'], ['rpe'], ['notes'], ['coach_comment'], ['created']]],
  ['notifications', 'notifications', [['id'], ['user_id'], ['title'], ['body'], ['seen'], ['created']]],
];
// Les codes de réinitialisation (resets) sont temporaires : non migrés.

const exists = t => !!db.prepare("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?").get(t);
const columns = t => new Set(db.prepare(`PRAGMA table_info(${t})`).all().map(c => c.name));
const sql = v => v === null || v === undefined ? 'NULL'
  : typeof v === 'number' || typeof v === 'bigint' ? String(v)
  : "'" + String(v).replace(/\\/g, '\\\\').replace(/'/g, "''") + "'";

const out = [];
out.push(`-- IronFit : import de ${file.replace(/\\/g, '/')} (${new Date().toISOString()})`);
out.push('SET NAMES utf8mb4;', 'SET FOREIGN_KEY_CHECKS = 0;', 'START TRANSACTION;', '');
for (const [target] of [...TABLES].reverse()) out.push(`DELETE FROM \`${target}\`;`);
out.push('DELETE FROM `resets`;', '');

const counts = {};
for (const [target, source, cols] of TABLES) {
  if (!exists(source)) { counts[target] = 0; continue; }
  const have = columns(source);
  const rows = db.prepare(`SELECT * FROM ${source}`).all();
  counts[target] = rows.length;
  if (!rows.length) continue;
  const names = cols.map(c => '`' + c[0] + '`').join(', ');
  for (let i = 0; i < rows.length; i += 200) {
    const values = rows.slice(i, i + 200).map(r => '(' + cols.map(([dst, src = dst, def]) => sql(have.has(src) ? r[src] : def)).join(', ') + ')');
    out.push(`INSERT INTO \`${target}\` (${names}) VALUES\n  ${values.join(',\n  ')};`);
  }
  out.push('');
}
out.push('COMMIT;', 'SET FOREIGN_KEY_CHECKS = 1;');
process.stdout.write(out.join('\n') + '\n');
console.error('Lignes exportées : ' + Object.entries(counts).map(([t, n]) => `${t}=${n}`).join(', '));
