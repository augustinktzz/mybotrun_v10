// Ce qui differe entre Windows et Linux. Sous Windows rien ici ne sert : le GUI garde son fonctionnement d'origine
// (pont PowerShell, chemins Windows, %APPDATA%). Sous Linux le bot tourne dans Wine : le pont (MyBotBridge.au3) y
// tourne aussi, par l'AutoIt installe dans le meme prefixe Wine, et les chemins lui sont passes au format Windows.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const IS_WINDOWS = process.platform === 'win32';
const AUTOIT_WIN = 'C:\\Program Files\\AutoIt3\\AutoIt3.exe';
const AUTOIT_IN_PREFIX = ['drive_c', 'Program Files', 'AutoIt3', 'AutoIt3.exe'];

function which(cmd) {
  for (const dir of (process.env.PATH ?? '').split(path.delimiter)) {
    const file = path.join(dir, cmd);
    try {
      fs.accessSync(file, fs.constants.X_OK);
      return file;
    } catch {
      // pas dans ce dossier
    }
  }
  return '';
}

// le prefixe Wine ou AutoIt est installe : $WINEPREFIX, puis ~/.wine32 (le bot est en 32 bits), puis ~/.wine
function findPrefix() {
  const candidates = [process.env.WINEPREFIX, path.join(os.homedir(), '.wine32'), path.join(os.homedir(), '.wine')];
  return candidates.find((p) => p && fs.existsSync(path.join(p, ...AUTOIT_IN_PREFIX))) ?? '';
}

let cached;
// { bin, prefix, autoit } si le bot peut etre pilote sous Linux, sinon null (et toujours null sous Windows)
function wine() {
  if (IS_WINDOWS) return null;
  if (cached === undefined) {
    const bin = which('wine');
    const prefix = bin ? findPrefix() : '';
    cached = bin && prefix ? { bin, prefix, autoit: AUTOIT_WIN } : null;
  }
  return cached;
}

// ce qu'il manque pour piloter le bot sous Linux, pour le message d'erreur
function wineProblem() {
  if (!which('wine')) return 'Wine est introuvable (installez le paquet wine)';
  return `AutoIt est introuvable dans le prefixe Wine (${path.join('~', '.wine32', ...AUTOIT_IN_PREFIX)})`;
}

// chemin Linux -> chemin vu par Wine. Le lecteur Z: de Wine montre la racine "/" : c'est le cas normal. Sinon winepath.
function toWinePath(p, prefix) {
  const abs = path.resolve(p);
  if (fs.existsSync(path.join(prefix, 'dosdevices', 'z:'))) return `Z:${abs.replace(/\//g, '\\')}`;
  const res = spawnSync('winepath', ['-w', abs], { env: { ...process.env, WINEPREFIX: prefix }, encoding: 'utf8' });
  return res.status === 0 ? res.stdout.trim() : abs;
}

// %APPDATA% tel que le bot le voit : le vrai sous Windows, celui de l'utilisateur Wine sous Linux ('' si inconnu)
function appDataDir() {
  if (IS_WINDOWS) return process.env.APPDATA ?? '';
  const w = wine();
  return w ? path.join(w.prefix, 'drive_c', 'users', os.userInfo().username, 'AppData', 'Roaming') : '';
}

module.exports = { IS_WINDOWS, wine, wineProblem, toWinePath, appDataDir };
