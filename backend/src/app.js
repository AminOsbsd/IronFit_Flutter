'use strict';
// Serveur HTTP : routeur, session, CORS, fichiers statiques
const fs = require('fs'), path = require('path');
const { tokens, rateLimiter } = require('./security');
const { HttpError, fail, isAdmin, isCoach, isMember } = require('./util');

const ROUTES = ['auth', 'users', 'subscriptions', 'coaching', 'programs', 'classes', 'notifications', 'stats', 'crud'].map(n => require('./routes/' + n));

/** '/api/members/:id/:action(a|b)' → regex ; les paramètres sans motif sont des entiers. */
function compile(p) {
  const keys = [], ints = [];
  const src = p.replace(/:(\w+)(?:\(([^)]+)\))?/g, (_, k, alt) => { keys.push(k); if (!alt) ints.push(k); return alt ? `(${alt})` : '(\\d+)'; });
  return { re: new RegExp('^' + src + '$'), keys, ints };
}

const readBody = req => new Promise((ok, ko) => {
  let d = '';
  req.setEncoding('utf8');
  req.on('data', c => { d += c; if (d.length > 1e5) { ko(new HttpError(413, 'Requête trop grande')); req.destroy(); } });
  req.on('end', () => { try { const o = d ? JSON.parse(d) : {}; ok(o && typeof o === 'object' && !Array.isArray(o) ? o : {}); } catch { ko(new HttpError(400, 'JSON invalide')); } });
  req.on('error', ko);
});

function createApp({ cfg, d, secret, log = console }) {
  const tok = tokens(secret, cfg.tokenDays);
  const limited = rateLimiter(cfg.rateLimit);

  // Services partagés par les routes
  const S = {
    d, cfg, tok, log,
    notify: (userId, title, body = null) => d.run('INSERT INTO notifications(user_id,title,body) VALUES(?,?,?)', userId, title, body),
    /** Vrai si `coachId` suit actuellement `clientId` (relation acceptée). */
    coaches: (coachId, clientId) => !!d.one("SELECT 1 x FROM coach_clients WHERE coach_id=? AND client_id=? AND status='active'", coachId, clientId),
    /** Données personnelles d'un membre : lui-même, l'admin, ou son coach actif. */
    canSeeMember: (me, id) => isAdmin(me) || me.id === id || (isCoach(me) && S.coaches(me.id, id)),
    member: id => { const u = d.one("SELECT * FROM users WHERE id=? AND role IN ('athlete','coach')", id); if (!u) fail(404, 'Membre introuvable'); return u; },
    isAdmin, isCoach, isMember,
  };

  const routes = ROUTES.flatMap(m => m(S)).map(r => ({ ...r, ...compile(r.path) }));

  function session(req) {
    const t = tok.verify((req.headers.authorization || '').replace(/^Bearer\s+/i, ''));
    const me = t && d.one('SELECT * FROM users WHERE id=?', t.id);
    if (!me || me.tv !== (t.tv || 0)) fail(401, 'Session expirée, reconnectez-vous');
    if (!me.active) fail(401, 'Compte désactivé. Contactez l’accueil de la salle.');
    return me;
  }

  async function api(req, url) {
    const p = url.pathname, m = req.method;
    const r = routes.find(x => x.method === m && x.re.test(p));
    if (!r) fail(routes.some(x => x.re.test(p)) ? 405 : 404, 'Route inconnue');
    const ip = req.socket.remoteAddress;
    if (r.limit && limited(ip + ' ' + p)) fail(429, 'Trop de tentatives, réessayez dans une minute');
    const body = m === 'POST' || m === 'PUT' ? await readBody(req) : {};
    const me = r.public ? null : session(req);
    const vals = r.re.exec(p).slice(1), params = {};
    r.keys.forEach((k, i) => { params[k] = r.ints.includes(k) ? Number(vals[i]) : vals[i]; });
    return r.handler({ me, body, params, query: url.searchParams, ip, req });
  }

  const PUB = path.join(__dirname, '..', 'public');
  const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.ico': 'image/x-icon', '.json': 'application/json' };

  return async function handler(req, res) {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'no-referrer');
    // CORS : nécessaire pour Flutter Web ; l'API s'authentifie par en-tête Bearer (pas de cookie)
    res.setHeader('Access-Control-Allow-Origin', cfg.corsOrigin);
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
    if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }
    let url;
    try { url = new URL(req.url, 'http://x'); } catch { res.writeHead(400); return res.end(); }

    if (url.pathname.startsWith('/api/')) {
      let code = 200, out;
      try { out = await api(req, url); }
      catch (e) {
        if (e instanceof HttpError) { code = e.status; out = { error: e.message }; }
        else if (/UNIQUE constraint/.test(e && e.message)) { code = 409; out = { error: 'Identifiant ou e-mail déjà utilisé' }; }
        else { log.error(`[${new Date().toISOString()}] ${req.method} ${url.pathname} :`, e); code = 500; out = { error: 'Erreur serveur' }; }
      }
      res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      return res.end(JSON.stringify(out === undefined ? { ok: true } : out));
    }

    let rel; try { rel = decodeURIComponent(url.pathname); } catch { rel = '/'; }
    let f = path.normalize(path.join(PUB, rel === '/' ? 'index.html' : rel));
    if (!f.startsWith(PUB + path.sep) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) f = path.join(PUB, 'index.html');
    res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' });
    fs.createReadStream(f).pipe(res);
  };
}

module.exports = { createApp, compile };
