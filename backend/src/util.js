'use strict';
// Erreurs HTTP, validation des entrées et règles d'accès communes aux routes

class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
const fail = (status, message) => { throw new HttpError(status, message); };
const deny = () => fail(403, 'Action non autorisée');

// ---------- Rôles ----------
// Un coach est aussi un membre : il peut s'abonner, réserver et suivre ses propres programmes.
const MEMBER_ROLES = ['athlete', 'coach'];
const isAdmin = u => u.role === 'admin';
const isCoach = u => u.role === 'coach';
const isMember = u => MEMBER_ROLES.includes(u.role);
const need = ok => { if (!ok) deny(); };

const pub = u => ({ id: u.id, name: u.name, login: u.login, email: u.email, phone: u.phone, role: u.role, plan_id: u.plan_id, sub_end: u.sub_end, specialty: u.specialty, active: u.active, created: u.created });

// ---------- Validation ----------
const iso = d => d.toISOString().slice(0, 10);
const pad = n => String(n).padStart(2, '0');
const today = () => { const n = new Date(); return `${n.getFullYear()}-${pad(n.getMonth() + 1)}-${pad(n.getDate())}`; }; // date locale de la salle
const okMail = e => typeof e === 'string' && e.length <= 120 && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e);
const okLogin = l => typeof l === 'string' && /^[a-z0-9_.-]{3,20}$/i.test(l);
const okDate = s => typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s) && !isNaN(Date.parse(s + 'T00:00:00Z'));
const okTime = s => typeof s === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(s);
const okPassword = p => typeof p === 'string' && p.length >= 6 && p.length <= 200;

/**
 * Convertit et valide une valeur selon un type de colonne.
 * Types : text, num (≥ 0), int (≥ 0), pct (0-100), day (0-6), time (HH:MM), date (AAAA-MM-JJ), id (référence).
 */
function coerce(type, v, label) {
  if (v === '' || v == null) return null;
  const bad = () => fail(400, `Valeur invalide : ${label}`);
  switch (type) {
    case 'num': case 'int': case 'pct': case 'day': case 'id': {
      const n = Number(typeof v === 'string' ? v.replace(',', '.') : v);
      if (!Number.isFinite(n) || n < 0) bad();
      if (type !== 'num' && !Number.isInteger(n)) bad();
      if (type === 'pct' && n > 100) bad();
      if (type === 'day' && n > 6) bad();
      if (n > 1e9) bad();
      return n;
    }
    case 'time': if (!okTime(String(v))) bad(); return String(v);
    case 'date': if (!okDate(String(v))) bad(); return String(v);
    default: { const s = String(v).trim(); if (s.length > 2000) bad(); return s === '' ? null : s; }
  }
}

/** Lit les champs déclarés `{ nom: [type, obligatoire, libellé] }` depuis le corps de la requête. */
function pick(body, spec) {
  const out = {};
  for (const [k, [type, required, label]] of Object.entries(spec)) {
    out[k] = coerce(type, body[k], label || k);
    if (required && out[k] == null) fail(400, `Champ obligatoire : ${label || k}`);
  }
  return out;
}

/** Pagination : ?limit= (1-500) & ?offset= */
function page(query, def = 500) {
  const limit = Math.min(Math.max(parseInt(query.get('limit'), 10) || def, 1), 500);
  const offset = Math.max(parseInt(query.get('offset'), 10) || 0, 0);
  return { limit, offset };
}
const like = s => '%' + String(s).replace(/[\\%_]/g, c => '\\' + c) + '%';

/** Prolonge un abonnement à partir de la fin actuelle (ou d'aujourd'hui s'il a expiré). */
function extend(from, duration) {
  const t = today(), d = new Date((from && from > t ? from : t) + 'T00:00:00Z');
  const s = String(duration || ''), mo = s.match(/(\d+)\s*mois/i), j = s.match(/(\d+)\s*j/i);
  if (mo) d.setUTCMonth(d.getUTCMonth() + +mo[1]); else if (j) d.setUTCDate(d.getUTCDate() + +j[1]);
  else d.setUTCDate(d.getUTCDate() + (/entr|séance/i.test(s) ? 1 : 30));
  return iso(d);
}

module.exports = { HttpError, fail, deny, need, MEMBER_ROLES, isAdmin, isCoach, isMember, pub, iso, today, okMail, okLogin, okDate, okTime, okPassword, coerce, pick, page, like, extend };
