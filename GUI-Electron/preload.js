// Seul pont entre la page et le processus principal : la page ne voit que window.mybot.
const { contextBridge, ipcRenderer } = require('electron');

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
  getConfig: (ids) => ipcRenderer.invoke('config:get', ids),
  setConfig: (values) => ipcRenderer.invoke('config:set', values),
  launch: () => ipcRenderer.invoke('bot:launch'),
  command: (name) => ipcRenderer.invoke('bot:command', name),
  state: () => ipcRenderer.invoke('bot:state'),
  logHistory: () => ipcRenderer.invoke('log:history'),
  openPath: (what) => ipcRenderer.invoke('shell:open', what),
  setTitleBar: (colors) => ipcRenderer.invoke('window:titlebar', colors),
  onLog: listen('log:lines'),
  onLogFile: listen('log:file'),
  onState: listen('bot:state'),
});
