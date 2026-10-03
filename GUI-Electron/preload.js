// The only bridge between the page and the main process: the page sees nothing but window.mybot.
const { contextBridge, ipcRenderer } = require('electron');

// file actions answer { ok, result } or { ok: false, error } (main.js, guarded): the error becomes an exception again,
// with the main process's message and without Electron's prefix
const act = (channel, arg) =>
  ipcRenderer.invoke(channel, arg).then((res) => {
    if (!res?.ok) throw new Error(res?.error ?? 'Unknown error');
    return res.result;
  });

const listen = (channel) => (callback) => {
  const handler = (_e, payload) => callback(payload);
  ipcRenderer.on(channel, handler);
  return () => ipcRenderer.removeListener(channel, handler);
};

contextBridge.exposeInMainWorld('mybot', {
  info: () => ipcRenderer.invoke('app:info'),
  setSettings: (patch) => ipcRenderer.invoke('settings:set', patch),
  pickBotDir: () => ipcRenderer.invoke('dialog:botDir'),
  listProfiles: () => ipcRenderer.invoke('profiles:list'),
  createProfile: (name, copy) => act('profiles:create', { name, copy }),
  renameProfile: (from, to) => act('profiles:rename', { from, to }),
  deleteProfile: (name) => act('profiles:delete', name),
  importProfiles: (dir) => act('profiles:import', dir),
  dismissImport: () => act('profiles:dismissImport'),
  repairPlan: (name) => ipcRenderer.invoke('profiles:repairPlan', name),
  repairProfile: (name) => act('profiles:repair', name),
  getConfig: (ids) => ipcRenderer.invoke('config:get', ids),
  setConfig: (values) => ipcRenderer.invoke('config:set', values), // { ok, error }: the form keeps its changes
  listStrategies: () => ipcRenderer.invoke('strategies:list'),
  loadStrategy: (name) => act('strategies:load', name),
  saveStrategy: (name, notes) => act('strategies:save', { name, notes }),
  deleteStrategy: (name) => act('strategies:delete', name),
  list: (kind) => ipcRenderer.invoke('lists:get', kind),
  launch: () => ipcRenderer.invoke('bot:launch'),
  command: (name) => ipcRenderer.invoke('bot:command', name),
  state: () => ipcRenderer.invoke('bot:state'),
  logHistory: () => ipcRenderer.invoke('log:history'),
  attackLogHistory: () => ipcRenderer.invoke('atklog:history'),
  openPath: (what) => ipcRenderer.invoke('shell:open', what),
  setTitleBar: (colors) => ipcRenderer.invoke('window:titlebar', colors),
  updateState: () => ipcRenderer.invoke('update:state'),
  checkUpdate: () => act('update:check'),
  downloadUpdate: () => act('update:download'),
  installUpdate: (closeBots) => act('update:install', { closeBots }),
  setUpdateOptions: (patch) => act('update:options', patch),
  syncBot: (options) => act('bot:sync', options),
  onLog: listen('log:lines'),
  onAttackLog: listen('atklog:lines'),
  onLogFile: listen('log:file'),
  onState: listen('bot:state'),
  onInfo: listen('info:changed'),
  onUpdate: listen('update:state'),
  onBotSync: listen('bot:sync'),
});
