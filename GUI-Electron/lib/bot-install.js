// The bot inside the installed application.
//
// The installer (or the AppImage) carries the bot in resources/bot, with bot-manifest.json: its version and the SHA-256
// of every file. The bot cannot run from there: it writes its profiles, logs and temporary files next to itself, the
// install folder is replaced on every update, and an AppImage is read-only. So the bot is copied into a folder of its
// own, the "bot folder", and kept in step with the application:
//   Windows  %LOCALAPPDATA%\MyBot\Bot
//   Linux    ~/.local/share/MyBot/Bot   ($XDG_DATA_HOME/MyBot/Bot)
//
// An update copies only what changed, from the list of files the previous version installed (.mybot-manifest.json in
// the bot folder):
//   - a file of the new version that is missing or different is copied
//   - a file of the previous version that the new one no longer ships is deleted
//   - Profiles\ and every file the bot or the user created are never in a manifest: never touched
//   - CSV\ and Strategies\ hold files users edit: a shipped file the user changed there is kept, not replaced
// The manifest is written last, only when every file was copied: an interrupted update starts again next time.
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');

const MANIFEST = 'bot-manifest.json'; // in the payload
const INSTALLED_MANIFEST = '.mybot-manifest.json'; // in the bot folder
const USER_EDITABLE = /^(CSV|Strategies)\//i;

function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

async function sha256Async(file) {
  return crypto.createHash('sha256').update(await fsp.readFile(file)).digest('hex');
}

// same files with the same SHA-256 in two manifests
function sameFiles(a = {}, b = {}) {
  const keys = Object.keys(a);
  return keys.length === Object.keys(b).length && keys.every((rel) => a[rel] === b[rel]);
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return null;
  }
}

// every file under dir, as forward-slash paths relative to it
function listFiles(dir, base = dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) listFiles(full, base, out);
    else if (entry.isFile()) out.push(path.relative(base, full).split(path.sep).join('/'));
  }
  return out;
}

// used by the release script: the manifest of a payload folder
function writeManifest(dir, version) {
  const files = {};
  for (const rel of listFiles(dir).sort()) {
    if (rel === MANIFEST) continue;
    files[rel] = sha256(path.join(dir, rel));
  }
  fs.writeFileSync(path.join(dir, MANIFEST), JSON.stringify({ version, files }, null, 1));
  return Object.keys(files).length;
}

function defaultBotDir() {
  if (process.platform === 'win32') {
    return path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local'), 'MyBot', 'Bot');
  }
  return path.join(process.env.XDG_DATA_HOME || path.join(os.homedir(), '.local', 'share'), 'MyBot', 'Bot');
}

class BotInstall {
  // payloadDir: resources/bot of the installed application
  constructor(payloadDir, botDir = defaultBotDir()) {
    this.payloadDir = payloadDir;
    this.botDir = botDir;
  }

  get bundled() {
    if (this._bundled === undefined) this._bundled = readJson(path.join(this.payloadDir, MANIFEST));
    return this._bundled;
  }

  get installed() {
    return readJson(path.join(this.botDir, INSTALLED_MANIFEST));
  }

  status() {
    const next = this.bundled;
    const prev = this.installed;
    const bundled = next?.version ?? '';
    const installed = prev?.version ?? '';
    // the files are compared too: a build that keeps the version number (a fix rebuilt as 12.0.1 again) left the
    // previous bot in the bot folder
    const needsSync = Boolean(bundled) && (bundled !== installed || !sameFiles(next.files, prev?.files));
    return { botDir: this.botDir, bundledVersion: bundled, installedVersion: installed, needsSync };
  }

  // copies the bundled bot into the bot folder; onProgress(done, total). Throws when a file cannot be written (a bot
  // still running locks its files on Windows), after copying what it could.
  async sync({ verify = false, onProgress } = {}) {
    const next = this.bundled;
    if (!next) throw new Error(`The bot is missing from this installation (${path.join(this.payloadDir, MANIFEST)})`);
    const prev = this.installed?.files ?? {};
    const entries = Object.entries(next.files);
    const result = { copied: 0, removed: 0, kept: [], failed: [] };
    await fsp.mkdir(this.botDir, { recursive: true });

    for (const [i, [rel, hash]] of entries.entries()) {
      if (i % 25 === 0) onProgress?.(i, entries.length);
      const dest = path.join(this.botDir, ...rel.split('/'));
      try {
        if (fs.existsSync(dest)) {
          // unchanged since the previous version: nothing to do, unless asked to check the files themselves
          if (!verify && prev[rel] === hash) continue;
          const current = await sha256Async(dest);
          if (current === hash) continue;
          if (USER_EDITABLE.test(rel) && prev[rel] && current !== prev[rel]) {
            result.kept.push(rel);
            continue;
          }
        }
        await this.copy(rel, dest);
        result.copied++;
      } catch (err) {
        result.failed.push(`${rel}: ${err.code ?? err.message}`);
      }
    }

    // files of the previous version that this one no longer ships
    for (const [rel, hash] of Object.entries(prev)) {
      if (rel in next.files) continue;
      const file = path.join(this.botDir, ...rel.split('/'));
      try {
        if (!fs.existsSync(file)) continue;
        if (USER_EDITABLE.test(rel) && (await sha256Async(file)) !== hash) {
          result.kept.push(rel);
          continue;
        }
        await fsp.rm(file);
        result.removed++;
      } catch (err) {
        result.failed.push(`${rel}: ${err.code ?? err.message}`);
      }
    }
    onProgress?.(entries.length, entries.length);

    if (result.failed.length) {
      const err = new Error(`${result.failed.length} bot file(s) could not be updated. Close the bot and MultiBot, then try again.`);
      err.result = result;
      throw err;
    }
    await fsp.writeFile(path.join(this.botDir, INSTALLED_MANIFEST), JSON.stringify(next));
    return result;
  }

  // through a temporary file, so that a failed copy never leaves half a file behind
  async copy(rel, dest) {
    await fsp.mkdir(path.dirname(dest), { recursive: true });
    const tmp = `${dest}.mybot-update`;
    await fsp.copyFile(path.join(this.payloadDir, ...rel.split('/')), tmp);
    try {
      await fsp.rename(tmp, dest);
    } catch (err) {
      await fsp.rm(tmp, { force: true });
      throw err;
    }
  }

  // brings the profiles of another bot folder (a bot unzipped from GitHub, say) into this one: the profiles this folder
  // does not have yet, without their logs, and the strategies and attack scripts it does not have. Nothing here is
  // overwritten.
  async importFrom(oldDir) {
    if (path.resolve(oldDir) === path.resolve(this.botDir)) throw new Error('This is already the bot folder');
    const oldProfiles = path.join(oldDir, 'Profiles');
    if (!fs.existsSync(oldProfiles)) throw new Error(`No Profiles folder in ${oldDir}`);
    const result = { profiles: [], skipped: [], files: 0 };
    const profilesDir = path.join(this.botDir, 'Profiles');
    await fsp.mkdir(profilesDir, { recursive: true });
    const noLogs = (src) => !/^(Logs|Temp)$/i.test(path.basename(src)) || path.dirname(path.dirname(src)) !== oldProfiles;

    for (const entry of await fsp.readdir(oldProfiles, { withFileTypes: true })) {
      const dest = path.join(profilesDir, entry.name);
      if (fs.existsSync(dest)) {
        if (entry.isDirectory()) result.skipped.push(entry.name);
        continue;
      }
      await fsp.cp(path.join(oldProfiles, entry.name), dest, { recursive: true, filter: noLogs });
      if (entry.isDirectory()) result.profiles.push(entry.name);
      else result.files++;
    }
    for (const sub of ['Strategies', path.join('CSV', 'Attack')]) {
      const from = path.join(oldDir, sub);
      if (!fs.existsSync(from)) continue;
      for (const rel of listFiles(from)) {
        const dest = path.join(this.botDir, sub, ...rel.split('/'));
        if (fs.existsSync(dest)) continue;
        await fsp.mkdir(path.dirname(dest), { recursive: true });
        await fsp.copyFile(path.join(from, ...rel.split('/')), dest);
        result.files++;
      }
    }
    return result;
  }
}

// a folder that holds profiles worth importing
function hasProfiles(dir) {
  try {
    return fs.readdirSync(path.join(dir, 'Profiles'), { withFileTypes: true }).some((e) => e.isDirectory());
  } catch {
    return false;
  }
}

module.exports = { BotInstall, defaultBotDir, writeManifest, hasProfiles, MANIFEST };
