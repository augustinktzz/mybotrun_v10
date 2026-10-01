// Pilote du bot : lancement de MyBot.run.exe et commandes par son API fenetre, a travers bridge/MyBotBridge.ps1.
// Meme ligne de commande que le .bat et MultiBot :  MyBot.run.exe <profil> <emulateur> <instance> [/switches]
// Sous Linux le bot tourne dans Wine : le pont est bridge/MyBotBridge.au3, lance dans le meme prefixe Wine, avec le
// meme protocole (voir lib/platform.js). Sous Windows rien ne change.
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const readline = require('node:readline');
const platform = require('./platform');

// gui : se declarer comme l'interface du bot, qui n'a plus de fenetre a lui (voir main.js)
const API = { state: 0x00ff, start: 0x1000, stop: 0x1010, resume: 0x1020, pause: 0x1030, close: 0x1040, gui: 0x1060 };
const BIT_RUNNING = 1;
const BIT_PAUSED = 2;
const BIT_LAUNCHED = 4;
// ordre de MultiBot ($g_asParamSwitch), sans /minigui : le bot n'a plus de fenetre, ce GUI est son interface
const SWITCHES = ['debug', 'dpiaware', 'hideandroid', 'nowatchdog', 'autostart'];

function botExecutable(botDir) {
  for (const name of ['MyBot.run.exe', 'MyBot.run.au3']) {
    const file = path.join(botDir, name);
    if (fs.existsSync(file)) return file;
  }
  return '';
}

function quote(arg) {
  return /\s/.test(arg) ? `"${arg}"` : arg;
}

// le profil est le premier vrai argument de la ligne de commande (on saute l'exe, et le .au3 lance par AutoIt3.exe)
function profileOfCommandLine(cmd) {
  const tokens = cmd.match(/"[^"]*"|\S+/g) ?? [];
  for (const raw of tokens.slice(1)) {
    const token = raw.replace(/^"|"$/g, '');
    if (/\.(exe|au3)$/i.test(token)) continue;
    return token;
  }
  return '';
}

class BotBridge {
  constructor(scriptPath) {
    // dans l'appli empaquetee, le script est sorti de l'archive asar (asarUnpack) pour que PowerShell puisse le lire
    this.script = scriptPath.replace(`app.asar${path.sep}`, `app.asar.unpacked${path.sep}`);
    // le pont de Linux, a cote de celui de Windows
    this.wineScript = path.join(path.dirname(this.script), 'MyBotBridge.au3');
    this.proc = null;
    this.pending = new Map();
    this.nextId = 1;
    this.ready = null;
  }

  get supported() {
    return process.platform === 'win32' || Boolean(platform.wine());
  }

  // le pont : PowerShell sous Windows ; sous Linux, MyBotBridge.au3 par l'AutoIt du prefixe Wine
  spawnBridge() {
    if (process.platform === 'win32') {
      return spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', this.script], {
        windowsHide: true,
        stdio: ['pipe', 'pipe', 'pipe'],
      });
    }
    const w = platform.wine();
    return spawn(w.bin, [w.autoit, platform.toWinePath(this.wineScript, w.prefix)], {
      env: { ...process.env, WINEPREFIX: w.prefix, WINEDEBUG: '-all' },
      stdio: ['pipe', 'pipe', 'pipe'],
    });
  }

  ensure() {
    if (!this.supported) {
      return Promise.reject(new Error(process.platform === 'linux' ? `Pilotage impossible : ${platform.wineProblem()}` : 'Le pilotage du bot ne fonctionne que sous Windows'));
    }
    if (this.ready) return this.ready;
    this.proc = this.spawnBridge();
    this.ready = new Promise((resolve, reject) => {
      this.pending.set(0, { resolve, reject, timer: null });
    });
    readline.createInterface({ input: this.proc.stdout }).on('line', (line) => this.onLine(line));
    this.proc.stderr.on('data', (d) => console.error('[bridge]', d.toString()));
    this.proc.on('exit', (code) => {
      const err = new Error(`Le pont PowerShell s'est arrete (code ${code})`);
      for (const p of this.pending.values()) {
        clearTimeout(p.timer);
        p.reject(err);
      }
      this.pending.clear();
      this.proc = null;
      this.ready = null;
    });
    return this.ready;
  }

  onLine(line) {
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      return; // ligne parasite de PowerShell
    }
    const p = this.pending.get(msg.id);
    if (!p) return;
    this.pending.delete(msg.id);
    clearTimeout(p.timer);
    if (msg.ok) p.resolve(msg.result);
    else p.reject(new Error(msg.error));
  }

  async request(cmd, args = {}, timeoutMs = 10000) {
    await this.ensure();
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Pas de reponse du pont pour "${cmd}"`));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer });
      let line = JSON.stringify({ id, cmd, ...args });
      // le pont AutoIt lit sa console en ASCII : tout autre caractere voyage en \uXXXX (JSON valide pour les deux ponts)
      if (process.platform !== 'win32') line = line.replace(/[\u007f-￿]/g, (c) => `\\u${c.charCodeAt(0).toString(16).padStart(4, '0')}`);
      this.proc.stdin.write(line + '\n');
    });
  }

  async windows() {
    const list = await this.request('list');
    return (Array.isArray(list) ? list : list ? [list] : []).map((w) => ({
      ...w,
      profile: profileOfCommandLine(w.commandLine || ''),
      instance: /\(([^()]+)\)\s*$/.exec(w.title)?.[1] ?? '',
    }));
  }

  // la fenetre du bot de ce profil ; a defaut de ligne de commande lisible, l'instance du titre "My Bot v12.0.0 (Pie64)"
  async find(profile, instance) {
    const all = await this.windows();
    const lower = profile.toLowerCase();
    return all.find((w) => w.profile.toLowerCase() === lower) ?? all.find((w) => !w.profile && w.instance === instance) ?? null;
  }

  async state(profile, instance) {
    const win = await this.find(profile, instance);
    if (!win) return { state: 'off' };
    const { bits } = await this.request('ask', { hwnd: win.hwnd, code: API.state, timeout: 1500 });
    return { state: decode(bits), pid: win.pid, hwnd: win.hwnd, title: win.title };
  }

  async command(profile, instance, name) {
    if (!(name in API)) throw new Error(`Commande inconnue : ${name}`);
    const win = await this.find(profile, instance);
    if (!win) throw new Error(`Aucun bot ouvert pour le profil ${profile}`);
    const { bits } = await this.request('ask', { hwnd: win.hwnd, code: API[name], timeout: 3000 });
    if (bits === -2) throw new Error("Windows a refuse le message : lancez l'interface en administrateur, comme le bot");
    return { state: decode(bits) };
  }

  // le bot, sans fenetre, retient le PID de l'interface qui se declare (code 0x1060) ; c'est celui du pont. Il ne
  // repond pas tant qu'il demarre : on n'attend pas de reponse.
  async registerGui(hwnd, waitAnswer) {
    return this.request('ask', { hwnd, code: API.gui, timeout: waitAnswer ? 1500 : 100 });
  }

  async launch({ botDir, profile, emulator, instance, switches }) {
    const file = botExecutable(botDir);
    if (!file) throw new Error(`MyBot.run.exe introuvable dans ${botDir}`);
    const running = await this.find(profile, instance);
    if (running) throw new Error(`Le bot du profil ${profile} est deja ouvert`);
    const flags = SWITCHES.filter((s) => switches?.[s]).map((s) => `/${s}`);
    const args = [quote(profile), emulator, quote(instance), ...flags].join(' ');
    if (process.platform !== 'win32') {
      // le pont tourne dans Wine : il lui faut les chemins tels que Wine les voit
      const { prefix } = platform.wine();
      return this.request('launch', { file: platform.toWinePath(file, prefix), args, cwd: platform.toWinePath(botDir, prefix) });
    }
    return this.request('launch', { file, args, cwd: botDir });
  }

  dispose() {
    if (this.proc) this.proc.stdin.end();
  }
}

function decode(bits) {
  if (bits === -2) return 'denied';
  if (bits < 0) return 'noanswer'; // occupe, ou encore en train de demarrer
  if (!(bits & BIT_LAUNCHED)) return 'starting';
  if (bits & BIT_PAUSED) return 'paused';
  if (bits & BIT_RUNNING) return 'running';
  return 'idle';
}

module.exports = { BotBridge, botExecutable, profileOfCommandLine, SWITCHES };
