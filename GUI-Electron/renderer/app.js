'use strict';
// La page : navigation, tableau de bord, journal, formulaires de config.ini, profils et reglages.
// Tout passe par `backend` : window.mybot (preload.js) dans Electron, ou DemoBackend (demo.js) en demo / navigateur.

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const icon = (id) => `<svg class="icon"><use href="#${id}"/></svg>`;
const nf = new Intl.NumberFormat('fr-FR');
const nfCompact = new Intl.NumberFormat('fr-FR', { notation: 'compact', maximumFractionDigits: 1 });

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
  ['hideandroid', "Cacher l'émulateur", "La fenêtre de l'émulateur est cachée pendant le run"],
  ['minigui', 'Mini GUI', 'Petite fenêtre du bot'],
  ['autostart', 'Démarrage automatique', 'Le run démarre dès que le bot est prêt'],
  ['nowatchdog', 'Sans Watchdog', "Un bot planté n'est pas relancé"],
  ['debug', 'Journal debug', 'Écrit le journal détaillé'],
  ['dpiaware', 'DPI aware', 'Pour un zoom Windows au-dessus de 100 %'],
];
const SWITCH_ORDER = ['debug', 'dpiaware', 'hideandroid', 'minigui', 'nowatchdog', 'autostart'];

const ACCENTS = ['#3b82f6', '#8b5cf6', '#10b981', '#f59e0b', '#f43f5e', '#06b6d4'];

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
  stats: null,
  form: null, // { name, original: {id: value}, values: {id: value} }
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

function applyTheme() {
  const { theme = 'dark', accent = ACCENTS[0] } = app.settings;
  const resolved = theme === 'system' ? (systemDark.matches ? 'dark' : 'light') : theme;
  document.documentElement.dataset.theme = resolved;
  document.documentElement.style.setProperty('--accent', accent);
  const css = getComputedStyle(document.documentElement);
  backend?.setTitleBar?.({ color: css.getPropertyValue('--titlebar').trim(), symbolColor: css.getPropertyValue('--text-2').trim() });
  $$('#themeSeg button').forEach((b) => b.classList.toggle('active', b.dataset.theme === theme));
  $$('#accentSwatches button').forEach((b) => b.classList.toggle('active', b.dataset.color === accent));
}
systemDark.addEventListener('change', applyTheme);

// ---------------------------------------------------------------------------------------------------------------------
// navigation
// ---------------------------------------------------------------------------------------------------------------------
async function go(page) {
  if (page === app.page) return;
  if (app.form && dirtyIds().length && !confirm('Des modifications ne sont pas enregistrées. Les abandonner ?')) return;
  app.page = page;
  $$('#nav button').forEach((b) => b.classList.toggle('active', b.dataset.page === page));
  $$('.page').forEach((p) => p.classList.toggle('active', p.id === `page-${page}`));
  $('#main').scrollTop = 0;
  app.form = null;
  updateSavebar();
  if (window.FORMS[page]) await loadForm(page);
  if (page === 'profiles') renderProfiles();
  if (page === 'log') scrollLogToEnd();
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
  if (s === 'running' && !app.runSince) app.runSince = Date.now();
  if (s !== 'running' && s !== 'paused') app.runSince = null;
  if (app.connected && prev === 'off' && s === 'starting') resetStats(); // nouveau lancement : nouvelle session

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
    unsupported: 'Le pilotage du bot ne fonctionne que sous Windows. Utilisez le mode démo pour voir le GUI.',
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
  const text = app.runSince ? duration(Date.now() - app.runSince) : '—';
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

function lineMatches(line) {
  if (app.logFilter !== 'all' && line.level !== app.logFilter) return false;
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

  const box = $('#log');
  const atEnd = box.scrollHeight - box.scrollTop - box.clientHeight < 40;
  const frag = document.createDocumentFragment();
  for (const line of lines) if (lineMatches(line)) frag.append(lineElement(line));
  if (frag.childElementCount) box.querySelector('.empty')?.remove();
  box.append(frag);
  while (box.childElementCount > MAX_LOG) box.firstElementChild.remove();
  if (app.autoscroll && (atEnd || app.page !== 'log')) box.scrollTop = box.scrollHeight;

  const mini = $('#miniLog');
  mini.replaceChildren(...app.log.slice(-9).map(lineElement));

  const last = lines[lines.length - 1];
  if (last) $('#sbLast').textContent = `${last.time}  ${last.text}`;
  renderDashboard();
}

function renderLog() {
  const box = $('#log');
  const frag = document.createDocumentFragment();
  for (const line of app.log) if (lineMatches(line)) frag.append(lineElement(line));
  box.replaceChildren(frag);
  if (!box.childElementCount) {
    const empty = document.createElement('div');
    empty.className = 'empty';
    empty.textContent = app.log.length ? 'Aucune ligne ne correspond au filtre.' : 'Le journal apparaîtra ici dès que le bot écrit.';
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
// formulaires config.ini (forms.js)
// ---------------------------------------------------------------------------------------------------------------------
const isTrue = (v) => /^(1|true)$/i.test(String(v ?? '').trim());
const fieldsOf = (name) => window.FORMS[name].flatMap((card) => card.fields);

function fieldHTML(f) {
  const hint = f.hint ? `<small>${f.hint}</small>` : '';
  if (f.type === 'toggle') {
    return `<label class="row-toggle" data-field="${f.id}">
      <span class="row-text"><span>${f.label}</span>${hint}</span>
      <input type="checkbox" class="switch" data-id="${f.id}">
    </label>`;
  }
  let input;
  if (f.type === 'select') {
    input = `<select data-id="${f.id}">${f.options.map(([v, l]) => `<option value="${v}">${l}</option>`).join('')}</select>`;
  } else if (f.type === 'number') {
    input = `<input type="number" min="${f.min ?? 0}" step="${f.step ?? 1}" data-id="${f.id}">`;
  } else if (f.type === 'secret') {
    input = `<div class="input-with-btn"><input type="password" spellcheck="false" autocomplete="off" placeholder="${f.placeholder ?? ''}" data-id="${f.id}">
      <button type="button" class="icon-btn reveal" title="Afficher">${icon('i-eye')}</button></div>`;
  } else {
    input = `<input type="text" spellcheck="false" placeholder="${f.placeholder ?? ''}" data-id="${f.id}">`;
  }
  return `<div class="field" data-field="${f.id}"><label>${f.label}</label>${input}${hint}</div>`;
}

function buildForms() {
  for (const [name, cards] of Object.entries(window.FORMS)) {
    const box = $(`#page-${name} [data-cards]`);
    box.innerHTML = cards
      .map(
        (card) => `<article class="card">
          <div class="card-head"><h2>${icon(card.icon)}${card.title}</h2></div>
          ${card.note ? `<p class="note">${icon('i-alert')}<span>${card.note}</span></p>` : ''}
          <div class="fields">${card.fields.map(fieldHTML).join('')}</div>
        </article>`,
      )
      .join('');
  }
  document.addEventListener('input', onFieldInput);
  document.addEventListener('change', onFieldInput);
  document.addEventListener('click', (e) => {
    const btn = e.target.closest('.reveal');
    if (!btn) return;
    const input = btn.parentElement.querySelector('input');
    input.type = input.type === 'password' ? 'text' : 'password';
  });
}

async function loadForm(name) {
  const fields = fieldsOf(name);
  const res = await guard(() => backend.getConfig(fields.map((f) => f.id)));
  if (!res) return;
  const original = {};
  for (const f of fields) original[f.id] = res.values[f.id] ?? f.def ?? '';
  app.form = { name, original, values: { ...original }, exists: res.exists };
  const page = $(`#page-${name}`);
  for (const f of fields) {
    const input = page.querySelector(`[data-id="${CSS.escape(f.id)}"]`);
    if (f.type === 'toggle') input.checked = isTrue(original[f.id]);
    else input.value = original[f.id];
  }
  if (!res.exists) toast("Ce profil n'a pas encore de config.ini : lancez le bot une fois.", 'info');
  refreshDependencies();
  updateSavebar();
}

function onFieldInput(e) {
  const id = e.target.dataset?.id;
  if (!id || !app.form) return;
  const f = fieldsOf(app.form.name).find((x) => x.id === id);
  if (!f) return;
  if (f.type === 'toggle') {
    // garde l'ecriture d'origine de la cle : 1/0, ou True/False pour les options que le bot ecrit ainsi
    const style = /^(true|false)$/i.test(app.form.original[id]) ? ['True', 'False'] : ['1', '0'];
    app.form.values[id] = e.target.checked ? style[0] : style[1];
    refreshDependencies();
  } else {
    app.form.values[id] = e.target.value;
  }
  updateSavebar();
}

function refreshDependencies() {
  if (!app.form) return;
  const page = $(`#page-${app.form.name}`);
  for (const f of fieldsOf(app.form.name)) {
    if (!f.needs) continue;
    const on = f.needs.every((dep) => isTrue(app.form.values[dep]));
    const wrap = page.querySelector(`[data-field="${CSS.escape(f.id)}"]`);
    wrap.classList.toggle('disabled', !on);
    wrap.querySelectorAll('input, select, button').forEach((i) => (i.disabled = !on));
  }
}

function dirtyIds() {
  if (!app.form) return [];
  return Object.keys(app.form.values).filter((id) => String(app.form.values[id]) !== String(app.form.original[id]));
}

function updateSavebar() {
  const dirty = dirtyIds();
  $('#savebar').hidden = dirty.length === 0;
  $('#main').classList.toggle('has-savebar', dirty.length > 0);
  $('#dirtyCount').textContent = dirty.length;
}

async function saveForm() {
  const dirty = dirtyIds();
  if (!dirty.length) return;
  const values = Object.fromEntries(dirty.map((id) => [id, app.form.values[id]]));
  const res = await guard(() => backend.setConfig(values));
  if (!res) return;
  if (!res.ok) return toast(res.error, 'error');
  Object.assign(app.form.original, values);
  updateSavebar();
  toast(`${dirty.length} réglage(s) enregistré(s) dans config.ini`, 'success');
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
  $('#cmdPreview').textContent = ['MyBot.run.exe', q(f.profile || '?'), f.emulator, q(f.instance || '?'), ...flags].join(' ');
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

// ---------------------------------------------------------------------------------------------------------------------
// reglages
// ---------------------------------------------------------------------------------------------------------------------
async function applySettings(patch, message) {
  const profileChanged = patch.profile && patch.profile !== app.settings.profile;
  const info = await guard(() => backend.setSettings(patch), message);
  if (!info) return;
  setInfo(info);
  if (profileChanged) await reloadLog(info.logFile); // le journal suivi est maintenant celui du nouveau profil
}

function setInfo(info) {
  app.info = info;
  app.settings = info.settings;
  applyTheme();
  fillLaunchForm();
  $('#demoTag').hidden = !info.demo;
  $('#setupBanner').hidden = info.botFound || info.demo;
  $('#botDirPath').textContent = info.settings.botDir || 'Non défini';
  const tag = $('#botDirTag');
  tag.textContent = info.botFound ? 'Trouvé' : 'Introuvable';
  tag.className = `tag ${info.botFound ? 'ok' : 'bad'}`;
  $('#brandVersion').textContent = `v12 · GUI ${info.version}`;
  const about = [
    ['Version du GUI', info.version],
    ['Mode', info.demo ? 'Démo (bot simulé)' : 'Réel'],
    ['Plateforme', info.platform],
    ['Pilotage du bot', info.control ? 'disponible' : 'Windows uniquement'],
  ];
  $('#aboutList').innerHTML = about.map(([k]) => `<dt>${k}</dt><dd></dd>`).join('');
  $$('#aboutList dd').forEach((dd, i) => (dd.textContent = about[i][1]));
  setBotState(app.bot);
}

function buildSettings() {
  $('#accentSwatches').innerHTML = ACCENTS.map((c) => `<button data-color="${c}" style="--sw:${c}" title="${c}"></button>`).join('');
  $('#accentSwatches').addEventListener('click', (e) => {
    const c = e.target.closest('button')?.dataset.color;
    if (c) applySettings({ accent: c });
  });
  $('#themeSeg').addEventListener('click', (e) => {
    const t = e.target.closest('button')?.dataset.theme;
    if (t) applySettings({ theme: t });
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
    app.log = [];
    renderLog();
  });
  $('#logOpenFolder').addEventListener('click', () => openPath('logs'));

  $$('[data-reload]').forEach((b) => b.addEventListener('click', () => app.form && loadForm(app.form.name)));
  $('#saveBtn').addEventListener('click', saveForm);
  $('#discardBtn').addEventListener('click', () => app.form && loadForm(app.form.name));

  $('#page-profiles').addEventListener('input', updateCmdPreview);
  $('#page-profiles').addEventListener('change', updateCmdPreview);
  $('#saveLaunch').addEventListener('click', () => {
    const f = launchForm();
    if (!f.profile || !f.instance) return toast("Le profil et l'instance sont obligatoires", 'error');
    applySettings(f, 'Réglages de lancement enregistrés').then(renderProfiles);
  });
  $('#profilesRefresh').addEventListener('click', renderProfiles);

  const pages = ['dashboard', 'log', 'village', 'attack', 'notify', 'profiles', 'settings'];
  document.addEventListener('keydown', (e) => {
    if (e.ctrlKey && /^[1-7]$/.test(e.key)) {
      e.preventDefault();
      go(pages[Number(e.key) - 1]);
    }
    if (e.ctrlKey && e.key.toLowerCase() === 's' && app.form) {
      e.preventDefault();
      saveForm();
    }
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
  setInfo(info);
  await reloadLog(info.logFile);
  unsubscribe = [
    backend.onLog(appendLog),
    backend.onLogFile(showLogFile),
    backend.onState(setBotState),
  ];
  setBotState(await backend.state());
  app.connected = true;
}

// repart de l'historique du processus principal (la fin du journal courant) avec des compteurs a zero
async function reloadLog(logFile) {
  const history = await backend.logHistory();
  app.log = [];
  resetStats();
  $('#miniLog').replaceChildren();
  if (history.length) appendLog(history);
  renderLog();
  renderDashboard();
  showLogFile(logFile);
}

function showLogFile(name) {
  $('#sbFile').textContent = name || 'aucun journal';
  $('#logFileName').textContent = name ? `Suivi en direct de ${name}` : 'Suivi en direct de Profiles\\<profil>\\Logs';
}

async function startDemo() {
  backend = new window.DemoBackend(app.info);
  await connect();
  toast('Mode démo : cliquez sur « Ouvrir le bot » puis « Démarrer »', 'info');
}

async function init() {
  buildResourceTiles();
  buildForms();
  buildSwitches();
  buildSettings();
  wire();
  if (!backend) backend = new window.DemoBackend(); // page ouverte dans un navigateur
  await connect();
  renderDashboard();
  updateUptime();
}

init();
