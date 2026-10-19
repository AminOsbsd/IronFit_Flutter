'use strict';
// Inscription, connexion, mot de passe oublié, profil et changement de mot de passe
const crypto = require('crypto');
const { hash, check, DUMMY } = require('../security');
const { fail, pub, okMail, okLogin, okPassword, isCoach } = require('../util');

module.exports = S => {
  const { d, cfg, tok, log } = S;
  const session = u => ({ token: tok.sign(u), user: pub(u) });
  const byId = id => d.one('SELECT * FROM users WHERE id=?', id);
  const pwdRule = p => { if (!okPassword(p)) fail(400, 'Mot de passe : 6 caractères minimum'); };

  return [
    {
      method: 'POST', path: '/api/signup', public: true, limit: true,
      handler: ({ body: b }) => {
        const name = String(b.name || '').trim(), login = String(b.login || '').trim(), email = String(b.email || '').trim();
        if (name.length < 2 || name.length > 80) fail(400, 'Nom invalide');
        if (!okLogin(login)) fail(400, 'Identifiant : 3 à 20 caractères (lettres, chiffres, . _ -)');
        if (!okMail(email)) fail(400, 'E-mail invalide');
        pwdRule(b.password);
        // Toute inscription publique crée un membre ; seul l'admin attribue le rôle coach.
        const id = d.run('INSERT INTO users(name,login,email,role,pwd) VALUES(?,?,?,?,?)', name, login, email, 'athlete', hash(b.password)).lastInsertRowid;
        return session(byId(Number(id)));
      },
    },
    {
      method: 'POST', path: '/api/login', public: true, limit: true,
      handler: ({ body: b }) => {
        const id = String(b.login || '').trim();
        const me = id ? d.one('SELECT * FROM users WHERE login=? OR email=?', id, id) : null;
        const ok = check(String(b.password || ''), me ? me.pwd : DUMMY);
        if (!me || !ok) fail(401, 'Identifiant ou mot de passe incorrect');
        if (!me.active) fail(403, 'Compte désactivé. Contactez l’accueil de la salle.');
        return session(me);
      },
    },
    {
      method: 'POST', path: '/api/forgot', public: true, limit: true,
      handler: ({ body: b }) => {
        const me = okMail(b.email) ? d.one('SELECT * FROM users WHERE email=?', b.email.trim()) : null;
        let devCode;
        if (me) {
          const code = String(crypto.randomInt(100000, 1000000));
          d.run('INSERT OR REPLACE INTO resets(user_id,code,expires,tries) VALUES(?,?,?,0)', me.id, hash(code), Date.now() + 15 * 60000);
          if (cfg.showResetCode) { devCode = code; if (!cfg.quiet) log.log(`  [Mot de passe oublié] Code pour ${me.email} : ${code} (valable 15 min)`); }
          else log.warn(`  [Mot de passe oublié] Demande pour le compte #${me.id} : aucun envoi d'e-mail n'est configuré.`);
        }
        return { ok: true, devCode }; // même réponse si l'e-mail n'existe pas
      },
    },
    {
      method: 'POST', path: '/api/reset', public: true, limit: true,
      handler: ({ body: b }) => {
        const me = okMail(b.email) ? d.one('SELECT * FROM users WHERE email=?', b.email.trim()) : null;
        const r = me && d.one('SELECT * FROM resets WHERE user_id=?', me.id);
        if (!r || r.expires < Date.now() || r.tries >= 5) fail(400, 'Code invalide ou expiré');
        if (!check(String(b.code || ''), r.code)) { d.run('UPDATE resets SET tries=tries+1 WHERE user_id=?', me.id); fail(400, 'Code invalide ou expiré'); }
        pwdRule(b.password);
        d.tx(() => {
          d.run('UPDATE users SET pwd=?, tv=tv+1 WHERE id=?', hash(b.password), me.id); // déconnecte les autres sessions
          d.run('DELETE FROM resets WHERE user_id=?', me.id);
        });
        return { ok: true };
      },
    },
    { method: 'GET', path: '/api/me', handler: ({ me }) => pub(me) },
    {
      method: 'PUT', path: '/api/profile',
      handler: ({ me, body: b }) => {
        const name = String(b.name || '').trim(), email = String(b.email || '').trim(), phone = String(b.phone || '').trim();
        if (name.length < 2 || name.length > 80) fail(400, 'Nom invalide');
        if (!okMail(email)) fail(400, 'E-mail invalide');
        if (phone.length > 30) fail(400, 'Téléphone invalide');
        const specialty = isCoach(me) ? String(b.specialty ?? me.specialty ?? '').trim().slice(0, 80) || null : me.specialty;
        d.run('UPDATE users SET name=?, email=?, phone=?, specialty=? WHERE id=?', name, email, phone || null, specialty, me.id);
        return pub(byId(me.id));
      },
    },
    {
      method: 'POST', path: '/api/password', limit: true,
      handler: ({ me, body: b }) => {
        if (!check(String(b.old || ''), me.pwd)) fail(400, 'Ancien mot de passe incorrect');
        pwdRule(b.new);
        d.run('UPDATE users SET pwd=?, tv=tv+1 WHERE id=?', hash(b.new), me.id);
        return { ok: true, token: tok.sign(byId(me.id)) }; // les anciens jetons sont révoqués, celui-ci remplace le jeton courant
      },
    },
  ];
};
