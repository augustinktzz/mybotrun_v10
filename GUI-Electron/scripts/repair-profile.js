#!/usr/bin/env node
// Repairs a profile that MyBot 12.0.0 / 12.0.1 saved before reading its settings (see lib/profile-repair.js).
//
//   node scripts/repair-profile.js <profile>                    shows what would change, writes nothing
//   node scripts/repair-profile.js <profile> --apply            writes it, after a copy of each file (.bak-<date>)
//   node scripts/repair-profile.js <profile> --keep a/b,c/d     leaves these settings as they are ("section/key")
//
// <profile> is a profile folder, or a profile name looked up in the Profiles folder of this repository, then in the
// bot folder of the installed application. Close the bot of that profile first: it rewrites its files when it closes.
const fs = require('node:fs');
const path = require('node:path');
const { planRepair, applyRepair } = require('../lib/profile-repair');
const { defaultBotDir } = require('../lib/bot-install');

const argv = process.argv.slice(2);
const apply = argv.includes('--apply');
const keepAt = argv.indexOf('--keep');
const keep = keepAt >= 0 ? String(argv[keepAt + 1] ?? '').split(',').filter(Boolean) : [];
const name = argv.find((a, i) => !a.startsWith('--') && (keepAt < 0 || i !== keepAt + 1));

if (!name) {
  console.log('Usage : node scripts/repair-profile.js <profil> [--apply] [--keep section/cle,...]');
  process.exit(2);
}

const candidates = [name, path.resolve(__dirname, '..', '..', 'Profiles', name), path.join(defaultBotDir(), 'Profiles', name)];
const dir = candidates.find((d) => fs.existsSync(path.join(d, 'config.ini')));
if (!dir) {
  console.error(`Profil introuvable (aucun config.ini) :\n  ${candidates.join('\n  ')}`);
  process.exit(1);
}

const changes = planRepair(dir, keep);
console.log(`Profil : ${dir}`);
if (!changes.length) {
  console.log('Rien à réparer : aucun réglage ne porte plus la valeur du bug.');
  process.exit(0);
}
for (const { file, id, current, value } of changes) console.log(`  ${file.padEnd(14)} ${id.padEnd(42)} ${JSON.stringify(current)} -> ${JSON.stringify(value)}`);
console.log(`${changes.length} réglage(s) à remettre par défaut.`);

if (!apply) {
  console.log('Simulation : rien n\'est écrit. Fermez le bot de ce profil, puis relancez avec --apply.');
  process.exit(0);
}
for (const backup of applyRepair(dir, changes)) console.log(`Copie de sauvegarde : ${backup}`);
console.log('Profil réparé.');
