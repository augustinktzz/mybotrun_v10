'use strict';
// La page : navigation, tableau de bord, journal, pages de reglages (form-engine.js + forms/*.js), strategies, profils
// et reglages du GUI.
// Tout passe par `backend` : window.mybot (preload.js) dans Electron, ou DemoBackend (demo.js) en demo / navigateur.

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const icon = (id) => `<svg class="icon"><use href="#${id}"/></svg>`;
let nf = new Intl.NumberFormat('fr-FR'); // suivent la langue de l'interface (applyLanguage)
let nfCompact = new Intl.NumberFormat('fr-FR', { notation: 'compact', maximumFractionDigits: 1 });

let backend = window.mybot ?? null;

const STATE_LABEL = {
  off: 'Bot fermé',
  starting: 'Démarrage…',
  noanswer: 'Occupé…',
  idle: 'Prêt',
  running: 'En cours',
  paused: 'En pause',
  error: 'Pont indisponible',
  denied: 'Accès refusé',
  unsupported: 'Pilotage indisponible',
};

const SWITCHES = [
  ['hideandroid', "Cacher l'émulateur", "La fenêtre de l'émulateur est sortie de l'écran pendant le run (invisible). Pour seulement pouvoir mettre d'autres fenêtres devant, utilisez plutôt le mode arrière-plan (page Bot)"],
  ['autostart', 'Démarrage automatique', 'Le run démarre dès que le bot est prêt'],
  ['nowatchdog', 'Sans Watchdog', "Un bot planté n'est pas relancé"],
  ['debug', 'Journal debug', 'Écrit le journal détaillé'],
  ['dpiaware', 'DPI aware', 'Pour un zoom Windows au-dessus de 100 %'],
];
const SWITCH_ORDER = ['debug', 'dpiaware', 'hideandroid', 'nowatchdog', 'autostart'];

// 'system' = la couleur d'accent de Windows (main.js, suivie en direct ; bleu par defaut sans elle)
// 'mono' = noir et blanc : ses couleurs dependent du theme (styles.css, :root[data-accent='mono'])
const DEFAULT_ACCENT = '#3b82f6';
const ACCENTS = ['system', DEFAULT_ACCENT, '#8b5cf6', '#10b981', '#f59e0b', '#f43f5e', '#06b6d4', 'mono'];
const ACCENT_TITLES = { system: 'Couleur de Windows', mono: 'Noir et blanc' };

const RESOURCES = [
  { key: 'gold', label: 'Or', icon: 'i-coins', color: 'var(--gold)' },
  { key: 'elixir', label: 'Élixir', icon: 'i-drop', color: 'var(--elixir)' },
  { key: 'dark', label: 'Élixir noir', icon: 'i-drop', color: 'var(--dark)' },
  { key: 'gems', label: 'Gemmes', icon: 'i-gem', color: 'var(--gems)' },
];

const app = {
  info: null,
  settings: {},
  bot: { state: 'off' },
  page: 'dashboard',
  log: [],
  logFilter: 'all',
  logQuery: '',
  autoscroll: true,
  runSince: null,
  pausedAt: null, // debut de la pause en cours : le temps de run ne compte pas les pauses
  stats: null,
  logKind: 'bot', // journal affiche : 'bot' ou 'attack'
  attackLog: [],
  strategy: null, // strategie selectionnee dans la liste
  connected: false,
};

function resetStats() {
  app.stats = {
    since: Date.now(),
    first: null,
    current: {},
    history: { gold: [], elixir: [], dark: [], gems: [] },
    league: '',
    searches: 0,
    attacks: 0,
    warnings: 0,
    errors: 0,
  };
}
resetStats();

// ---------------------------------------------------------------------------------------------------------------------
// utilitaires
// ---------------------------------------------------------------------------------------------------------------------
function toast(message, kind = 'info') {
  const el = document.createElement('div');
  el.className = `toast ${kind}`;
  el.innerHTML = icon(kind === 'error' ? 'i-alert' : kind === 'success' ? 'i-check' : 'i-info');
  const span = document.createElement('span');
  span.textContent = message;
  el.append(span);
  $('#toasts').append(el);
  setTimeout(() => el.classList.add('out'), 4200);
  setTimeout(() => el.remove(), 4600);
}

async function guard(fn, okMessage) {
  try {
    const res = await fn();
    if (okMessage) toast(okMessage, 'success');
    return res;
  } catch (err) {
    toast(String(err.message ?? err).replace(/^Error invoking remote method '[^']+': (Error: )?/, ''), 'error');
    return null;
  }
}

function duration(ms) {
  const s = Math.floor(ms / 1000);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (h) return `${h} h ${String(m).padStart(2, '0')} min`;
  if (m) return `${m} min ${String(s % 60).padStart(2, '0')} s`;
  return `${s} s`;
}

// ---------------------------------------------------------------------------------------------------------------------
// theme
// ---------------------------------------------------------------------------------------------------------------------
const systemDark = window.matchMedia('(prefers-color-scheme: dark)');

// reglages : theme = 'dark' | 'light' (le choix manuel), followSystemTheme = suivre le theme de Windows.
// L'ancien theme: 'system' vaut "suivre Windows" (la case est cochee) jusqu'a ce qu'on la decoche.
function themeChoice() {
  const { theme = 'dark', followSystemTheme = false } = app.settings;
  return { follow: Boolean(followSystemTheme) || theme === 'system', manual: theme === 'light' ? 'light' : 'dark' };
}

// texte pose sur l'accent : noir sur un accent clair (un bleu clair de Windows...), blanc sinon
function textOn(hex) {
  const lin = (i) => {
    const v = parseInt(hex.slice(i, i + 2), 16) / 255;
    return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * lin(1) + 0.7152 * lin(3) + 0.0722 * lin(5) > 0.45 ? '#0a0a0a' : '#fff';
}

function applyTheme() {
  const { accent = DEFAULT_ACCENT } = app.settings;
  const { follow, manual } = themeChoice();
  const resolved = follow ? (systemDark.matches ? 'dark' : 'light') : manual;
  const root = document.documentElement;
  root.dataset.theme = resolved;
  const systemColor = app.systemAccent || DEFAULT_ACCENT;
  if (accent === 'mono') {
    root.dataset.accent = 'mono';
    root.style.removeProperty('--accent');
    root.style.removeProperty('--on-accent');
  } else {
    const color = accent === 'system' ? systemColor : /^#[0-9a-f]{6}$/i.test(accent) ? accent : DEFAULT_ACCENT;
    delete root.dataset.accent;
    root.style.setProperty('--accent', color);
    root.style.setProperty('--on-accent', textOn(color));
  }
  const systemSwatch = $('#accentSwatches button[data-color="system"]');
  if (systemSwatch) {
    systemSwatch.style.setProperty('--sw', systemColor);
    systemSwatch.style.color = textOn(systemColor);
  }
  const css = getComputedStyle(root);
  backend?.setTitleBar?.({ color: css.getPropertyValue('--titlebar').trim(), symbolColor: css.getPropertyValue('--text-2').trim() });
  // en suivant Windows, Sombre / Clair sont grises et montrent le theme de Windows
  $$('#themeSeg button').forEach((b) => {
    b.classList.toggle('active', b.dataset.theme === resolved);
    b.disabled = follow;
  });
  const followBox = $('#themeFollowSystem');
  if (followBox) followBox.checked = follow;
  $$('#accentSwatches button').forEach((b) => b.classList.toggle('active', b.dataset.color === accent));
}
systemDark.addEventListener('change', applyTheme);

// ---------------------------------------------------------------------------------------------------------------------
// navigation
// ---------------------------------------------------------------------------------------------------------------------
const PAGES = ['dashboard', 'log', 'village', 'army', 'attack', 'strategies', 'notify', 'bot', 'profiles', 'settings', 'updates'];

function confirmLeave() {
  return !FormEngine.dirty().length || confirm('Des modifications ne sont pas enregistrées. Les abandonner ?');
}

async function go(page) {
  if (page === app.page) return;
  if (!confirmLeave()) return;
  app.page = page;
  $$('#nav button').forEach((b) => b.classList.toggle('active', b.dataset.page === page));
  $$('.page').forEach((p) => p.classList.toggle('active', p.id === `page-${page}`));
  $('#main').scrollTop = 0;
  FormEngine.leave();
  if (FormEngine.has(page)) await FormEngine.load(page);
  if (page === 'strategies') renderStrategies();
  if (page === 'profiles') renderProfiles();
  if (page === 'updates') renderUpdates();
  if (page === 'log') scrollLogToEnd();
}

// ---------------------------------------------------------------------------------------------------------------------
// updates (application + bot files)
// ---------------------------------------------------------------------------------------------------------------------
function formatBytes(n) {
  if (!n) return '0 B';
  const u = ['B', 'KB', 'MB', 'GB'];
  const i = Math.min(u.length - 1, Math.floor(Math.log(n) / Math.log(1024)));
  return `${(n / 1024 ** i).toFixed(i ? 1 : 0)} ${u[i]}`;
}

const UPDATE_TAG = {
  idle: ['À jour', 'ok'],
  checking: ['Vérification…', ''],
  latest: ['À jour', 'ok'],
  available: ['Mise à jour disponible', 'accent'],
  downloading: ['Téléchargement…', 'accent'],
  downloaded: ['Prête à installer', 'accent'],
  error: ['Échec de la vérification', 'bad'],
};

function onUpdateState(st) {
  app.update = st;
  if (st.sync) app.sync = st.sync;
  const avail = st.phase === 'available' || st.phase === 'downloaded';
  const badge = $('#navUpdate');
  if (badge) badge.hidden = !avail;
  if (app.page === 'updates') renderUpdates();
}

function onBotSyncState(sync) {
  app.sync = sync;
  if (app.page === 'updates') renderUpdates();
}

async function refreshUpdates() {
  const st = await guard(() => backend.updateState());
  if (st) onUpdateState(st);
}

function renderUpdates() {
  const u = app.update ?? { phase: 'idle', current: app.info?.version };
  const [tagText, tagKind] = UPDATE_TAG[u.phase] ?? ['—', ''];
  $('#updTag').textContent = tagText;
  $('#updTag').className = `tag ${tagKind}`;
  $('#updCurrent').textContent = u.current ?? app.info?.version ?? '—';
  $('#updLatest').textContent = u.version ? `v${u.version.replace(/^v/, '')}` : u.phase === 'latest' ? 'aucune plus récente' : '—';
  $('#updChecked').textContent = u.checkedAt ? new Date(u.checkedAt).toLocaleString() : 'jamais';
  $('#updReleases').href = u.releasesPage ?? '#';
  $('#updCheck').disabled = ['checking', 'downloading'].includes(u.phase);

  const prog = $('#updProgress');
  prog.hidden = u.phase !== 'downloading';
  if (u.phase === 'downloading') {
    $('#updBar').style.width = `${Math.round(u.percent ?? 0)}%`;
    $('#updProgressText').textContent = `${Math.round(u.percent ?? 0)}% — ${formatBytes(u.transferred)} / ${formatBytes(u.total)}`;
  }

  const note = $('#updNote');
  if (u.phase === 'error') {
    note.hidden = false;
    note.textContent = u.error ?? 'La recherche de mise à jour a échoué.';
  } else if (!u.installed && u.phase === 'available') {
    note.hidden = false;
    note.textContent = "Lancé depuis les sources : ouvrez la version sur GitHub pour mettre à jour. L'application installée se met à jour toute seule.";
  } else note.hidden = true;

  const action = $('#updAction');
  if (u.installed && u.phase === 'available') setBtn(action, 'Télécharger la mise à jour', 'i-down', () => guard(() => backend.downloadUpdate()));
  else if (u.phase === 'downloaded') setBtn(action, 'Redémarrer et installer', 'i-power', installUpdate);
  else action.hidden = true;

  const notes = $('#updNotesCard');
  notes.hidden = !u.notes;
  if (u.notes) {
    $('#updNotes').textContent = u.notes;
    $('#updNotesVer').textContent = u.version ? `v${u.version.replace(/^v/, '')}` : '';
  }

  renderBotSync();
  renderImport();
}

function setBtn(btn, label, iconId, onClick) {
  btn.hidden = false;
  btn.disabled = false;
  btn.innerHTML = `${icon(iconId)}${label}`;
  btn.onclick = onClick;
}

async function installUpdate() {
  let closeBots = false;
  if (app.bot && !['off', 'error', 'unsupported'].includes(app.bot.state)) {
    if (!confirm('Un bot est ouvert. Il doit être fermé pour installer la mise à jour. Le fermer et installer maintenant ?')) return;
    closeBots = true;
  }
  await guard(() => backend.installUpdate(closeBots));
}

function renderBotSync() {
  const card = $('#botSyncCard');
  if (!app.info?.packaged) {
    card.hidden = true;
    return;
  }
  card.hidden = false;
  const s = app.sync ?? { phase: 'idle' };
  const map = {
    idle: ['À jour', 'ok'],
    waiting: ['En attente de la fermeture du bot', 'accent'],
    copying: ['Mise à jour…', 'accent'],
    done: ['Mis à jour', 'ok'],
    error: ['Échec', 'bad'],
  };
  const [text, kind] = map[s.phase] ?? ['—', ''];
  $('#botSyncTag').textContent = text;
  $('#botSyncTag').className = `tag ${kind}`;
  const prog = $('#botSyncProgress');
  prog.hidden = s.phase !== 'copying';
  if (s.phase === 'copying') {
    const pct = s.total ? Math.round((s.done / s.total) * 100) : 0;
    $('#botSyncBar').style.width = `${pct}%`;
    $('#botSyncProgressText').textContent = `${pct}% — ${s.done}/${s.total} fichiers`;
  }
  if (s.phase === 'waiting') $('#botSyncText').textContent = "Un bot est ouvert : fermez-le pour que ses fichiers soient mis à jour. Cela se fera tout seul dès qu'il sera fermé.";
  else if (s.phase === 'error') $('#botSyncText').textContent = s.error ?? "Certains fichiers du bot n'ont pas pu être mis à jour.";
  else $('#botSyncText').textContent = "Le bot est tenu à jour avec l'application, dans son propre dossier ; vos profils ne sont jamais modifiés.";
  $('#botSyncVerify').disabled = s.phase === 'copying';
}

function renderImport() {
  const card = $('#importCard');
  card.hidden = !app.info?.legacyBotDir;
  if (app.info?.legacyBotDir) $('#importText').textContent = `Les profils de votre ancien dossier MyBot (${app.info.legacyBotDir}) peuvent être importés une fois. Vos profils actuels sont conservés.`;
}

// ---------------------------------------------------------------------------------------------------------------------
// etat du bot et commandes
// ---------------------------------------------------------------------------------------------------------------------
function setBotState(next) {
  // hors Windows, sans le mode demo, rien a piloter
  if (app.info && !app.info.control && !app.info.demo) next = { state: 'unsupported' };
  const prev = app.bot.state;
  app.bot = next;
  const s = next.state;
  // temps de run : il ne repart a zero que quand le bot s'arrete vraiment. "noanswer" (le bot occupe plus de 1,5 s,
  // en fin d'attaque notamment), "error" et "denied" sont passagers et le remettaient a zero ; la pause le fige.
  if (s === 'running') {
    if (!app.runSince) app.runSince = Date.now();
    if (app.pausedAt) {
      app.runSince += Date.now() - app.pausedAt;
      app.pausedAt = null;
    }
  } else if (s === 'paused') {
    if (app.runSince && !app.pausedAt) app.pausedAt = Date.now();
  } else if (['off', 'idle', 'starting', 'unsupported'].includes(s)) {
    app.runSince = null;
    app.pausedAt = null;
  }
  if (app.connected && prev === 'off' && s === 'starting') resetStats(); // nouveau lancement : nouvelle session
  if (app.connected && prev && prev !== 'off' && s === 'off') checkRepair(); // le bot a reecrit son profil en se fermant

  $('#statusPill').dataset.state = s;
  $('#statusText').textContent = STATE_LABEL[s] ?? s;
  $('#heroState').textContent = STATE_LABEL[s] ?? s;
  $('#heroCard').dataset.state = s;
  $('#orb').innerHTML = icon({ running: 'i-play', paused: 'i-pause', idle: 'i-check', off: 'i-power' }[s] ?? 'i-clock');

  const control = app.info?.control;
  const open = !['off', 'error', 'unsupported'].includes(s);
  const enable = (sel, on) => $$(sel).forEach((b) => (b.disabled = !control || !on));
  enable('#btnStart, #miniStart', s === 'idle');
  enable('#btnPause, #miniPause', s === 'running' || s === 'paused');
  enable('#btnStop, #miniStop', s === 'running' || s === 'paused');
  enable('#btnClose', open);
  enable('#btnLaunch', !open && app.info?.botFound);
  $('#btnPause span').textContent = s === 'paused' ? 'Reprendre' : 'Pause';
  $('#btnPause use').setAttribute('href', s === 'paused' ? '#i-play' : '#i-pause');
  $('#miniPause use').setAttribute('href', s === 'paused' ? '#i-play' : '#i-pause');

  const notes = {
    denied: "Windows refuse les commandes : lancez ce GUI en administrateur, comme le bot.",
    error: next.error ? `Le pont vers le bot ne répond pas : ${next.error}` : '',
    noanswer: 'Le bot est ouvert mais ne répond pas encore (démarrage ou tâche longue).',
    unsupported:
      app.info?.platform === 'linux'
        ? 'Le pilotage du bot sous Linux demande Wine et AutoIt dans le préfixe du bot (voir le README). Utilisez le mode démo pour voir le GUI.'
        : 'Le pilotage du bot ne fonctionne que sous Windows. Utilisez le mode démo pour voir le GUI.',
  };
  $('#heroNote').textContent = notes[s] ?? '';
  updateUptime();
}

async function botCommand(name) {
  if (name === 'pause' && app.bot.state === 'paused') name = 'resume';
  const res = await guard(() => backend.command(name));
  if (res?.state) setBotState({ ...app.bot, state: res.state });
}

async function launchBot() {
  const res = await guard(() => backend.launch(), `Lancement du bot (${app.settings.profile})…`);
  if (res) setBotState({ state: 'starting' });
}

function updateUptime() {
  const text = app.runSince ? duration((app.pausedAt ?? Date.now()) - app.runSince) : '—';
  $('#uptime').textContent = text;
  $('#sessionSince').textContent = `depuis ${duration(Date.now() - app.stats.since)}`;
  $('#sbClock').textContent = new Date().toLocaleTimeString('fr-FR');
}

// ---------------------------------------------------------------------------------------------------------------------
// journal
// ---------------------------------------------------------------------------------------------------------------------
const MAX_LOG = 3000;
const RE_REPORT = /^\[G\]:\s*([\d\s]+?)\s+\[E\]:\s*([\d\s]+?)(?:\s+\[D\]:\s*([\d\s]+?))?\s+\[GEM\]:\s*([\d\s]+)$/;
const RE_LEAGUE = /^\[League\]:\s*(.+)$/;
const RE_SEARCH = /^\d+>\s*\[G\]:/;
const num = (s) => Number(String(s).replace(/\s/g, '')) || 0;

// the bot writes its debug lines to its log file whatever its settings: "all" leaves them out, as the bot's own window
// did, and the Debug filter shows them
function lineMatches(line) {
  if (app.logKind === 'bot' && (app.logFilter === 'all' ? line.level === 'debug' : line.level !== app.logFilter)) return false;
  if (app.logQuery && !line.text.toLowerCase().includes(app.logQuery)) return false;
  return true;
}

function lineElement(line) {
  const row = document.createElement('div');
  row.className = `line lvl-${line.level}`;
  const time = document.createElement('span');
  time.className = 'time';
  time.textContent = line.time;
  const text = document.createElement('span');
  text.className = 'text';
  text.textContent = line.text; // jamais de HTML venant du journal
  row.append(time, text);
  return row;
}

function ingest(lines) {
  const st = app.stats;
  for (const line of lines) {
    const t = line.text.trim();
    const report = RE_REPORT.exec(t);
    if (report) {
      const values = { gold: num(report[1]), elixir: num(report[2]), dark: report[3] ? num(report[3]) : null, gems: num(report[4]) };
      st.first ??= { ...values };
      st.current = values;
      for (const key of Object.keys(st.history)) {
        if (values[key] === null) continue;
        st.history[key].push(values[key]);
        if (st.history[key].length > 60) st.history[key].shift();
      }
    }
    const league = RE_LEAGUE.exec(t);
    if (league) st.league = league[1];
    if (RE_SEARCH.test(t)) st.searches++;
    if (/^Returning Home$/i.test(t)) st.attacks++;
    if (line.level === 'warn') st.warnings++;
    if (line.level === 'error') st.errors++;
  }
}

function appendLog(lines) {
  app.log.push(...lines);
  if (app.log.length > MAX_LOG) app.log.splice(0, app.log.length - MAX_LOG);
  ingest(lines);

  if (app.logKind === 'bot') showLines(lines);

  const mini = $('#miniLog');
  const recent = [];
  for (let i = app.log.length - 1; i >= 0 && recent.length < 9; i--) if (app.log[i].level !== 'debug') recent.unshift(app.log[i]);
  mini.replaceChildren(...recent.map(lineElement));

  const last = lines.findLast((l) => l.level !== 'debug');
  if (last) $('#sbLast').textContent = `${last.time}  ${last.text}`;
  renderDashboard();
}

// ajoute des lignes au journal affiche
function showLines(lines) {
  const box = $('#log');
  const atEnd = box.scrollHeight - box.scrollTop - box.clientHeight < 40;
  const frag = document.createDocumentFragment();
  for (const line of lines) if (lineMatches(line)) frag.append(lineElement(line));
  if (frag.childElementCount) box.querySelector('.empty')?.remove();
  box.append(frag);
  while (box.childElementCount > MAX_LOG) box.firstElementChild.remove();
  if (app.autoscroll && (atEnd || app.page !== 'log')) box.scrollTop = box.scrollHeight;
}

// le tableau des attaques (AttackLog-AAAA-MM.log) : une ligne par attaque, sans niveau
function appendAttackLog(lines) {
  app.attackLog.push(...lines);
  if (app.attackLog.length > MAX_LOG) app.attackLog.splice(0, app.attackLog.length - MAX_LOG);
  if (app.logKind === 'attack') showLines(lines);
}

function renderLog() {
  const box = $('#log');
  const source = app.logKind === 'attack' ? app.attackLog : app.log;
  box.classList.toggle('attack-log', app.logKind === 'attack');
  showLogFile(app.logFile);
  $('#logFilters').classList.toggle('disabled', app.logKind === 'attack');
  const frag = document.createDocumentFragment();
  for (const line of source) if (lineMatches(line)) frag.append(lineElement(line));
  box.replaceChildren(frag);
  if (!box.childElementCount) {
    const empty = document.createElement('div');
    empty.className = 'empty';
    empty.textContent = source.length
      ? 'Aucune ligne ne correspond au filtre.'
      : app.logKind === 'attack'
        ? 'Le tableau des attaques apparaîtra ici après la première attaque (Logs\\AttackLog-AAAA-MM.log).'
        : 'Le journal apparaîtra ici dès que le bot écrit.';
    box.append(empty);
  }
  scrollLogToEnd();
}

function scrollLogToEnd() {
  if (!app.autoscroll) return;
  const box = $('#log');
  requestAnimationFrame(() => (box.scrollTop = box.scrollHeight));
}

// ---------------------------------------------------------------------------------------------------------------------
// tableau de bord
// ---------------------------------------------------------------------------------------------------------------------
function sparkline(values, color) {
  if (values.length < 2) return '<svg class="spark" viewBox="0 0 100 32" preserveAspectRatio="none"></svg>';
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const pts = values.map((v, i) => [(i / (values.length - 1)) * 100, 29 - ((v - min) / span) * 26]);
  const line = pts.map(([x, y]) => `${x.toFixed(2)},${y.toFixed(2)}`).join(' ');
  const id = `g${Math.random().toString(36).slice(2, 8)}`;
  return `<svg class="spark" viewBox="0 0 100 32" preserveAspectRatio="none">
    <defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${color}" stop-opacity=".35"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></linearGradient></defs>
    <polygon points="0,32 ${line} 100,32" fill="url(#${id})"/>
    <polyline points="${line}" fill="none" stroke="${color}" stroke-width="1.6" vector-effect="non-scaling-stroke" stroke-linejoin="round"/>
  </svg>`;
}

function buildResourceTiles() {
  const box = $('#resources');
  box.innerHTML = RESOURCES.map(
    (r) => `<article class="card tile" data-res="${r.key}" style="--c:${r.color}">
      <div class="tile-head"><span class="tile-icon">${icon(r.icon)}</span><span class="tile-label">${r.label}</span></div>
      <div class="tile-value">—</div>
      <div class="tile-delta">&nbsp;</div>
      <div class="tile-spark"></div>
    </article>`,
  ).join('') +
    `<article class="card tile" data-res="league" style="--c:var(--league)">
      <div class="tile-head"><span class="tile-icon">${icon('i-trophy')}</span><span class="tile-label">Ligue</span></div>
      <div class="tile-value small-value">—</div>
      <div class="tile-delta muted">lue sur le badge du village</div>
    </article>`;
}

function renderDashboard() {
  const st = app.stats;
  for (const r of RESOURCES) {
    const tile = $(`.tile[data-res="${r.key}"]`);
    const v = st.current[r.key];
    tile.querySelector('.tile-value').textContent = v === undefined || v === null ? '—' : nf.format(v);
    const delta = st.first && v !== null && v !== undefined && st.first[r.key] !== null ? v - st.first[r.key] : null;
    const d = tile.querySelector('.tile-delta');
    d.textContent = delta === null ? ' ' : `${delta >= 0 ? '+' : '−'} ${nfCompact.format(Math.abs(delta))} depuis le début`;
    d.classList.toggle('up', delta > 0);
    d.classList.toggle('down', delta < 0);
    tile.querySelector('.tile-spark').innerHTML = sparkline(st.history[r.key], getComputedStyle(tile).getPropertyValue('--c').trim() || 'currentColor');
  }
  $('.tile[data-res="league"] .tile-value').textContent = st.league || '—';
  $('#kpiSearches').textContent = nf.format(st.searches);
  $('#kpiAttacks').textContent = nf.format(st.attacks);
  $('#kpiWarnings').textContent = nf.format(st.warnings);
  $('#kpiErrors').textContent = nf.format(st.errors);
  const badge = $('#navErrors');
  badge.hidden = st.errors === 0;
  badge.textContent = st.errors > 99 ? '99+' : st.errors;
}

// ---------------------------------------------------------------------------------------------------------------------
// pages de reglages (form-engine.js) et barre d'enregistrement
// ---------------------------------------------------------------------------------------------------------------------
function updateSavebar(count) {
  $('#savebar').hidden = count === 0;
  $('#main').classList.toggle('has-savebar', count > 0);
  $('#dirtyCount').textContent = count;
}

async function saveForm() {
  const n = await FormEngine.save();
  if (n > 0) toast(`${n} réglage(s) enregistré(s) pour le profil ${app.settings.profile}`, 'success');
}

function reloadForm() {
  const name = FormEngine.current();
  if (name && confirmLeave()) FormEngine.load(name);
}

// ---------------------------------------------------------------------------------------------------------------------
// strategies (Attack Plan > Strategies du bot)
// ---------------------------------------------------------------------------------------------------------------------
async function renderStrategies() {
  const list = (await guard(() => backend.listStrategies())) ?? [];
  $('#strategyCount').textContent = list.length ? `${list.length} dans Strategies\\` : '';
  if (app.strategy && !list.some((s) => s.name === app.strategy)) app.strategy = null;
  const box = $('#strategyList');
  if (!list.length) {
    box.innerHTML = '<div class="empty">Aucune stratégie : enregistrez les réglages actuels à droite.</div>';
  } else {
    box.replaceChildren(
      ...list.map((s) => {
        const item = document.createElement('button');
        item.className = `strategy-item${s.name === app.strategy ? ' active' : ''}`;
        item.innerHTML = `${icon('i-book')}<span class="strategy-name"></span><span class="muted small strategy-first"></span>`;
        item.querySelector('.strategy-name').textContent = s.name;
        item.querySelector('.strategy-first').textContent = s.info.split('\n')[0];
        item.addEventListener('click', () => {
          app.strategy = s.name;
          renderStrategies();
        });
        return item;
      }),
    );
  }
  const current = list.find((s) => s.name === app.strategy);
  $('#strategyInfo').hidden = !current;
  if (current) $('#strategyNotes').textContent = current.info || '(pas de notes)';
}

async function loadStrategy() {
  if (!app.strategy) return;
  if (!confirm(`Remplacer les réglages d'armée et d'attaque du profil ${app.settings.profile} par « ${app.strategy} » ?`)) return;
  const n = await guard(() => backend.loadStrategy(app.strategy));
  if (n !== null) toast(`Stratégie « ${app.strategy} » chargée (${n} réglages)`, 'success');
}

async function saveStrategy() {
  const name = $('#strategyName').value.trim();
  if (!name) return toast('Donnez un nom à la stratégie', 'error');
  const saved = await guard(() => backend.saveStrategy(name, $('#strategyNewNotes').value));
  if (!saved) return;
  toast(`Stratégie « ${saved} » enregistrée`, 'success');
  $('#strategyName').value = '';
  $('#strategyNewNotes').value = '';
  app.strategy = saved;
  renderStrategies();
}

async function deleteStrategy() {
  if (!app.strategy || !confirm(`Supprimer la stratégie « ${app.strategy} » ?`)) return;
  const res = await guard(() => backend.deleteStrategy(app.strategy));
  if (res === null) return;
  toast(`Stratégie « ${app.strategy} » supprimée`, 'success');
  app.strategy = null;
  renderStrategies();
}

// ---------------------------------------------------------------------------------------------------------------------
// profils
// ---------------------------------------------------------------------------------------------------------------------
function buildSwitches() {
  $('#switchList').innerHTML = SWITCHES.map(
    ([key, label, hint]) => `<label class="row-toggle">
      <span class="row-text"><span>${label} <code>/${key}</code></span><small>${hint}</small></span>
      <input type="checkbox" class="switch" data-switch="${key}">
    </label>`,
  ).join('');
}

function launchForm() {
  const switches = {};
  $$('#switchList [data-switch]').forEach((i) => (switches[i.dataset.switch] = i.checked));
  return { profile: $('#setProfile').value.trim(), emulator: $('#setEmulator').value, instance: $('#setInstance').value.trim(), switches };
}

function updateCmdPreview() {
  const f = launchForm();
  const q = (s) => (/\s/.test(s) ? `"${s}"` : s);
  const flags = SWITCH_ORDER.filter((k) => f.switches[k]).map((k) => `/${k}`);
  // sous Linux, le bot est lance dans Wine par l'AutoIt du prefixe
  const exe = app.info?.platform === 'win32' || !app.info ? 'MyBot.run.exe' : 'wine AutoIt3.exe MyBot.run.au3';
  $('#cmdPreview').textContent = [exe, q(f.profile || '?'), f.emulator, q(f.instance || '?'), ...flags].join(' ');
}

function fillLaunchForm() {
  const s = app.settings;
  $('#setProfile').value = s.profile;
  $('#setEmulator').value = s.emulator;
  $('#setInstance').value = s.instance;
  $$('#switchList [data-switch]').forEach((i) => (i.checked = Boolean(s.switches?.[i.dataset.switch])));
  updateCmdPreview();
  $('#pillProfile').textContent = s.profile;
  $('#pillInstance').textContent = `${s.emulator} · ${s.instance}`;
  $('#heroProfile').textContent = s.profile;
  $('#heroInstance').textContent = `${s.emulator} · ${s.instance}`;
}

async function renderProfiles() {
  const list = (await guard(() => backend.listProfiles())) ?? [];
  $('#profileList').innerHTML = list.map((p) => `<option value="${p.name.replace(/"/g, '&quot;')}">`).join('');
  const box = $('#profileCards');
  if (!list.length) {
    box.innerHTML = '<div class="empty">Aucun profil : le bot crée le sien au premier démarrage.</div>';
    return;
  }
  box.replaceChildren(
    ...list.map((p) => {
      const card = document.createElement('div');
      const current = p.name.toLowerCase() === app.settings.profile.toLowerCase();
      card.className = `profile-card${current ? ' current' : ''}`;
      card.innerHTML = `<div class="avatar"></div>
        <div class="profile-info"><strong></strong><span class="muted small"></span><div class="profile-tags"></div></div>
        <button class="btn btn-sm">${current ? 'Actif' : 'Utiliser'}</button>`;
      card.querySelector('.avatar').textContent = p.name.slice(0, 1).toUpperCase();
      card.querySelector('strong').textContent = p.name;
      card.querySelector('.profile-info span').textContent = p.instance ? `${p.emulator} · ${p.instance}` : 'instance non renseignée';
      card.querySelector('.profile-tags').innerHTML =
        (p.hasConfig ? '<span class="tag ok">config.ini</span>' : '<span class="tag">nouveau</span>') + (p.multibot ? '<span class="tag">MultiBot</span>' : '');
      const btn = card.querySelector('button');
      btn.disabled = current;
      btn.addEventListener('click', async () => {
        const patch = { profile: p.name };
        if (p.emulator) patch.emulator = p.emulator;
        if (p.instance) patch.instance = p.instance;
        await applySettings(patch, `Profil ${p.name} sélectionné`);
        renderProfiles();
      });
      return card;
    }),
  );
}

// Bot > Profils du bot : nouveau, copie, renommer, supprimer (le profil actif pour les deux derniers)
async function profileAction(kind) {
  const name = $('#profileNewName').value.trim();
  const active = app.settings.profile;
  if (kind !== 'delete' && !name) return toast('Tapez un nom de profil', 'error');
  if (['rename', 'delete'].includes(kind) && !['off', 'error', 'unsupported'].includes(app.bot.state)) {
    return toast(`Fermez d'abord le bot du profil ${active}`, 'error');
  }
  let res;
  if (kind === 'create' || kind === 'duplicate') {
    res = await guard(() => backend.createProfile(name, kind === 'duplicate' ? active : ''));
    if (!res) return;
    toast(kind === 'duplicate' ? `Profil ${res} créé à partir de ${active}` : `Profil ${res} créé`, 'success');
  } else if (kind === 'rename') {
    if (!confirm(`Renommer le profil ${active} en ${name} ?`)) return;
    res = await guard(() => backend.renameProfile(active, name));
    if (!res) return;
    toast(`Profil renommé en ${res}`, 'success');
    await profileSwitched();
  } else {
    if (!confirm(`Supprimer le profil ${active}, ses réglages et ses journaux ? C'est définitif.`)) return;
    res = await guard(() => backend.deleteProfile(active));
    if (res === null) return;
    toast(`Profil ${active} supprimé`, 'success');
    await profileSwitched();
  }
  $('#profileNewName').value = '';
  renderProfiles();
}

// le processus principal a change de profil actif (renomme, supprime) : on repart de ses reglages
async function profileSwitched() {
  const info = await guard(() => backend.info());
  if (!info) return;
  setInfo(info);
  await reloadLog(info.logFile);
  const form = FormEngine.current();
  if (form) await FormEngine.load(form);
}

// ---------------------------------------------------------------------------------------------------------------------
// reglages
// ---------------------------------------------------------------------------------------------------------------------
async function applySettings(patch, message) {
  const profileChanged = patch.profile && patch.profile !== app.settings.profile;
  const info = await guard(() => backend.setSettings(patch), message);
  if (!info) return;
  setInfo(info);
  if (profileChanged) {
    checkRepair();
    await reloadLog(info.logFile); // le journal suivi est maintenant celui du nouveau profil
    const form = FormEngine.current();
    if (form) await FormEngine.load(form);
  }
}

function setInfo(info) {
  app.info = info;
  app.settings = info.settings;
  applyTheme();
  applyLanguage();
  fillLaunchForm();
  $('#demoTag').hidden = !info.demo;
  // the installed application manages the bot folder itself: on the first start the bot is still being copied there,
  // which is not an error (the Updates page shows the progress)
  $('#setupBanner').hidden = info.botFound || info.demo || info.packaged;
  $('#pickBotDir').hidden = Boolean(info.packaged);
  $('#botDirPath').textContent = info.settings.botDir || 'Non défini';
  const tag = $('#botDirTag');
  const installing = info.packaged && !info.botFound;
  tag.textContent = installing ? 'Installation…' : info.botFound ? 'Trouvé' : 'Introuvable';
  tag.className = `tag ${installing ? 'accent' : info.botFound ? 'ok' : 'bad'}`;
  $('#brandVersion').textContent = `v12 · GUI ${info.version}`;
  const about = [
    ['Version du GUI', info.version],
    ['Mode', info.demo ? 'Démo (bot simulé)' : 'Réel'],
    ['Plateforme', info.platform],
    ['Pilotage du bot', info.control ? (info.platform === 'win32' ? 'disponible' : 'disponible (Wine)') : info.platform === 'linux' ? 'Wine + AutoIt introuvables' : 'Windows uniquement'],
  ];
  $('#aboutList').innerHTML = about.map(([k]) => `<dt>${k}</dt><dd></dd>`).join('');
  $$('#aboutList dd').forEach((dd, i) => (dd.textContent = about[i][1]));
  const upd = info.settings.updates ?? {};
  $('#updAuto').checked = upd.autoCheck !== false;
  $('#updBeta').checked = Boolean(upd.beta);
  renderImport();
  renderBotSync();
  setBotState(app.bot);
}

// langue de l'interface (i18n.js) : appliquee tout de suite, sans redemarrer ; les nombres suivent
function applyLanguage() {
  const lang = app.settings.language === 'en' ? 'en' : 'fr';
  const changed = lang !== I18n.lang;
  I18n.setLang(lang);
  $$('#langSeg button').forEach((b) => b.classList.toggle('active', b.dataset.lang === lang));
  const locale = lang === 'en' ? 'en-US' : 'fr-FR';
  nf = new Intl.NumberFormat(locale);
  nfCompact = new Intl.NumberFormat(locale, { notation: 'compact', maximumFractionDigits: 1 });
  if (changed) renderDashboard();
}

function buildSettings() {
  $('#langSeg').addEventListener('click', (e) => {
    const lang = e.target.closest('button')?.dataset.lang;
    if (lang && lang !== app.settings.language) applySettings({ language: lang });
  });
  $('#accentSwatches').innerHTML = ACCENTS.map((c) =>
    c.startsWith('#')
      ? `<button data-color="${c}" style="--sw:${c}" title="${c}"></button>`
      : `<button data-color="${c}" title="${ACCENT_TITLES[c] ?? c}">${c === 'system' ? icon('i-monitor') : ''}</button>`,
  ).join('');
  $('#accentSwatches').addEventListener('click', (e) => {
    const c = e.target.closest('button')?.dataset.color;
    if (c) applySettings({ accent: c });
  });
  $('#themeSeg').addEventListener('click', (e) => {
    const t = e.target.closest('button')?.dataset.theme;
    if (t && !themeChoice().follow) applySettings({ theme: t });
  });
  // decocher garde le theme affiche a cet instant (celui de Windows) comme choix manuel
  $('#themeFollowSystem')?.addEventListener('change', (e) => {
    applySettings(e.target.checked ? { followSystemTheme: true } : { followSystemTheme: false, theme: document.documentElement.dataset.theme }).then(applyTheme);
  });
  $('#pickBotDir').addEventListener('click', async () => {
    const info = await guard(() => backend.pickBotDir());
    if (!info) return;
    if (info.error) toast(info.error, 'error');
    else if (!info.canceled) toast('Dossier du bot enregistré', 'success');
    setInfo(info);
  });
  $('#openBotDir').addEventListener('click', () => openPath('botDir'));
}

async function openPath(what) {
  const err = await guard(() => backend.openPath(what));
  if (err) toast(err, 'error');
}

// ---------------------------------------------------------------------------------------------------------------------
// demarrage
// ---------------------------------------------------------------------------------------------------------------------
function wire() {
  $('#nav').addEventListener('click', (e) => {
    const page = e.target.closest('button[data-page]')?.dataset.page;
    if (page) go(page);
  });
  document.addEventListener('click', (e) => {
    const target = e.target.closest('[data-goto]');
    if (target) go(target.dataset.goto);
  });
  $('#profilePill').addEventListener('click', () => go('profiles'));

  $('#btnStart').addEventListener('click', () => botCommand('start'));
  $('#miniStart').addEventListener('click', () => botCommand('start'));
  $('#btnPause').addEventListener('click', () => botCommand('pause'));
  $('#miniPause').addEventListener('click', () => botCommand('pause'));
  $('#btnStop').addEventListener('click', () => botCommand('stop'));
  $('#miniStop').addEventListener('click', () => botCommand('stop'));
  $('#btnClose').addEventListener('click', () => botCommand('close'));
  $('#btnLaunch').addEventListener('click', launchBot);

  $('#bannerPick').addEventListener('click', () => $('#pickBotDir').click());
  $('#bannerDemo').addEventListener('click', () => startDemo());

  $('#logFilters').addEventListener('click', (e) => {
    const chip = e.target.closest('.chip');
    if (!chip) return;
    app.logFilter = chip.dataset.level;
    $$('#logFilters .chip').forEach((c) => c.classList.toggle('active', c === chip));
    renderLog();
  });
  $('#logSearch').addEventListener('input', (e) => {
    app.logQuery = e.target.value.trim().toLowerCase();
    renderLog();
  });
  $('#logAutoscroll').addEventListener('click', (e) => {
    app.autoscroll = !app.autoscroll;
    e.currentTarget.classList.toggle('active', app.autoscroll);
    scrollLogToEnd();
  });
  $('#logClear').addEventListener('click', () => {
    if (app.logKind === 'attack') app.attackLog = [];
    else app.log = [];
    renderLog();
  });
  $('#logOpenFolder').addEventListener('click', () => openPath('logs'));
  $('#logKind').addEventListener('click', (e) => {
    const kind = e.target.closest('button[data-kind]')?.dataset.kind;
    if (!kind || kind === app.logKind) return;
    app.logKind = kind;
    $$('#logKind button').forEach((b) => b.classList.toggle('active', b.dataset.kind === kind));
    renderLog();
  });

  $$('[data-reload]').forEach((b) => b.addEventListener('click', reloadForm));
  $('#saveBtn').addEventListener('click', saveForm);
  $('#discardBtn').addEventListener('click', () => {
    const name = FormEngine.current();
    if (name) FormEngine.load(name);
  });

  $('#strategiesFolder').addEventListener('click', () => openPath('strategies'));
  $('#strategyLoad').addEventListener('click', loadStrategy);
  $('#strategySave').addEventListener('click', saveStrategy);
  $('#strategyDelete').addEventListener('click', deleteStrategy);

  $('#profileCreate').addEventListener('click', () => profileAction('create'));
  $('#profileDuplicate').addEventListener('click', () => profileAction('duplicate'));
  $('#profileRename').addEventListener('click', () => profileAction('rename'));
  $('#profileDelete').addEventListener('click', () => profileAction('delete'));

  $('#page-profiles').addEventListener('input', updateCmdPreview);
  $('#page-profiles').addEventListener('change', updateCmdPreview);
  $('#saveLaunch').addEventListener('click', () => {
    const f = launchForm();
    if (!f.profile || !f.instance) return toast("Le profil et l'instance sont obligatoires", 'error');
    applySettings(f, 'Réglages de lancement enregistrés').then(renderProfiles);
  });
  $('#profilesRefresh').addEventListener('click', renderProfiles);

  $('#updCheck').addEventListener('click', () => guard(() => backend.checkUpdate()));
  $('#updAuto').addEventListener('change', (e) => guard(() => backend.setUpdateOptions({ autoCheck: e.target.checked })));
  $('#updBeta').addEventListener('change', (e) => guard(() => backend.setUpdateOptions({ beta: e.target.checked })).then(() => backend.checkUpdate?.()));
  $('#botSyncVerify').addEventListener('click', async () => {
    let closeBots = false;
    if (app.bot && !['off', 'error', 'unsupported'].includes(app.bot.state)) {
      if (!confirm('Un bot est ouvert. Le fermer pour réparer les fichiers du bot ?')) return;
      closeBots = true;
    }
    guard(() => backend.syncBot({ verify: true, closeBots }), 'Fichiers du bot vérifiés');
  });
  $('#importRun').addEventListener('click', async () => {
    const res = await guard(() => backend.importProfiles(), 'Profils importés');
    if (res) toast(`${res.profiles?.length ?? 0} profil(s) importé(s)`, 'success');
  });
  $('#importDismiss').addEventListener('click', () => guard(() => backend.dismissImport()));
  $('#repairRun').addEventListener('click', async () => {
    const res = await guard(() => backend.repairProfile());
    if (res) toast(`${res.count} réglage(s) remis par défaut, une copie du profil a été faite avant`, 'success');
    await checkRepair();
    const form = FormEngine.current();
    if (form) await FormEngine.load(form);
  });

  // Ctrl+1 a Ctrl+9 puis Ctrl+0 : les pages dans l'ordre du menu ; Ctrl+S : enregistrer
  document.addEventListener('keydown', (e) => {
    if (e.ctrlKey && /^[0-9]$/.test(e.key)) {
      e.preventDefault();
      go(PAGES[(Number(e.key) + 9) % 10]);
    }
    if (e.ctrlKey && e.key.toLowerCase() === 's' && FormEngine.current()) {
      e.preventDefault();
      saveForm();
    }
  });
  window.addEventListener('beforeunload', (e) => {
    if (FormEngine.dirty().length) e.preventDefault();
  });

  setInterval(updateUptime, 1000);
}

let unsubscribe = [];
async function connect() {
  app.connected = false;
  unsubscribe.forEach((off) => off?.());
  const info = await backend.info();
  if (info.demo && !(backend instanceof window.DemoBackend)) {
    backend = new window.DemoBackend(info);
    return connect();
  }
  app.systemAccent = (await backend.systemAccent?.().catch(() => null)) ?? null; // couleur d'accent de Windows
  setInfo(info);
  await reloadLog(info.logFile);
  unsubscribe = [
    backend.onSystemAccent?.((color) => {
      app.systemAccent = color ?? null;
      applyTheme();
    }),
    backend.onLog(appendLog),
    backend.onAttackLog(appendAttackLog),
    backend.onLogFile(showLogFile),
    backend.onState(setBotState),
    backend.onUpdate?.(onUpdateState),
    backend.onBotSync?.(onBotSyncState),
    backend.onInfo?.((i) => setInfo(i)),
  ];
  setBotState(await backend.state());
  refreshUpdates();
  checkRepair();
  app.connected = true;
}

// les reglages que MyBot 12.0.0 / 12.0.1 a enregistres faux dans le profil (lib/profile-repair.js) : un bandeau propose
// de les remettre par defaut. Revu au demarrage, au changement de profil et quand le bot se ferme (il reecrit son profil).
async function checkRepair() {
  const plan = (await backend.repairPlan?.().catch(() => [])) ?? [];
  $('#repairBanner').hidden = !plan.length;
  if (plan.length)
    $('#repairText').textContent = `MyBot 12.0.0 et 12.0.1 ont enregistré ${plan.length} réglage(s) de ce profil avec une mauvaise valeur (butin minimum à 0, fin de combat à 0, aucune heure de dons, mode arrière-plan coupé...). La réparation les remet par défaut ; ce que vous avez changé vous-même est gardé, et une copie du profil est faite avant. Fermez le bot d'abord.`;
}

// repart de l'historique du processus principal (la fin du journal courant) avec des compteurs a zero
async function reloadLog(logFile) {
  const history = await backend.logHistory();
  app.log = [];
  app.attackLog = (await backend.attackLogHistory()) ?? [];
  resetStats();
  $('#miniLog').replaceChildren();
  if (history.length) appendLog(history);
  renderLog();
  renderDashboard();
  showLogFile(logFile);
}

function showLogFile(name) {
  app.logFile = name;
  $('#sbFile').textContent = name || 'aucun journal';
  $('#logFileName').textContent =
    app.logKind === 'attack'
      ? 'Tableau des attaques du profil (Logs\\AttackLog-AAAA-MM.log)'
      : name
        ? `Suivi en direct de ${name}`
        : 'Suivi en direct de Profiles\\<profil>\\Logs';
}

async function startDemo() {
  backend = new window.DemoBackend(app.info);
  await connect();
  toast('Mode démo : cliquez sur « Ouvrir le bot » puis « Démarrer »', 'info');
}

async function init() {
  buildResourceTiles();
  FormEngine.init({ backend: { getConfig: (ids) => backend.getConfig(ids), setConfig: (v) => backend.setConfig(v), list: (k) => backend.list(k), listProfiles: () => backend.listProfiles() }, toast, guard, onDirty: updateSavebar }, window.PAGES, $('#main'), $('#page-strategies'));
  buildSwitches();
  buildSettings();
  wire();
  if (!backend) backend = new window.DemoBackend(); // page ouverte dans un navigateur
  await connect();
  renderDashboard();
  updateUptime();
}

init();
