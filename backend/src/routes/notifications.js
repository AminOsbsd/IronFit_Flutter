'use strict';
// Notifications personnelles (abonnement, coaching, programmes, commentaires, annonces, séances annulées)
const { page } = require('../util');

module.exports = S => {
  const { d } = S;
  return [
    {
      method: 'GET', path: '/api/notifications',
      handler: ({ me, query }) => {
        const { limit, offset } = page(query, 50);
        return {
          unread: d.one('SELECT COUNT(*) n FROM notifications WHERE user_id=? AND seen=0', me.id).n,
          items: d.q('SELECT * FROM notifications WHERE user_id=? ORDER BY id DESC LIMIT ? OFFSET ?', me.id, limit, offset),
        };
      },
    },
    { method: 'POST', path: '/api/notifications/:id/read', handler: ({ me, params }) => { d.run('UPDATE notifications SET seen=1 WHERE id=? AND user_id=?', params.id, me.id); return { ok: true }; } },
    { method: 'POST', path: '/api/notifications/read-all', handler: ({ me }) => { d.run('UPDATE notifications SET seen=1 WHERE user_id=? AND seen=0', me.id); return { ok: true }; } },
  ];
};
