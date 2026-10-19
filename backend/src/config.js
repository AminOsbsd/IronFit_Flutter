'use strict';
// Configuration lue depuis les variables d'environnement (voir backend/.env.example)
const path = require('path');

function loadConfig(env = process.env) {
  const production = env.NODE_ENV === 'production';
  const flag = (v, def) => (v == null || v === '' ? def : v === 'true');
  return {
    production,
    port: env.PORT == null || env.PORT === '' ? 3000 : Number(env.PORT),
    host: env.HOST || '0.0.0.0',
    dataDir: path.resolve(env.DATA_DIR || path.join(__dirname, '..', 'data')),
    secret: env.IRONFIT_SECRET || null, // sinon : fichier data/secret généré au premier lancement
    tokenDays: Number(env.TOKEN_DAYS) || 7,
    corsOrigin: env.CORS_ORIGIN || '*',
    showResetCode: flag(env.SHOW_RESET_CODE, !production), // démo : code de réinitialisation renvoyé à l'app
    seedDemo: flag(env.SEED_DEMO, !production), // données de démonstration si la base est vide
    adminPassword: env.ADMIN_PASSWORD || (production ? null : 'admin123'),
    rateLimit: Number(env.RATE_LIMIT) || 10, // tentatives de connexion / inscription / réinitialisation par minute et par IP
    quiet: flag(env.QUIET, false),
  };
}

module.exports = { loadConfig };
