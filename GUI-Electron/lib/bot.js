// Drives the bot: launches MyBot.run.exe and sends it commands through its window API, via bridge/MyBotBridge.ps1.
// Same command line as MultiBot:  MyBot.run.exe <profile> <emulator> <instance> [/switches]
// On Linux the bot runs in Wine: the bridge is MyBotBridge.au3 (or its compiled MyBotBridge.exe in the installed
// application), run in the same Wine prefix, with the same protocol (see lib/platform.js). Windows is unchanged.
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const readline = require('node:readline');
const platform = require('./platform');

// gui: register as the bot's interface, as the bot has no window of its own any more (see main.js)
const API = { state: 0x00ff, start: 0x1000, stop: 0x1010, resume: 0x1020, pause: 0x1030, close: 0x1040, gui: 0x1060 };
const BIT_RUNNING = 1;
const BIT_PAUSED = 2;
const BIT_LAUNCHED = 4;
// MultiBot's order ($g_asParamSwitch), without /minigui: the bot has no window, this interface is its window
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

// the profile is the first real argument of the command line (skipping the exe, and the .au3 run by AutoIt3.exe)
function profileOfCommandLine(cmd) {
  const tokens = cmd.match(/"[^"]*"|\S+/g) ?? [];
  for (const raw of tokens.slice(1)) {
    const token = raw.replace(/^"|"$/g, '');
    if (/\.(exe|au3)$/i.test(token)) continue;
    return token;
  }
  return '';
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

class BotBridge {
  constructor(scriptPath) {
    // in the packaged application the script is taken out of the asar archive (asarUnpack) so that PowerShell can read it
    this.script = scriptPath.replace(`app.asar${path.sep}`, `app.asar.unpacked${path.sep}`);
    // the Linux bridge, next to the Windows one
    this.wineScript = path.join(path.dirname(this.script), 'MyBotBridge.au3');
    this.proc = null;
    this.pending = new Map();
    this.nextId = 1;
    this.ready = null;
  }

  get supported() {
    return process.platform === 'win32' || Boolean(platform.wine());
  }

  // the bridge: PowerShell on Windows; on Linux, MyBotBridge.exe or MyBotBridge.au3 in the bot's Wine prefix
  spawnBridge() {
    if (process.platform === 'win32') {
      return spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', this.script], {
        windowsHide: true,
        stdio: ['pipe', 'pipe', 'pipe'],
      });
    }
    const w = platform.wine();
    const args = w.bridgeExe ? [platform.toWinePath(w.bridgeExe, w.prefix)] : [platform.AUTOIT_WIN, platform.toWinePath(this.wineScript, w.prefix)];
    return spawn(w.bin, args, {
      env: { ...process.env, WINEPREFIX: w.prefix, WINEDEBUG: '-all' },
      stdio: ['pipe', 'pipe', 'pipe'],
    });
  }

  ensure() {
    if (!this.supported) {
      return Promise.reject(new Error(process.platform === 'linux' ? `The bot cannot be driven: ${platform.wineProblem()}` : 'The bot can only be driven on Windows and Linux'));
    }
    if (this.ready) return this.ready;
    this.proc = this.spawnBridge();
    this.ready = new Promise((resolve, reject) => {
      this.pending.set(0, { resolve, reject, timer: null });
    });
    readline.createInterface({ input: this.proc.stdout }).on('line', (line) => this.onLine(line));
    this.proc.stderr.on('data', (d) => console.error('[bridge]', d.toString()));
    this.proc.on('exit', (code) => {
      const err = new Error(`The bridge to the bot stopped (code ${code})`);
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
      return; // stray output of PowerShell
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
        reject(new Error(`No answer from the bridge for "${cmd}"`));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer });
      let line = JSON.stringify({ id, cmd, ...args });
      // the AutoIt bridge reads its console as ASCII: any other character travels as \uXXXX (valid JSON for both bridges)
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

  // the bot window of this profile; without a readable command line, the instance in the title "My Bot v12.0.0 (Pie64)"
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
    if (!(name in API)) throw new Error(`Unknown command: ${name}`);
    const win = await this.find(profile, instance);
    if (!win) throw new Error(`No bot is open for the profile ${profile}`);
    const { bits } = await this.request('ask', { hwnd: win.hwnd, code: API[name], timeout: 3000 });
    if (bits === -2) throw new Error('Windows refused the message: run this interface as administrator, like the bot');
    return { state: decode(bits) };
  }

  // the bot, without a window, remembers the PID of the interface that registers (code 0x1060); it is the bridge's. It
  // does not answer while it starts: no answer is awaited then.
  async registerGui(hwnd, waitAnswer) {
    return this.request('ask', { hwnd, code: API.gui, timeout: waitAnswer ? 1500 : 100 });
  }

  // every open bot, whatever its profile (an update needs them all closed: Windows locks the files of a running bot)
  async anyRunning() {
    if (!this.supported) return false;
    return (await this.windows()).length > 0;
  }

  // asks every open bot to close (each saves its settings, its Watchdog ends with it), then waits until none is left
  async closeAll(timeoutMs = 90000) {
    for (const win of await this.windows()) {
      await this.request('ask', { hwnd: win.hwnd, code: API.close, timeout: 3000 }).catch(() => {});
    }
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
      if (!(await this.anyRunning())) return;
      await sleep(1500);
    }
    throw new Error('A bot did not close. Close it, then try again.');
  }

  async launch({ botDir, profile, emulator, instance, switches }) {
    const file = botExecutable(botDir);
    if (!file) throw new Error(`MyBot.run.exe was not found in ${botDir}`);
    const running = await this.find(profile, instance);
    if (running) throw new Error(`The bot of the profile ${profile} is already open`);
    const flags = SWITCHES.filter((s) => switches?.[s]).map((s) => `/${s}`);
    const args = [quote(profile), emulator, quote(instance), ...flags].join(' ');
    if (process.platform !== 'win32') {
      // the bridge runs in Wine: it needs the paths as Wine sees them
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
  if (bits < 0) return 'noanswer'; // busy, or still starting
  if (!(bits & BIT_LAUNCHED)) return 'starting';
  if (bits & BIT_PAUSED) return 'paused';
  if (bits & BIT_RUNNING) return 'running';
  return 'idle';
}

module.exports = { BotBridge, botExecutable, profileOfCommandLine, SWITCHES };
