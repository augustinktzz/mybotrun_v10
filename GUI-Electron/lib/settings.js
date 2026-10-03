// Settings of the interface (not of the bot): %APPDATA%\MyBot GUI\settings.json
const fs = require('node:fs');
const path = require('node:path');

// on Linux the bot drives an Android that already runs, reachable over ADB: the bot's "Generic" emulator
const ON_WINDOWS = process.platform === 'win32';

const DEFAULTS = {
  botDir: '', // folder that holds MyBot.run.exe
  legacyBotDir: '', // installed application: the bot folder used before it, offered for importing its profiles
  profile: 'MyVillage',
  emulator: ON_WINDOWS ? 'BlueStacks5' : 'Generic',
  instance: ON_WINDOWS ? 'Pie64' : 'Android',
  switches: { hideandroid: false, nowatchdog: false, debug: false, dpiaware: false, autostart: false },
  updates: { autoCheck: true, beta: false },
  theme: 'dark', // dark | light (older versions also wrote 'system': read as followSystemTheme)
  followSystemTheme: false, // follow the Windows theme (the dark / light choice is then greyed out)
  accent: '#3b82f6', // a colour, 'system' (the Windows accent colour) or 'mono' (black and white)
  language: 'fr', // language of the interface: fr | en (renderer/i18n.js); the bot's own language is in its config.ini
};

// the settings made of several values are merged rather than replaced
const NESTED = ['switches', 'updates'];

function merge(base, patch) {
  const out = { ...base, ...patch };
  for (const key of NESTED) out[key] = { ...base[key], ...patch?.[key] };
  return out;
}

class Settings {
  constructor(dir) {
    this.file = path.join(dir, 'settings.json');
    this.data = structuredClone(DEFAULTS);
    try {
      this.data = merge(this.data, JSON.parse(fs.readFileSync(this.file, 'utf8')));
    } catch {
      // first start, or an unreadable file: the defaults
    }
  }

  get() {
    return structuredClone(this.data);
  }

  set(patch) {
    this.data = merge(this.data, patch);
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    fs.writeFileSync(this.file, JSON.stringify(this.data, null, 2));
    return this.get();
  }
}

module.exports = { Settings, DEFAULTS };
