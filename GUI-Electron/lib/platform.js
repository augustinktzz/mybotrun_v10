// What differs between Windows and Linux. On Windows nothing here is used: the interface keeps its original behaviour
// (PowerShell bridge, Windows paths, %APPDATA%). On Linux the bot runs in Wine: the bridge runs there too, in the same
// Wine prefix, and paths are passed to it in Windows form.
//   - run from the sources, the bridge is MyBotBridge.au3, run by the AutoIt installed in the prefix
//   - in the installed application (AppImage), it is MyBotBridge.exe, compiled by the release script: AutoIt is not
//     needed, only a Wine prefix (the one the bot runs in, with .NET 4.8 for MyBot.run.dll)
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
      // not in this folder
    }
  }
  return '';
}

// the compiled bridge of the installed application, if any
function bridgeExe() {
  if (!process.resourcesPath) return '';
  const file = path.join(process.resourcesPath, 'bridge', 'MyBotBridge.exe');
  return fs.existsSync(file) ? file : '';
}

// the Wine prefix: $WINEPREFIX, then ~/.wine32 (the bot is 32-bit), then ~/.wine. Without the compiled bridge, it must
// hold AutoIt.
function findPrefix(needAutoIt) {
  const candidates = [process.env.WINEPREFIX, path.join(os.homedir(), '.wine32'), path.join(os.homedir(), '.wine')];
  const usable = (p) => p && fs.existsSync(path.join(p, ...(needAutoIt ? AUTOIT_IN_PREFIX : ['drive_c'])));
  return candidates.find(usable) ?? '';
}

let cached;
// { bin, prefix, bridge: [program, ...args] } when the bot can be driven on Linux, otherwise null (always null on Windows)
function wine() {
  if (IS_WINDOWS) return null;
  if (cached === undefined) {
    const bin = which('wine');
    const exe = bridgeExe();
    const prefix = bin ? findPrefix(!exe) : '';
    cached = bin && prefix ? { bin, prefix, bridgeExe: exe } : null;
  }
  return cached;
}

// what is missing to drive the bot on Linux, for the error message
function wineProblem() {
  if (!which('wine')) return 'Wine was not found (install the wine package)';
  if (bridgeExe()) return 'No Wine prefix was found (~/.wine32 or ~/.wine, or set WINEPREFIX)';
  return `AutoIt was not found in the Wine prefix (${path.join('~', '.wine32', ...AUTOIT_IN_PREFIX)})`;
}

// Linux path -> the path Wine sees. Wine's Z: drive shows the root "/": the usual case. Otherwise winepath.
function toWinePath(p, prefix) {
  const abs = path.resolve(p);
  if (fs.existsSync(path.join(prefix, 'dosdevices', 'z:'))) return `Z:${abs.replace(/\//g, '\\')}`;
  const res = spawnSync('winepath', ['-w', abs], { env: { ...process.env, WINEPREFIX: prefix }, encoding: 'utf8' });
  return res.status === 0 ? res.stdout.trim() : abs;
}

// %APPDATA% as the bot sees it: the real one on Windows, the Wine user's on Linux ('' when unknown)
function appDataDir() {
  if (IS_WINDOWS) return process.env.APPDATA ?? '';
  const w = wine();
  return w ? path.join(w.prefix, 'drive_c', 'users', os.userInfo().username, 'AppData', 'Roaming') : '';
}

module.exports = { IS_WINDOWS, AUTOIT_WIN, wine, wineProblem, toWinePath, appDataDir };
