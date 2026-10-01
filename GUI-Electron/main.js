// Processus principal : la fenetre, les reglages de l'interface, et tout ce qui touche au disque et au bot
// (journaux, fichiers .ini des profils, strategies, lancement et commandes). La page (renderer/) n'y accede que par
// preload.js.
const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const { Settings } = require('./lib/settings');
const { LogTail, parseAttackLine, ATTACK_LOG_NAME } = require('./lib/log-tail');
const { BotBridge, botExecutable } = require('./lib/bot');
const { ProfileStore } = require('./lib/profile-store');

const DEMO = process.argv.includes('--demo');
const HISTORY = 1500; // lignes de journal gardees pour une page rechargee

let win = null;
let settings = null;
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
// dossiers du bot
// ---------------------------------------------------------------------------------------------------------------------
const isBotDir = (dir) => Boolean(dir) && botExecutable(dir) !== '';

// le dossier choisi, sinon celui qui contient l'interface (GUI-Electron\ pose dans le dossier du bot, ou l'exe portable)
function detectBotDir() {
  const candidates = [
    settings.get().botDir,
    process.env.PORTABLE_EXECUTABLE_DIR,
    process.env.PORTABLE_EXECUTABLE_DIR && path.dirname(process.env.PORTABLE_EXECUTABLE_DIR),
    path.dirname(app.getAppPath()),
  ];
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
// journal et etat du bot
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

// le bot n'a plus de fenetre a lui, ce GUI est son interface : on se declare tant qu'il demarre, puis une fois par bot
// deja lance (interface rouverte pendant qu'il tourne, ou bot lance par MultiBot ou relance par le Watchdog)
async function linkBot(st) {
  if (!st.hwnd) return;
  const starting = st.state === 'noanswer' || st.state === 'starting';
  if (!starting && linkedBotPid === st.pid) return;
  try {
    await bridge.registerGui(st.hwnd, !starting);
    if (!starting) linkedBotPid = st.pid;
  } catch {
    // reessaye au prochain tour
  }
}
async function pollState() {
  if (polling) return;
  polling = true;
  try {
    const { profile, instance } = settings.get();
    lastState = await bridge.state(profile, instance);
    await linkBot(lastState);
    // le bot met un moment a creer sa fenetre : juste apres un lancement, "pas de fenetre" veut dire "demarre encore"
    if (lastState.state !== 'off') launchedAt = 0;
    else if (Date.now() - launchedAt < 90000) lastState = { state: 'starting' };
  } catch (err) {
    lastState = { state: 'error', error: err.message };
  } finally {
    polling = false;
  }
  send('bot:state', lastState);
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
  const res = await dialog.showOpenDialog(win, {
    title: 'Dossier de MyBot (celui qui contient MyBot.run.exe)',
    properties: ['openDirectory'],
    defaultPath: settings.get().botDir || app.getPath('desktop'),
  });
  if (res.canceled || !res.filePaths[0]) return { ...info(), canceled: true };
  const dir = res.filePaths[0];
  if (!isBotDir(dir)) return { ...info(), error: `MyBot.run.exe (ou MyBot.run.au3) introuvable dans ${dir}` };
  settings.set({ botDir: dir });
  restartWatchers();
  return info();
});

// le bot reecrit tous ses .ini quand il enregistre (a la fermeture notamment) : une modification faite pendant qu'il
// est ouvert serait perdue
const CLOSE_FIRST = "Fermez d'abord le bot de ce profil : il reecrit ses reglages en quittant.";
const botOpen = () => !['off', 'error'].includes(lastState.state);

// le bot d'un autre profil que celui pilote : sa fenetre, s'il est ouvert
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
    if (await otherBotOpen(from)) throw new Error(`Fermez d'abord le bot du profil ${from}`);
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
    if (await otherBotOpen(name)) throw new Error(`Fermez d'abord le bot du profil ${name}`);
    store.deleteProfile(name);
    if (name.toLowerCase() === settings.get().profile.toLowerCase()) {
      const next = store.listProfiles().find((p) => p.hasConfig) ?? store.listProfiles()[0];
      settings.set({ profile: next?.name ?? 'MyVillage' });
      restartWatchers();
    }
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
  if (launchedAt && Date.now() - launchedAt < 90000) throw new Error('Le bot est deja en train de demarrer');
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
  return `Dossier introuvable : ${target}`;
});

// la couleur de la barre de titre suit le theme de la page (boutons natifs reduire / agrandir / fermer)
ipcMain.handle('window:titlebar', (_e, { color, symbolColor }) => {
  try {
    if (win && process.platform !== 'darwin') win.setTitleBarOverlay({ color, symbolColor, height: 44 });
  } catch {
    // barre de titre native sans overlay (certains bureaux Linux) : rien a recolorer
  }
});

// ---------------------------------------------------------------------------------------------------------------------
// fenetre
// ---------------------------------------------------------------------------------------------------------------------
function createWindow() {
  win = new BrowserWindow({
    width: 1320,
    height: 840,
    minWidth: 1000,
    minHeight: 640,
    show: false,
    backgroundColor: '#0a0f1c',
    title: 'MyBot GUI',
    icon: path.join(__dirname, 'renderer', 'assets', 'MyBot.ico'),
    titleBarStyle: 'hidden',
    titleBarOverlay: process.platform === 'darwin' ? true : { color: '#0a0f1c', symbolColor: '#cbd5e1', height: 44 },
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
    },
  });
  win.removeMenu();
  win.once('ready-to-show', () => win.show());
  // liens externes dans le navigateur, jamais dans l'appli
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
    const dir = detectBotDir();
    if (dir && dir !== settings.get().botDir) settings.set({ botDir: dir });
    createWindow();
    restartWatchers();
  });

  app.on('window-all-closed', () => {
    tail.stop();
    attackTail.stop();
    clearInterval(pollTimer);
    bridge.dispose();
    app.quit();
  });
}
