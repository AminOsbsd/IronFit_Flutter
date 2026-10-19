'use strict';
// IronFit – serveur API sans dépendance npm (Node.js 22.13+ : SQLite intégré via node:sqlite)
//   node server.js           démarre le serveur
//   node server.js --reset   supprime la base locale puis la recrée (données de démo si SEED_DEMO)
const http = require('http'), fs = require('fs'), path = require('path'), os = require('os');

const major = Number(process.versions.node.split('.')[0]), minor = Number(process.versions.node.split('.')[1]);
if (major < 22 || (major === 22 && minor < 13)) { console.error('\n  Node.js 22.13 ou plus récent est requis (https://nodejs.org, version LTS).\n'); process.exit(1); }

const { loadConfig } = require('./src/config');
const { openDb, seed } = require('./src/db');
const { loadSecret } = require('./src/security');
const { createApp } = require('./src/app');

/** Démarre le serveur ; utilisé par `node server.js` et par les tests (port 0 = port libre). */
function start(env = process.env, { reset = false } = {}) {
  const cfg = loadConfig(env);
  fs.mkdirSync(cfg.dataDir, { recursive: true });
  const file = path.join(cfg.dataDir, 'gym.db');
  if (reset) for (const f of [file, file + '-wal', file + '-shm']) fs.rmSync(f, { force: true });
  const d = openDb(file);
  const seeded = seed(d, cfg);
  const server = http.createServer(createApp({ cfg, d, secret: loadSecret(cfg) }));
  const ready = new Promise((ok, ko) => { server.once('error', ko); server.listen(cfg.port, cfg.host, () => ok()); });
  return { cfg, d, server, seeded, ready, close: () => new Promise(ok => server.close(() => { d.close(); ok(); })) };
}

if (require.main === module) {
  try { process.loadEnvFile(path.join(__dirname, '.env')); } catch { /* fichier .env facultatif */ }
  let app;
  try { app = start(process.env, { reset: process.argv.includes('--reset') }); }
  catch (e) { console.error('\n  ' + e.message + '\n'); process.exit(1); }
  const { cfg, d, ready, seeded } = app;
  ready.then(() => {
    const ips = Object.values(os.networkInterfaces()).flat().filter(i => i.family === 'IPv4' && !i.internal).map(i => i.address);
    const port = app.server.address().port;
    console.log(`\n  💪 IronFit démarré (schéma v${d.migration.to}${d.migration.from !== d.migration.to ? `, migré depuis v${d.migration.from}` : ''})`);
    console.log(`  PC        : http://localhost:${port}`);
    console.log(`  Téléphone : ${ips.map(i => `http://${i}:${port}`).join('  ') || '(non connecté au réseau)'}`);
    if (seeded) console.log(`  Base initialisée${cfg.seedDemo ? ' avec les données de démo' : ''}.`);
    if (!cfg.production) console.log('  Mode développement : comptes de démo actifs, code de réinitialisation affiché dans l’app.');
    console.log('');
  }).catch(e => { console.error(`\n  Impossible d'écouter sur le port ${cfg.port} : ${e.message}\n`); process.exit(1); });
  const stop = () => app.close().then(() => process.exit(0));
  process.on('SIGINT', stop); process.on('SIGTERM', stop);
}

module.exports = { start };
