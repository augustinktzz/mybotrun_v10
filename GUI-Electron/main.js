// Main process: the window, the interface's settings, and everything that touches the disk and the bot (logs, profile
// .ini files, strategies, launch and commands, updates). The page (renderer/) reaches them only through preload.js.
const { app, BrowserWindow, ipcMain, dialog, shell, systemPreferences } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const { Settings } = require('./lib/settings');
const { LogTail, parseAttackLine, ATTACK_LOG_NAME } = require('./lib/log-tail');
const { BotBridge, botExecutable } = require('./lib/bot');
const { ProfileStore } = require('./lib/profile-store');
const { BotInstall, hasProfiles } = require('./lib/bot-install');
const { planRepair, applyRepair } = require('./lib/profile-repair');
const { Updater } = require('./lib/updater');

const DEMO = process.argv.includes('--demo');
const HISTORY = 1500; // log lines kept for a reloaded page

// the settings stay where the first versions of this interface kept them (%APPDATA%\MyBot GUI), whatever the product
// is called now: an update must not lose them
app.setPath('userData', path.join(app.getPath('appData'), 'MyBot GUI'));

let win = null;
let settings = null;
let updater = null;
let install = null; // the bot inside the installed application (null when run from the sources)
let pollTimer = null;
let lastState = { state: 'off' };
let logFile = '';
const history = [];
const attackHistory = [];
const tail = new LogTail();
const attackTail = new LogTail({ pattern: ATTACK_LOG_NAME, parse: parseAttackLine });
const bridge = new BotBridge(path.join(__dirname, 'bridge', 'MyBotBridge.ps1'));
const store = new ProfileStore(() => settings.get());

// ---------------------------------------------------------------------------------------------------------------------
// bot folders
// ---------------------------------------------------------------------------------------------------------------------
const isBotDir = (dir) => Boolean(dir) && botExecutable(dir) !== '';

// run from the sources: the chosen folder, otherwise the one holding the interface (GUI-Electron\ inside the bot folder)
function detectBotDir() {
  const candidates = [settings.get().botDir, path.dirname(app.getAppPath())];
  return candidates.find(isBotDir) ?? '';
}

function paths() {
  const { botDir } = settings.get();
  const profileDir = store.profileDir();
  return {
    botDir,
    profileDir,
    logs: path.join(profileDir, 'Logs'),
    strategies: store.strategiesDir,
    scripts: path.join(botDir, 'CSV', 'Attack'),
  };
}

// ---------------------------------------------------------------------------------------------------------------------
// log and bot state
// ---------------------------------------------------------------------------------------------------------------------
function send(channel, payload) {
  if (win && !win.isDestroyed()) win.webContents.send(channel, payload);
}

tail.on('lines', (lines) => {
  history.push(...lines);
  if (history.length > HISTORY) history.splice(0, history.length - HISTORY);
  send('log:lines', lines);
});
tail.on('file', (name) => {
  logFile = name;
  send('log:file', name);
});
attackTail.on('lines', (lines) => {
  attackHistory.push(...lines);
  if (attackHistory.length > HISTORY) attackHistory.splice(0, attackHistory.length - HISTORY);
  send('atklog:lines', lines);
});

function restartWatchers() {
  history.length = 0;
  attackHistory.length = 0;
  logFile = '';
  tail.stop();
  attackTail.stop();
  clearInterval(pollTimer);
  if (DEMO || !settings.get().botDir) return;
  tail.start(paths().logs);
  attackTail.start(paths().logs);
  if (bridge.supported) {
    pollTimer = setInterval(pollState, 2000);
    pollState();
  }
}

let polling = false;
let launchedAt = 0;
let linkedBotPid = 0;

// the bot has no window of its own, this interface is its window: register while it starts, then once per bot already
// running (interface reopened while it runs, or bot launched by MultiBot or restarted by the Watchdog)
async function linkBot(st) {
  if (!st.hwnd) return;
  const starting = st.state === 'noanswer' || st.state === 'starting';
  if (!starting && linkedBotPid === st.pid) return;
  try {
    await bridge.registerGui(st.hwnd, !starting);
    if (!starting) linkedBotPid = st.pid;
  } catch {
    // retried on the next round
  }
}
async function pollState() {
  if (polling) return;
  polling = true;
  try {
    const { profile, instance } = settings.get();
    lastState = await bridge.state(profile, instance);
    await linkBot(lastState);
    // the bot takes a while to create its window: right after a launch, "no window" means "still starting"
    if (lastState.state !== 'off') launchedAt = 0;
    else if (Date.now() - launchedAt < 90000) lastState = { state: 'starting' };
  } catch (err) {
    lastState = { state: 'error', error: err.message };
  } finally {
    polling = false;
  }
  send('bot:state', lastState);
  if (botSync.phase === 'waiting' && lastState.state === 'off') resumeSync();
}

// ---------------------------------------------------------------------------------------------------------------------
// the bot of the installed application: copied into its folder, and kept in step with each update
// ---------------------------------------------------------------------------------------------------------------------
let botSync = { phase: 'idle' }; // idle | waiting (a bot runs: its files are locked) | copying | done | error

function setSync(next) {
  botSync = next;
  send('bot:sync', botSync);
  return botSync;
}

async function syncBot({ verify = false } = {}) {
  if (!install || botSync.phase === 'copying') return botSync;
  const status = install.status();
  if (!status.needsSync && !verify) return setSync({ phase: 'idle' });
  if (await bridge.anyRunning().catch(() => false)) return setSync({ phase: 'waiting', version: status.bundledVersion });
  const version = status.bundledVersion;
  setSync({ phase: 'copying', version, done: 0, total: 0 });
  try {
    const res = await install.sync({ verify, onProgress: (done, total) => setSync({ phase: 'copying', version, done, total }) });
    setSync({ phase: 'done', version, copied: res.copied, removed: res.removed, kept: res.kept });
  } catch (err) {
    setSync({ phase: 'error', version, error: err.message });
  }
  restartWatchers();
  send('info:changed', info());
  return botSync;
}

let lastResume = 0;
function resumeSync() {
  if (Date.now() - lastResume < 10000) return;
  lastResume = Date.now();
  syncBot();
}

// ---------------------------------------------------------------------------------------------------------------------
// IPC
// ---------------------------------------------------------------------------------------------------------------------
function info() {
  const s = settings.get();
  return {
    version: app.getVersion(),
    platform: process.platform,
    demo: DEMO,
    control: bridge.supported,
    botFound: isBotDir(s.botDir),
    logFile,
    settings: s,
    packaged: Boolean(install),
    bot: install ? install.status() : null,
    // the bot folder used before the installed application, while it still has profiles to import
    legacyBotDir: install && s.legacyBotDir && hasProfiles(s.legacyBotDir) ? s.legacyBotDir : '',
  };
}

ipcMain.handle('app:info', () => info());

ipcMain.handle('settings:set', (_e, patch) => {
  const before = settings.get();
  settings.set(patch);
  const after = settings.get();
  if (before.botDir !== after.botDir || before.profile !== after.profile) restartWatchers();
  return info();
});

ipcMain.handle('dialog:botDir', async () => {
  if (install) return { ...info(), error: 'The installed application keeps the bot in its own folder' };
  const res = await dialog.showOpenDialog(win, {
    title: 'MyBot folder (the one that holds MyBot.run.exe)',
    properties: ['openDirectory'],
    defaultPath: settings.get().botDir || app.getPath('desktop'),
  });
  if (res.canceled || !res.filePaths[0]) return { ...info(), canceled: true };
  const dir = res.filePaths[0];
  if (!isBotDir(dir)) return { ...info(), error: `MyBot.run.exe (or MyBot.run.au3) was not found in ${dir}` };
  settings.set({ botDir: dir });
  restartWatchers();
  return info();
});

// the bot rewrites all its .ini files when it saves (when it closes, notably): a change made while it is open would be
// lost
const CLOSE_FIRST = 'Close the bot of this profile first: it rewrites its settings when it quits.';
const botOpen = () => !['off', 'error'].includes(lastState.state);

// the bot of another profile than the driven one: its window, if it is open
async function otherBotOpen(profile) {
  if (profile.toLowerCase() === settings.get().profile.toLowerCase()) return botOpen();
  if (!bridge.supported || DEMO) return false;
  try {
    return Boolean(await bridge.find(profile, ''));
  } catch {
    return false;
  }
}

function guarded(fn) {
  return async (...args) => {
    try {
      return { ok: true, result: await fn(...args) };
    } catch (err) {
      return { ok: false, error: err.message };
    }
  };
}

ipcMain.handle('profiles:list', () => store.listProfiles());

ipcMain.handle('config:get', (_e, ids) => store.getValues(ids));

ipcMain.handle(
  'config:set',
  guarded((_e, values) => {
    if (botOpen()) throw new Error(CLOSE_FIRST);
    store.setValues(values);
  }),
);

ipcMain.handle(
  'profiles:create',
  guarded((_e, { name, copy }) => store.createProfile(name, copy ? settings.get().profile : null)),
);

ipcMain.handle(
  'profiles:rename',
  guarded(async (_e, { from, to }) => {
    if (await otherBotOpen(from)) throw new Error(`Close the bot of the profile ${from} first`);
    const name = store.renameProfile(from, to);
    if (from.toLowerCase() === settings.get().profile.toLowerCase()) {
      settings.set({ profile: name });
      restartWatchers();
    }
    return name;
  }),
);

ipcMain.handle(
  'profiles:delete',
  guarded(async (_e, name) => {
    if (await otherBotOpen(name)) throw new Error(`Close the bot of the profile ${name} first`);
    store.deleteProfile(name);
    if (name.toLowerCase() === settings.get().profile.toLowerCase()) {
      const next = store.listProfiles().find((p) => p.hasConfig) ?? store.listProfiles()[0];
      settings.set({ profile: next?.name ?? 'MyVillage' });
      restartWatchers();
    }
  }),
);

// profiles of another bot folder (a bot unzipped from GitHub before the installed application): dir, or one to pick
ipcMain.handle(
  'profiles:import',
  guarded(async (_e, dir) => {
    if (!install) throw new Error('Importing profiles is for the installed application');
    if (!dir) {
      const res = await dialog.showOpenDialog(win, { title: 'Former MyBot folder (the one that holds Profiles)', properties: ['openDirectory'] });
      if (res.canceled || !res.filePaths[0]) return null;
      dir = res.filePaths[0];
    }
    const result = await install.importFrom(dir);
    if (path.resolve(dir) === path.resolve(settings.get().legacyBotDir || '.')) settings.set({ legacyBotDir: '' });
    send('info:changed', info());
    return result;
  }),
);

ipcMain.handle(
  'profiles:dismissImport',
  guarded(() => {
    settings.set({ legacyBotDir: '' });
    return info();
  }),
);

// the settings that MyBot 12.0.0 / 12.0.1 saved before reading them (lib/profile-repair.js): what a repair would change
ipcMain.handle('profiles:repairPlan', (_e, name) => {
  try {
    return planRepair(store.profileDir(name || settings.get().profile));
  } catch {
    return [];
  }
});
ipcMain.handle(
  'profiles:repair',
  guarded(async (_e, name) => {
    name ||= settings.get().profile;
    if (await otherBotOpen(name)) throw new Error(CLOSE_FIRST);
    const dir = store.profileDir(name);
    const changes = planRepair(dir);
    return { count: changes.length, backups: changes.length ? applyRepair(dir, changes) : [] };
  }),
);

ipcMain.handle('strategies:list', () => store.listStrategies());
ipcMain.handle(
  'strategies:load',
  guarded((_e, name) => {
    if (botOpen()) throw new Error(CLOSE_FIRST);
    return store.loadStrategy(name);
  }),
);
ipcMain.handle(
  'strategies:save',
  guarded((_e, { name, notes }) => store.saveStrategy(name, notes)),
);
ipcMain.handle(
  'strategies:delete',
  guarded((_e, name) => store.deleteStrategy(name)),
);

ipcMain.handle('lists:get', (_e, kind) => store.list(kind));

ipcMain.handle('bot:launch', async () => {
  const s = settings.get();
  if (install?.status().needsSync) throw new Error('The bot is being updated: wait for the end of the update (Updates page)');
  if (launchedAt && Date.now() - launchedAt < 90000) throw new Error('The bot is already starting');
  const res = await bridge.launch({ botDir: s.botDir, profile: s.profile, emulator: s.emulator, instance: s.instance, switches: s.switches });
  launchedAt = Date.now();
  lastState = { state: 'starting' };
  send('bot:state', lastState);
  return res;
});

ipcMain.handle('bot:command', async (_e, name) => {
  const s = settings.get();
  const res = await bridge.command(s.profile, s.instance, name);
  setTimeout(pollState, 400);
  return res;
});

ipcMain.handle('bot:state', () => lastState);
ipcMain.handle('log:history', () => history);
ipcMain.handle('atklog:history', () => attackHistory);

ipcMain.handle('shell:open', (_e, what) => {
  const p = paths();
  const target = { botDir: p.botDir, profile: p.profileDir, logs: p.logs, strategies: p.strategies, scripts: p.scripts }[what];
  if (target && fs.existsSync(target)) return shell.openPath(target);
  return `Folder not found: ${target}`;
});

// --------------------------------------------------------------------------------------------------- updates
ipcMain.handle('update:state', () => ({ ...updater.getState(), sync: botSync }));
ipcMain.handle('update:check', guarded(() => updater.check(false)));
ipcMain.handle('update:download', guarded(() => updater.download()));
ipcMain.handle(
  'update:options',
  guarded((_e, patch) => {
    settings.set({ updates: patch });
    return updater.setOptions(patch);
  }),
);
// the bots are closed first when asked: the new bot is copied into the bot folder at the next start, which a running
// bot would prevent
ipcMain.handle(
  'update:install',
  guarded(async (_e, { closeBots } = {}) => {
    if (await bridge.anyRunning().catch(() => false)) {
      if (!closeBots) throw new Error('A bot is open: it has to be closed for the update');
      await bridge.closeAll();
    }
    updater.install();
  }),
);
ipcMain.handle('bot:sync', guarded((_e, { verify, closeBots } = {}) => (closeBots ? bridge.closeAll() : Promise.resolve()).then(() => syncBot({ verify }))));

// the title bar follows the page's theme (native minimise / maximise / close buttons)
ipcMain.handle('window:titlebar', (_e, { color, symbolColor }) => {
  try {
    if (win && process.platform !== 'darwin') win.setTitleBarOverlay({ color, symbolColor, height: 44 });
  } catch {
    // native title bar without overlay (some Linux desktops): nothing to recolour
  }
});

// the Windows accent colour (Settings > Personalisation > Colours), for the accent "Couleur de Windows": '#rrggbb', or
// null where the system has none to give (Linux), the page then keeps its default blue
function systemAccent() {
  try {
    const c = systemPreferences.getAccentColor?.(); // 'RRGGBBAA'
    return /^[0-9a-f]{6}/i.test(c ?? '') ? `#${c.slice(0, 6).toLowerCase()}` : null;
  } catch {
    return null;
  }
}
ipcMain.handle('system:accent', () => systemAccent());
// changed in the Windows settings while the GUI is open: the page follows at once
app.whenReady().then(() => {
  if (process.platform === 'win32') systemPreferences.on('accent-color-changed', () => send('system:accent', systemAccent()));
});

// ---------------------------------------------------------------------------------------------------------------------
// window
// ---------------------------------------------------------------------------------------------------------------------
function createWindow() {
  win = new BrowserWindow({
    width: 1320,
    height: 840,
    minWidth: 1000,
    minHeight: 640,
    show: false,
    backgroundColor: '#000000', // the dark theme's background (renderer/styles.css), until the page shows
    title: 'MyBot',
    icon: path.join(__dirname, 'renderer', 'assets', 'MyBot.ico'),
    titleBarStyle: 'hidden',
    titleBarOverlay: process.platform === 'darwin' ? true : { color: '#0a0a0a', symbolColor: '#c8c8c8', height: 44 },
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
      // the window is often behind the emulator: throttled, the counters and the log moved by jumps
      backgroundThrottling: false,
    },
  });
  win.removeMenu();
  win.once('ready-to-show', () => win.show());
  // external links open in the browser, never in the application
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:/.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (e) => e.preventDefault());
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (!win) return;
    if (win.isMinimized()) win.restore();
    win.focus();
  });

  app.whenReady().then(() => {
    settings = new Settings(app.getPath('userData'));
    if (app.isPackaged && !DEMO) {
      // the bot runs from its own folder; the one used before, from GitHub or from the sources, is offered for import
      install = new BotInstall(path.join(process.resourcesPath, 'bot'));
      const { botDir, legacyBotDir } = settings.get();
      if (botDir && path.resolve(botDir) !== path.resolve(install.botDir) && !legacyBotDir) settings.set({ legacyBotDir: botDir });
      settings.set({ botDir: install.botDir });
    } else {
      const dir = detectBotDir();
      if (dir && dir !== settings.get().botDir) settings.set({ botDir: dir });
    }
    updater = new Updater(app, settings.get().updates);
    updater.on('state', (st) => send('update:state', { ...st, sync: botSync }));
    createWindow();
    restartWatchers();
    updater.start();
    if (install) syncBot();
  });

  app.on('window-all-closed', () => {
    tail.stop();
    attackTail.stop();
    clearInterval(pollTimer);
    bridge.dispose();
    app.quit();
  });
}
