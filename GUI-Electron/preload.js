// Seul pont entre la page et le processus principal : la page ne voit que window.mybot.
const { contextBridge, ipcRenderer } = require('electron');

// les actions sur les fichiers repondent { ok, result } ou { ok: false, error } (main.js, guarded) : l'erreur redevient
// une exception avec le message du processus principal, sans le prefixe d'Electron
const act = (channel, arg) =>
  ipcRenderer.invoke(channel, arg).then((res) => {
    if (!res?.ok) throw new Error(res?.error ?? 'Erreur inconnue');
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
  getConfig: (ids) => ipcRenderer.invoke('config:get', ids),
  setConfig: (values) => ipcRenderer.invoke('config:set', values), // { ok, error } : le formulaire garde ses modifications
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
  onLog: listen('log:lines'),
  onAttackLog: listen('atklog:lines'),
  onLogFile: listen('log:file'),
  onState: listen('bot:state'),
});
