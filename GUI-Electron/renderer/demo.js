// Mode demo : un faux bot qui repond comme window.mybot. Sert a voir et retoucher le GUI sans le bot ni Windows
// (npm run demo, ou index.html ouvert dans un navigateur).
(function () {
  const LS_KEY = 'mybot-gui-demo';
  const store = {
    load() {
      try {
        return JSON.parse(localStorage.getItem(LS_KEY)) ?? {};
      } catch {
        return {};
      }
    },
    save(data) {
      try {
        localStorage.setItem(LS_KEY, JSON.stringify(data));
      } catch {
        // stockage indisponible : la demo garde ses valeurs en memoire
      }
    },
  };

  const pad = (n) => String(n).padStart(2, '0');
  const now = () => {
    const d = new Date();
    return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
  };
  const fmt = (n) => String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  const rnd = (a, b) => a + Math.random() * (b - a);
  const pick = (list) => list[Math.floor(Math.random() * list.length)];

  class DemoBackend {
    constructor(realInfo) {
      this.realInfo = realInfo ?? null;
      const saved = store.load();
      this.settings = {
        botDir: 'C:\\Users\\Vous\\Desktop\\MyBot v12',
        profile: 'MyVillage',
        emulator: 'BlueStacks5',
        instance: 'Pie64',
        switches: { hideandroid: true, nowatchdog: false, debug: false, dpiaware: false, autostart: false },
        theme: 'dark',
        accent: '#3b82f6',
        ...(realInfo?.settings ?? {}),
        ...saved.settings,
      };
      this.config = saved.config ?? {};
      this.profiles = saved.profiles ?? [
        { name: 'MyVillage', hasConfig: true, emulator: 'BlueStacks5', instance: 'Pie64', multibot: true },
        { name: 'Farm2', hasConfig: true, emulator: 'BlueStacks5', instance: 'Pie64_1', multibot: true },
        { name: 'Rush TH12', hasConfig: false, emulator: '', instance: '', multibot: false },
      ];
      this.strategies = saved.strategies ?? {
        'Farm Barch': { info: 'Barbares + archères, bases mortes seulement.\nLigue Cristal.', values: {} },
        'Dragons TH12': { info: 'Dragons + sorts de rage, attaque scriptée.', values: {} },
      };
      this.botState = 'off';
      this.listeners = { log: [], file: [], state: [], attack: [] };
      this.history = [];
      this.attackHistory = [];
      this.loot = { gold: 4_512_330, elixir: 3_998_120, dark: 98_450, gems: 1_245 };
      this.script = [];
      this.timer = setInterval(() => this.tick(), 650);
    }

    persist() {
      store.save({ settings: this.settings, config: this.config, profiles: this.profiles, strategies: this.strategies });
    }

    info() {
      return Promise.resolve({
        version: this.realInfo?.version ?? '0.1.0',
        platform: this.realInfo?.platform ?? 'web',
        demo: true,
        control: true,
        botFound: true,
        settings: structuredClone(this.settings),
      });
    }

    async setSettings(patch) {
      this.settings = { ...this.settings, ...patch, switches: { ...this.settings.switches, ...patch.switches } };
      this.persist();
      return this.info();
    }

    pickBotDir() {
      return this.info();
    }

    listProfiles() {
      return Promise.resolve(structuredClone(this.profiles));
    }

    findProfile(name) {
      return this.profiles.find((p) => p.name.toLowerCase() === String(name).toLowerCase());
    }

    async createProfile(name, copyFrom) {
      const clean = String(name ?? '').replace(/[\\/:*?"<>|]/g, '_').trim();
      if (!clean) throw new Error('Nom invalide');
      if (this.findProfile(clean)) throw new Error(`Le profil ${clean} existe deja`);
      this.profiles.push({ name: clean, hasConfig: Boolean(copyFrom), emulator: '', instance: '', multibot: false });
      this.persist();
      return clean;
    }

    async renameProfile(from, to) {
      const p = this.findProfile(from);
      if (!p) throw new Error(`Profil introuvable : ${from}`);
      const name = String(to).trim();
      if (this.config[p.name]) {
        this.config[name] = this.config[p.name];
        delete this.config[p.name];
      }
      if (p.name.toLowerCase() === this.settings.profile.toLowerCase()) this.settings.profile = name;
      p.name = name;
      this.persist();
      return name;
    }

    async deleteProfile(name) {
      this.profiles = this.profiles.filter((p) => p !== this.findProfile(name));
      delete this.config[name];
      if (name.toLowerCase() === this.settings.profile.toLowerCase()) {
        this.settings.profile = (this.profiles.find((p) => p.hasConfig) ?? this.profiles[0])?.name ?? 'MyVillage';
      }
      this.persist();
    }

    // les valeurs de la demo sont celles du profil actif ; les cles "fichier:section/cle" sont gardees telles quelles
    getConfig(ids) {
      const values = {};
      const cfg = this.config[this.settings.profile] ?? {};
      for (const id of ids) values[id] = cfg[id] ?? null;
      return Promise.resolve({ values, files: { config: true } });
    }

    setConfig(values) {
      if (this.botState !== 'off') {
        return Promise.resolve({ ok: false, error: "Fermez d'abord le bot de ce profil : il réécrit ses fichiers en quittant." });
      }
      this.config[this.settings.profile] = { ...(this.config[this.settings.profile] ?? {}), ...values };
      this.persist();
      return Promise.resolve({ ok: true });
    }

    listStrategies() {
      return Promise.resolve(Object.entries(this.strategies).map(([name, s]) => ({ name, info: s.info })).sort((a, b) => a.name.localeCompare(b.name)));
    }

    async loadStrategy(name) {
      const s = this.strategies[name];
      if (!s) throw new Error(`Strategie introuvable : ${name}`);
      const res = await this.setConfig(s.values);
      if (!res.ok) throw new Error(res.error);
      return Object.keys(s.values).length;
    }

    async saveStrategy(name, notes) {
      let base = String(name).trim() || 'Stratégie';
      let final = base;
      for (let i = 2; this.strategies[final]; i++) final = `${base} (${i})`;
      const cfg = this.config[this.settings.profile] ?? {};
      const values = Object.fromEntries(Object.entries(cfg).filter(([id]) => /^(search|attack|troop|spells|endbattle|collectors|droporder|smartzap|planned)\//i.test(id)));
      this.strategies[final] = { info: notes ?? '', values };
      this.persist();
      return final;
    }

    async deleteStrategy(name) {
      delete this.strategies[name];
      this.persist();
    }

    list(kind) {
      const lists = {
        scripts: ['Barch four fingers', 'Dragons 2 sides', 'Giant Healers', 'LavaLoon', 'Mass Witch', 'Queen Walk Hybrid'],
        languages: ['Chinese_S', 'English', 'French', 'German', 'Italian', 'Portuguese', 'Russian', 'Spanish'],
      };
      return Promise.resolve(lists[kind] ?? []);
    }

    async launch() {
      if (this.botState !== 'off') throw new Error(`Le bot du profil ${this.settings.profile} est déjà ouvert`);
      this.setState('starting');
      this.emitFile(`${new Date().toISOString().slice(0, 10)}_${now().replace(/:/g, '.')}.log`);
      this.queue([
        ['info', `MyBot v12.0.0 BETA - profil ${this.settings.profile}`],
        ['debug', `Android: ${this.settings.emulator}, instance ${this.settings.instance}`],
        ['info', 'Connexion à ADB 127.0.0.1:5555'],
        ['success', 'Android prêt, Clash of Clans au premier plan'],
      ]);
      setTimeout(() => {
        this.setState('idle');
        this.log('info', 'Bot prêt. Appuyez sur Démarrer.');
        if (this.settings.switches.autostart) this.command('start');
      }, 3200);
      return { pid: 4242 };
    }

    async command(name) {
      const s = this.botState;
      if (name === 'start' && s === 'idle') {
        this.setState('running');
        this.log('success', '===== Démarrage du run =====');
      } else if (name === 'stop' && (s === 'running' || s === 'paused')) {
        this.script = [];
        this.setState('idle');
        this.log('warn', 'Run arrêté par l’utilisateur');
      } else if (name === 'pause' && s === 'running') {
        this.setState('paused');
        this.log('warn', 'Bot en pause');
      } else if (name === 'resume' && s === 'paused') {
        this.setState('running');
        this.log('info', 'Reprise du run');
      } else if (name === 'close' && s !== 'off') {
        this.script = [];
        this.log('info', 'Enregistrement de la configuration, fermeture du bot');
        this.setState('starting');
        setTimeout(() => this.setState('off'), 1200);
      }
      return { state: this.botState };
    }

    state() {
      return Promise.resolve({ state: this.botState });
    }

    logHistory() {
      return Promise.resolve(this.history.slice());
    }

    attackLogHistory() {
      return Promise.resolve(this.attackHistory.slice());
    }

    openPath() {
      return Promise.resolve('');
    }

    setTitleBar() {
      return Promise.resolve();
    }

    updateState() {
      return Promise.resolve({ phase: 'available', installed: true, current: this.realInfo?.version ?? '0.1.0', version: '12.1.0', notes: 'Demo:\n• Faster screen capture\n• New attack options', checkedAt: Date.parse('2026-10-01T12:00:00Z'), releasesPage: 'https://github.com/augustinktzz/mybotrun_v10/releases', options: { autoCheck: true, beta: false }, sync: { phase: 'idle' } });
    }
    checkUpdate() {
      return Promise.resolve({ ok: true, result: null });
    }
    downloadUpdate() {
      return Promise.resolve({ ok: true, result: null });
    }
    installUpdate() {
      return Promise.resolve({ ok: true, result: null });
    }
    setUpdateOptions() {
      return Promise.resolve({ ok: true, result: null });
    }
    syncBot() {
      return Promise.resolve({ ok: true, result: { phase: 'idle' } });
    }
    importProfiles() {
      return Promise.resolve({ ok: true, result: { profiles: [], files: 0, skipped: [] } });
    }
    dismissImport() {
      return Promise.resolve({ ok: true, result: this.info ? this.info() : {} });
    }
    repairPlan() {
      return Promise.resolve([]);
    }
    repairProfile() {
      return Promise.resolve({ ok: true, result: { count: 0, backups: [] } });
    }
    onUpdate() {
      return () => {};
    }
    onBotSync() {
      return () => {};
    }
    onInfo() {
      return () => {};
    }

    onLog(cb) {
      this.listeners.log.push(cb);
      return () => {};
    }

    onAttackLog(cb) {
      this.listeners.attack.push(cb);
      return () => {};
    }

    onLogFile(cb) {
      this.listeners.file.push(cb);
      return () => {};
    }

    onState(cb) {
      this.listeners.state.push(cb);
      cb({ state: this.botState });
      return () => {};
    }

    // ------------------------------------------------------------------ simulation
    setState(state) {
      this.botState = state;
      for (const cb of this.listeners.state) cb({ state });
    }

    emitFile(name) {
      for (const cb of this.listeners.file) cb(name);
    }

    log(level, text) {
      const line = { time: now(), level, text };
      this.history.push(line);
      if (this.history.length > 1500) this.history.shift();
      for (const cb of this.listeners.log) cb([line]);
    }

    // une ligne du tableau des attaques (AttackReport.au3), comme dans AttackLog-AAAA-MM.log
    attackLog(text) {
      const d = new Date();
      const atk = { time: `${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${now().slice(0, 5)}`, level: 'info', text };
      this.attackHistory.push(atk);
      for (const cb of this.listeners.attack) cb([atk]);
    }

    queue(lines) {
      this.script.push(...lines);
    }

    tick() {
      if (this.script.length) {
        const [level, text] = this.script.shift();
        if (level === 'atk') this.attackLog(text);
        else this.log(level, text);
        return;
      }
      if (this.botState === 'running') this.queue(this.cycle());
    }

    // un tour de boucle du bot : rapport du village, entretien, recherche, attaque
    cycle() {
      const l = this.loot;
      const lines = [
        ['info', 'Village Report'],
        ['success', ` [G]: ${fmt(l.gold)} [E]: ${fmt(l.elixir)} [D]: ${fmt(l.dark)} [GEM]: ${fmt(l.gems)}`],
        ['success', ' [League]: Crystal 2'],
        ['info', 'Collecting Resources'],
        ['success', `Collected ${fmt(rnd(8, 40) * 1000)} gold from the mines`],
      ];
      if (Math.random() < 0.4) lines.push(['success', `Donated 2 x ${pick(['Balloon', 'Archer', 'Wizard', 'Lightning Spell'])} to ${pick(['Kiko', 'Nexus', 'Aurore'])}`]);
      if (Math.random() < 0.3) lines.push(['warn', 'Wall upgrade skipped: not enough gold once the minimum is kept']);
      lines.push(['info', 'Checking Army Camp'], ['info', 'Army Camp: 280/280, spells 11/11'], ['info', '============== Searching For Dead Base ===============']);
      const tries = Math.floor(rnd(2, 7));
      for (let i = 1; i <= tries; i++) {
        lines.push(['info', `${String(i).padStart(3)}> [G]:${fmt(rnd(120, 480) * 1000).padStart(8)} [E]:${fmt(rnd(120, 480) * 1000).padStart(8)} [D]:${fmt(rnd(0, 4) * 1000).padStart(6)} [L]:12 [TH]:${Math.floor(rnd(11, 15))}`]);
      }
      if (Math.random() < 0.15) lines.push(['error', 'Image not found: Next button, retrying']);
      const gain = { gold: rnd(180, 520) * 1000, elixir: rnd(160, 500) * 1000, dark: rnd(800, 3500) };
      lines.push(
        ['success', 'Dead Base Found!'],
        ['info', 'Attacking with Standard, 4 sides'],
        ['debug', 'Drop order: Giants, Wall Breakers, Archers, Goblins, Heroes'],
        ['success', `Battle ended, 2 stars, ${Math.floor(rnd(55, 92))}% destruction`],
        ['info', 'Returning Home'],
      );
      const n = this.attackHistory.length + 1;
      const pct = Math.floor(rnd(55, 92));
      const col = (v, w) => String(v).padStart(w);
      lines.push(['atk', `|${col(n % 100, 2)}|${now().slice(0, 5)}|${col(22, 6)}|${col(tries, 3)}|DB|${col(fmt(gain.gold), 7)}|${col(fmt(gain.elixir), 7)}|${col(fmt(gain.dark), 5)}|${col(Math.floor(rnd(-5, 12)), 3)}|${col(pct >= 50 ? 2 : 1, 2)}|${col(pct, 3)}|${col(0, 6)}|${col(0, 4)}|${col(22, 2)}|`]);
      l.gold += gain.gold;
      l.elixir += gain.elixir;
      l.dark += gain.dark;
      if (Math.random() < 0.2) l.gems += 1;
      return lines;
    }
  }
  window.DemoBackend = DemoBackend;
})();
