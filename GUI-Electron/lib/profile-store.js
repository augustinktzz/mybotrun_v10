// Les fichiers du bot que le GUI lit et ecrit : reglages des profils, strategies, profils eux-memes, listes.
//
// Un champ du GUI est "fichier:section/cle" (fichier "config" par defaut) :
//   config     Profiles\<profil>\config.ini      reglages du profil          (UTF-16, _Ini_Save)
//   building   Profiles\<profil>\building.ini    labo, batiments localises  (UTF-16, SaveBuildingConfig)
//   clangames  Profiles\<profil>\clangames.ini   jeux de clan               (UTF-16, SaveClanGamesConfig)
//   cgrewards  Profiles\<profil>\ClanGamesRewards.ini  priorite des recompenses des jeux de clan (IniWrite)
//   profile    Profiles\profile.ini              reglages communs a tous les bots (IniWrite)
//   switch1-8  Profiles\SwitchAccount.0N.ini     groupes de changement de compte (IniWrite)
const fs = require('node:fs');
const path = require('node:path');
const ini = require('./ini');
const { appDataDir } = require('./platform');

const PROFILE_FILES = { config: 'config.ini', building: 'building.ini', clangames: 'clangames.ini' };
const PROFILE_ANSI_FILES = { cgrewards: 'ClanGamesRewards.ini' };
// les sections que le bot copie dans une strategie (_Ini_Save avec $g_sProfileSecondaryOutputFileName)
const STRATEGY_SECTIONS = ['search', 'attack', 'troop', 'spells', 'endbattle', 'collectors', 'droporder', 'smartzap', 'planned'];

function cleanName(name) {
  const clean = String(name ?? '')
    .replace(/[\\/:*?"<>|]/g, '_')
    .trim();
  if (!clean || clean === '.' || clean === '..') throw new Error('Nom invalide');
  return clean;
}

function splitId(id) {
  const m = /^(?:([a-z]+\d?):)?(.+)$/.exec(id);
  return { alias: m[1] || 'config', key: m[2] };
}

class ProfileStore {
  constructor(getSettings) {
    this.getSettings = getSettings;
  }

  get botDir() {
    return this.getSettings().botDir;
  }

  get profilesDir() {
    return path.join(this.botDir, 'Profiles');
  }

  profileDir(name = this.getSettings().profile) {
    return path.join(this.profilesDir, name);
  }

  // dossier "prive" du bot (shared_prefs...) : %APPDATA%\MyBot.run-Profiles\<profil>, renomme et supprime avec le profil.
  // Sous Linux, %APPDATA% est celui de l'utilisateur Wine (lib/platform.js).
  privateDir(name) {
    const appData = appDataDir();
    return appData ? path.join(appData, 'MyBot.run-Profiles', name) : '';
  }

  fileFor(alias) {
    if (PROFILE_FILES[alias]) return path.join(this.profileDir(), PROFILE_FILES[alias]);
    if (PROFILE_ANSI_FILES[alias]) return path.join(this.profileDir(), PROFILE_ANSI_FILES[alias]);
    if (alias === 'profile') return path.join(this.profilesDir, 'profile.ini');
    const sw = /^switch([1-8])$/.exec(alias);
    if (sw) return path.join(this.profilesDir, `SwitchAccount.0${sw[1]}.ini`);
    throw new Error(`Fichier inconnu : ${alias}`);
  }

  // ------------------------------------------------------------------ reglages
  getValues(ids) {
    if (!this.botDir) return { values: {}, files: {} };
    const byFile = new Map();
    for (const id of ids) {
      const { alias, key } = splitId(id);
      if (!byFile.has(alias)) byFile.set(alias, []);
      byFile.get(alias).push([id, key]);
    }
    const values = {};
    const files = {};
    for (const [alias, pairs] of byFile) {
      const file = this.fileFor(alias);
      files[alias] = fs.existsSync(file);
      const got = ini.getValues(file, pairs.map(([, key]) => key));
      for (const [id, key] of pairs) values[id] = got[key];
    }
    return { values, files };
  }

  setValues(values) {
    const byFile = new Map();
    for (const [id, value] of Object.entries(values)) {
      const { alias, key } = splitId(id);
      if (!byFile.has(alias)) byFile.set(alias, {});
      byFile.get(alias)[key] = value;
    }
    const config = this.fileFor('config');
    if (byFile.has('config') && !fs.existsSync(config)) {
      throw new Error(`Pas de config.ini pour ce profil (${config}). Lancez le bot une fois avec ce profil.`);
    }
    for (const [alias, vals] of byFile) {
      const file = this.fileFor(alias);
      fs.mkdirSync(path.dirname(file), { recursive: true });
      ini.setValues(file, vals, PROFILE_FILES[alias] ? 'utf16le' : 'latin1');
    }
  }

  // ------------------------------------------------------------------ profils
  listProfiles() {
    if (!this.botDir) return [];
    const found = new Map();
    try {
      for (const entry of fs.readdirSync(this.profilesDir, { withFileTypes: true })) {
        if (!entry.isDirectory()) continue;
        const hasConfig = fs.existsSync(path.join(this.profilesDir, entry.name, 'config.ini'));
        found.set(entry.name.toLowerCase(), { name: entry.name, hasConfig, emulator: '', instance: '', multibot: false });
      }
    } catch {
      // pas encore de dossier Profiles : le bot le cree a son premier demarrage
    }
    // les reglages de MultiBot (une section par profil) donnent l'emulateur et l'instance de chacun
    const data = ini.readAll(path.join(this.profilesDir, 'MultiBot-Profiles.ini'));
    for (const [section, keys] of Object.entries(data)) {
      if (section === 'options') continue;
      const name = keys.profile || section;
      const key = name.toLowerCase();
      const item = found.get(key) ?? { name, hasConfig: false };
      found.set(key, { ...item, emulator: keys.emulator ?? '', instance: keys.instance ?? '', multibot: true });
    }
    return [...found.values()].sort((a, b) => a.name.localeCompare(b.name));
  }

  // comme "Ajouter" dans Bot > Profils : le nouveau profil part des reglages du profil copie
  createProfile(name, copyFrom) {
    const clean = cleanName(name);
    const dir = this.profileDir(clean);
    if (fs.existsSync(dir)) throw new Error(`Le profil ${clean} existe deja`);
    fs.mkdirSync(path.join(dir, 'Logs'), { recursive: true });
    if (copyFrom) {
      for (const file of Object.values(PROFILE_FILES)) {
        const src = path.join(this.profileDir(copyFrom), file);
        if (fs.existsSync(src)) fs.copyFileSync(src, path.join(dir, file));
      }
    }
    return clean;
  }

  renameProfile(from, to) {
    const clean = cleanName(to);
    const src = this.profileDir(from);
    const dst = this.profileDir(clean);
    if (!fs.existsSync(src)) throw new Error(`Profil introuvable : ${from}`);
    if (fs.existsSync(dst) && src.toLowerCase() !== dst.toLowerCase()) throw new Error(`Le profil ${clean} existe deja`);
    fs.renameSync(src, dst);
    const priv = this.privateDir(from);
    if (priv && fs.existsSync(priv)) fs.renameSync(priv, this.privateDir(clean));
    return clean;
  }

  deleteProfile(name) {
    const dir = this.profileDir(cleanName(name));
    if (!fs.existsSync(dir)) throw new Error(`Profil introuvable : ${name}`);
    fs.rmSync(dir, { recursive: true, force: true });
    const priv = this.privateDir(name);
    if (priv && fs.existsSync(priv)) fs.rmSync(priv, { recursive: true, force: true });
  }

  // ------------------------------------------------------------------ strategies (Attack Plan > Strategies)
  get strategiesDir() {
    return path.join(this.botDir, 'Strategies');
  }

  listStrategies() {
    if (!this.botDir || !fs.existsSync(this.strategiesDir)) return [];
    return fs
      .readdirSync(this.strategiesDir)
      .filter((f) => f.toLowerCase().endsWith('.ini'))
      .map((f) => {
        const data = ini.readAll(path.join(this.strategiesDir, f));
        return { name: f.slice(0, -4), info: String(data.preset?.info ?? '').replace(/\\n/g, '\n') };
      })
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  // comme PresetLoadConf : les cles de la strategie remplacent celles du profil
  loadStrategy(name) {
    const file = path.join(this.strategiesDir, `${cleanName(name)}.ini`);
    if (!fs.existsSync(file)) throw new Error(`Strategie introuvable : ${name}`);
    const values = {};
    for (const { name: section, entries } of ini.readSections(file)) {
      if (section.toLowerCase() === 'preset') continue;
      for (const [key, value] of entries) values[`config:${section}/${key}`] = value;
    }
    this.setValues(values);
    return Object.keys(values).length;
  }

  // comme PresetSaveConf : un fichier .ini avec les notes et les sections d'armee, de recherche et d'attaque
  saveStrategy(name, notes) {
    let base = cleanName(String(name).replace(/\.ini$/i, ''));
    fs.mkdirSync(this.strategiesDir, { recursive: true });
    let file = path.join(this.strategiesDir, `${base}.ini`);
    for (let i = 2; fs.existsSync(file); i++) file = path.join(this.strategiesDir, `${base} (${i}).ini`);
    const config = this.fileFor('config');
    if (!fs.existsSync(config)) throw new Error("Ce profil n'a pas encore de config.ini");
    const sections = ini.readSections(config).filter((s) => STRATEGY_SECTIONS.includes(s.name.toLowerCase()));
    ini.writeSections(file, [{ name: 'preset', entries: [['info', String(notes ?? '').replace(/\r?\n/g, '\\n')]] }, ...sections]);
    return path.basename(file, '.ini');
  }

  deleteStrategy(name) {
    const file = path.join(this.strategiesDir, `${cleanName(name)}.ini`);
    if (fs.existsSync(file)) fs.rmSync(file);
  }

  // ------------------------------------------------------------------ listes
  list(kind) {
    if (!this.botDir) return [];
    const dirs = { scripts: ['CSV', 'Attack'], languages: ['Languages'] };
    const exts = { scripts: '.csv', languages: '.ini' };
    const dir = path.join(this.botDir, ...(dirs[kind] ?? []));
    if (!dirs[kind] || !fs.existsSync(dir)) return [];
    return fs
      .readdirSync(dir)
      .filter((f) => f.toLowerCase().endsWith(exts[kind]))
      .map((f) => f.slice(0, -exts[kind].length))
      .sort((a, b) => a.localeCompare(b));
  }
}

module.exports = { ProfileStore, splitId, cleanName, STRATEGY_SECTIONS };
