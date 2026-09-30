// Processus principal : la fenetre, les reglages de l'interface, et tout ce qui touche au disque et au bot
// (journal, config.ini du profil, lancement et commandes). La page (renderer/) n'y accede que par preload.js.
const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const { Settings } = require('./lib/settings');
const ini = require('./lib/ini');
const { LogTail } = require('./lib/log-tail');
const { BotBridge, botExecutable } = require('./lib/bot');

const DEMO = process.argv.includes('--demo');
const HISTORY = 1500; // lignes de journal gardees pour une page rechargee

let win = null;
let settings = null;
let pollTimer = null;
let lastState = { state: 'off' };
let logFile = '';
const history = [];
const tail = new LogTail();
const bridge = new BotBridge(path.join(__dirname, 'bridge', 'MyBotBridge.ps1'));

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
  const { botDir, profile } = settings.get();
  const profiles = path.join(botDir, 'Profiles');
  const profileDir = path.join(profiles, profile);
  return {
    botDir,
    profiles,
    profileDir,
    config: path.join(profileDir, 'config.ini'),
    logs: path.join(profileDir, 'Logs'),
    multibot: path.join(profiles, 'MultiBot-Profiles.ini'),
  };
}

function listProfiles() {
  const { botDir, profiles, multibot } = paths();
  if (!botDir) return [];
  const found = new Map();
  try {
    for (const entry of fs.readdirSync(profiles, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const hasConfig = fs.existsSync(path.join(profiles, entry.name, 'config.ini'));
      found.set(entry.name.toLowerCase(), { name: entry.name, hasConfig, emulator: '', instance: '', multibot: false });
    }
  } catch {
    // pas encore de dossier Profiles : le bot le cree a son premier demarrage
  }
  // les reglages de MultiBot (une section par profil) donnent l'emulateur et l'instance de chacun
  const data = ini.readAll(multibot);
  for (const [section, keys] of Object.entries(data)) {
    if (section === 'options') continue;
    const name = keys.profile || section;
    const key = name.toLowerCase();
    const item = found.get(key) ?? { name, hasConfig: false };
    found.set(key, { ...item, emulator: keys.emulator ?? '', instance: keys.instance ?? '', multibot: true });
  }
  return [...found.values()].sort((a, b) => a.name.localeCompare(b.name));
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

function restartWatchers() {
  history.length = 0;
  logFile = '';
  tail.stop();
  clearInterval(pollTimer);
  if (DEMO || !settings.get().botDir) return;
  tail.start(paths().logs);
  if (bridge.supported) {
    pollTimer = setInterval(pollState, 2000);
    pollState();
  }
}

let polling = false;
let launchedAt = 0;
async function pollState() {
  if (polling) return;
  polling = true;
  try {
    const { profile, instance } = settings.get();
    lastState = await bridge.state(profile, instance);
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
  if (!isBotDir(dir)) return { ...info(), error: `MyBot.run.exe introuvable dans ${dir}` };
  settings.set({ botDir: dir });
  restartWatchers();
  return info();
});

ipcMain.handle('profiles:list', () => listProfiles());

ipcMain.handle('config:get', (_e, ids) => {
  const { botDir, config } = paths();
  if (!botDir) return { file: '', exists: false, values: {} };
  return { file: config, exists: fs.existsSync(config), values: ini.getValues(config, ids) };
});

ipcMain.handle('config:set', (_e, values) => {
  // le bot reecrit tout config.ini quand il enregistre (a la fermeture notamment) : une modification faite pendant qu'il
  // est ouvert serait perdue
  if (!['off', 'error'].includes(lastState.state)) {
    return { ok: false, error: "Fermez d'abord le bot de ce profil : il reecrit config.ini en quittant." };
  }
  const { config } = paths();
  if (!fs.existsSync(config)) return { ok: false, error: `Pas de config.ini pour ce profil (${config}). Lancez le bot une fois.` };
  ini.setValues(config, values);
  return { ok: true };
});

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

ipcMain.handle('shell:open', (_e, what) => {
  const p = paths();
  const target = { botDir: p.botDir, profile: p.profileDir, logs: p.logs }[what];
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
    clearInterval(pollTimer);
    bridge.dispose();
    app.quit();
  });
}
