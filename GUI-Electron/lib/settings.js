// Reglages de l'interface (pas ceux du bot) : %APPDATA%\MyBot GUI\settings.json
const fs = require('node:fs');
const path = require('node:path');

// sous Linux le bot pilote un Android deja lance, joignable par ADB : l'emulateur "Generic" du bot
const ON_WINDOWS = process.platform === 'win32';

const DEFAULTS = {
  botDir: '', // dossier qui contient MyBot.run.exe
  profile: 'MyVillage',
  emulator: ON_WINDOWS ? 'BlueStacks5' : 'Generic',
  instance: ON_WINDOWS ? 'Pie64' : 'Android',
  switches: { hideandroid: false, nowatchdog: false, debug: false, dpiaware: false, autostart: false },
  theme: 'dark', // dark | light | system
  accent: '#3b82f6',
};

class Settings {
  constructor(dir) {
    this.file = path.join(dir, 'settings.json');
    this.data = structuredClone(DEFAULTS);
    try {
      const saved = JSON.parse(fs.readFileSync(this.file, 'utf8'));
      this.data = { ...this.data, ...saved, switches: { ...DEFAULTS.switches, ...saved.switches } };
    } catch {
      // premier lancement ou fichier illisible : valeurs par defaut
    }
  }

  get() {
    return structuredClone(this.data);
  }

  set(patch) {
    this.data = { ...this.data, ...patch, switches: { ...this.data.switches, ...patch.switches } };
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    fs.writeFileSync(this.file, JSON.stringify(this.data, null, 2));
    return this.get();
  }
}

module.exports = { Settings, DEFAULTS };
