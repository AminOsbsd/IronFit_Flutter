'use strict';
// Mots de passe (scrypt), jetons signés (HMAC-SHA256) et limitation de débit
const crypto = require('crypto'), fs = require('fs'), path = require('path');

const hash = p => { const s = crypto.randomBytes(16); return s.toString('hex') + ':' + crypto.scryptSync(String(p), s, 64).toString('hex'); };
const check = (p, stored) => {
  try {
    const [s, h] = String(stored).split(':');
    return crypto.timingSafeEqual(crypto.scryptSync(String(p), Buffer.from(s, 'hex'), 64), Buffer.from(h, 'hex'));
  } catch { return false; }
};
// Hachage factice : la connexion prend le même temps que l'identifiant existe ou non
const DUMMY = hash(crypto.randomBytes(8).toString('hex'));

function loadSecret(cfg) {
  if (cfg.secret) {
    if (cfg.secret.length < 32) throw new Error('IRONFIT_SECRET doit contenir au moins 32 caractères');
    return Buffer.from(cfg.secret);
  }
  const f = path.join(cfg.dataDir, 'secret');
  try { return fs.readFileSync(f); } catch {
    const s = crypto.randomBytes(32);
    fs.writeFileSync(f, s, { mode: 0o600 });
    return s;
  }
}

/** Jeton = base64url(JSON {id, tv, exp}) + '.' + HMAC. `tv` (token version) permet de révoquer tous les jetons d'un compte. */
function tokens(secret, days) {
  const mac = b => crypto.createHmac('sha256', secret).update(b).digest('base64url');
  return {
    sign: u => { const b = Buffer.from(JSON.stringify({ id: u.id, tv: u.tv || 0, exp: Date.now() + days * 864e5 })).toString('base64url'); return b + '.' + mac(b); },
    verify: t => {
      try {
        const [b, s] = String(t).split('.');
        if (!crypto.timingSafeEqual(Buffer.from(s), Buffer.from(mac(b)))) return null;
        const o = JSON.parse(Buffer.from(b, 'base64url'));
        return o.exp > Date.now() ? o : null;
      } catch { return null; }
    },
  };
}

/** Fenêtre glissante : `max` appels par `windowMs` et par clé. Les clés expirées sont purgées. */
function rateLimiter(max, windowMs = 60000) {
  const hits = new Map();
  setInterval(() => { const n = Date.now(); for (const [k, a] of hits) if (!a.some(t => n - t < windowMs)) hits.delete(k); }, windowMs).unref();
  return key => { const n = Date.now(), a = (hits.get(key) || []).filter(t => n - t < windowMs); a.push(n); hits.set(key, a); return a.length > max; };
}

module.exports = { hash, check, DUMMY, loadSecret, tokens, rateLimiter };
