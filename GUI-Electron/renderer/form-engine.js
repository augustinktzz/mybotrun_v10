'use strict';
// Moteur des pages de reglages : construit chaque page decrite dans forms/*.js (onglets, sous-onglets, cartes, champs),
// lit les valeurs dans les .ini du profil, suit les modifications et les enregistre.
//
// Un champ a un "id" = "fichier:section/cle" (fichier config par defaut, voir lib/profile-store.js). Dans une page qui a
// un parametre (le groupe de changement de compte), "#" dans l'id est remplace par sa valeur.
//
// Types de champ
//   toggle    case a cocher ; on / off = valeurs ecrites (1 / 0 par defaut, True / False garde si la cle l'etait)
//   bit       case a cocher qui allume un bit d'un entier (bit: 1, 2, 4...) ; plusieurs champs pour le meme id
//   number    nombre ; scale = facteur entre l'affichage et le fichier (ms affichees en s : scale 1000)
//   text, secret, textarea (sep = separateur des lignes dans le fichier, "|" par defaut)
//   select    liste ; options = ["a", "b"] (valeur = rang) ou [["valeur", "libelle"], ...] ; source = liste du bot
//   radio     boutons ; memes options que select
//   radiokeys un choix parmi plusieurs cles : options = [["id", "libelle"], ...], la cle choisie vaut 1, les autres 0
//   hours     24 cases, "1|0|...|" ; days : 7 cases ; flags : une case par libelle de items, "1|0|...|"
//   pipeselects  count listes dont les choix forment une seule valeur "a|b|c" (ordre de deploiement)
//   range     curseur (min, max, step, suffix)
//   row       champs sur une ligne : { type: 'row', label, fields: [...] }
//   info      texte : { type: 'info', text }
// needs  = conditions pour que le champ soit actif ; showIf = conditions pour qu'il soit visible.
//          "id" (case cochee), { id, eq: 'v' }, { id, ne: 'v' }, { id, in: ['a', 'b'] }, { id, gt: 0 }

(function () {
  const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const iconHTML = (id) => `<svg class="icon"><use href="#${id}"/></svg>`;
  const isTrue = (v) => /^(1|true)$/i.test(String(v ?? '').trim());
  const DAYS = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];

  const registry = []; // tous les champs, l'index sert d'attribut data-f
  const pages = {}; // nom -> { def, fields: [indices], param }
  let ctx = null; // { backend, toast, guard, onDirty }
  let form = null; // { name, original, values, param }
  const lists = {}; // listes du bot deja chargees (scripts, languages, profiles)

  // ------------------------------------------------------------------ options et ids
  function normOptions(f) {
    const src = f.source ? lists[f.source] ?? [] : f.options ?? [];
    return src.map((o, i) => (Array.isArray(o) ? [String(o[0]), o[1]] : f.source ? [String(o), o] : [String(i), o]));
  }

  const rid = (id, param) => (param === undefined ? id : id.replace('#', param));
  const idOf = (f) => (f.id ? rid(f.id, form?.param) : undefined);

  function fieldIds(f) {
    if (f.type === 'row') return f.fields.flatMap(fieldIds);
    if (f.type === 'radiokeys') return f.options.map(([id]) => id);
    if (f.type === 'info' || !f.id) return [];
    return [f.id];
  }

  function defaultOf(f) {
    if (f.def !== undefined) return String(f.def);
    switch (f.type) {
      case 'toggle':
        return f.off ?? '0';
      case 'bit':
      case 'number':
      case 'range':
        return '0';
      case 'select':
      case 'radio':
        return normOptions(f)[0]?.[0] ?? '';
      case 'hours':
        return '1|'.repeat(24);
      case 'days':
        return '1|'.repeat(7);
      case 'flags':
        return '0|'.repeat(f.items.length);
      case 'pipeselects':
        return f.options.slice(0, f.count).map(([v]) => v).join('|');
      default:
        return '';
    }
  }

  // ------------------------------------------------------------------ HTML des champs
  function label(f) {
    return f.label ? `<label>${f.label}</label>` : '';
  }

  function hint(f) {
    return f.hint ? `<small>${f.hint}</small>` : '';
  }

  function fieldHTML(f, compact = f.compact ?? false) {
    const fi = registry.push(f) - 1;
    f._fi = fi;
    const did = f.id ? ` data-id="${esc(f.id)}"` : ''; // pour retrouver un champ (tests, debug)
    const wrap = (inner, cls = 'field') =>
      `<div class="${cls}${compact ? ' compact' : ''}${f.wide ? ' wide' : ''}" data-wrap="${fi}"${did}>${inner}</div>`;
    switch (f.type) {
      case 'toggle':
      case 'bit':
        return `<label class="row-toggle${compact ? ' compact' : ''}${f.wide ? ' wide' : ''}" data-wrap="${fi}"${did}>
          <span class="row-text"><span>${f.label ?? ''}</span>${hint(f)}</span>
          <input type="checkbox" class="switch" data-f="${fi}"></label>`;
      case 'number':
        return wrap(`${label(f)}<div class="input-suffix"><input type="number" data-f="${fi}" min="${f.min ?? 0}"${f.max !== undefined ? ` max="${f.max}"` : ''} step="${f.step ?? 1}">${f.suffix ? `<span>${f.suffix}</span>` : ''}</div>${hint(f)}`);
      case 'text':
        return wrap(`${label(f)}<input type="text" spellcheck="false" data-f="${fi}" placeholder="${esc(f.placeholder)}"${f.readonly ? ' readonly tabindex="-1"' : ''}>${hint(f)}`);
      case 'secret':
        return wrap(`${label(f)}<div class="input-with-btn"><input type="password" spellcheck="false" autocomplete="off" data-f="${fi}" placeholder="${esc(f.placeholder)}">
          <button type="button" class="icon-btn reveal" title="Afficher">${iconHTML('i-eye')}</button></div>${hint(f)}`);
      case 'textarea':
        return wrap(`${label(f)}<textarea rows="${f.rows ?? 4}" spellcheck="false" data-f="${fi}" placeholder="${esc(f.placeholder)}"></textarea>${hint(f)}`);
      case 'select':
        return wrap(`${label(f)}<select data-f="${fi}"></select>${hint(f)}`);
      case 'radio':
      case 'radiokeys':
        return wrap(`${label(f)}<div class="segmented seg-wrap" data-f="${fi}">${(f.type === 'radio' ? normOptions(f) : f.options)
          .map(([v, l]) => `<button type="button" data-v="${esc(v)}">${l}</button>`)
          .join('')}</div>${hint(f)}`);
      case 'pipeselects':
        return wrap(`${label(f)}<div class="pipe-selects" data-f="${fi}">${Array.from({ length: f.count }, (_, i) => `<label><span>${i + 1}.</span><select data-i="${i}"></select></label>`).join('')}</div>${hint(f)}`);
      case 'range':
        return wrap(`${label(f)}<div class="range-row"><input type="range" data-f="${fi}" min="${f.min ?? 0}" max="${f.max ?? 100}" step="${f.step ?? 1}"><output data-out="${fi}"></output></div>${hint(f)}`);
      case 'hours':
        return wrap(`${label(f)}<div class="hours" data-f="${fi}">${Array.from({ length: 24 }, (_, h) => `<button type="button" data-i="${h}">${h}</button>`).join('')}</div>
          <div class="hours-actions"><button type="button" class="link" data-all="${fi}">Toutes</button><button type="button" class="link" data-none="${fi}">Aucune</button></div>${hint(f)}`);
      case 'days':
        return wrap(`${label(f)}<div class="hours days" data-f="${fi}">${DAYS.map((d, i) => `<button type="button" data-i="${i}">${d}</button>`).join('')}</div>${hint(f)}`);
      case 'flags':
        return wrap(`${label(f)}<div class="flags" data-f="${fi}">${f.items.map((it, i) => `<button type="button" data-i="${i}">${it}</button>`).join('')}</div>
          <div class="hours-actions"><button type="button" class="link" data-all="${fi}">Tout</button><button type="button" class="link" data-none="${fi}">Rien</button></div>${hint(f)}`);
      case 'row':
        return `<div class="field-inline${f.wide ? ' wide' : ''}" data-wrap="${fi}">${f.label ? `<div class="inline-label">${f.label}</div>` : ''}<div class="inline-fields">${f.fields.map((x) => fieldHTML(x, true)).join('')}</div>${hint(f)}</div>`;
      case 'info':
        return `<p class="field-info${f.warn ? ' warn' : ''}${f.wide ? ' wide' : ''}" data-wrap="${fi}">${f.warn ? iconHTML('i-alert') : iconHTML('i-info')}<span>${f.text}</span></p>`;
      default:
        return `<p class="field-info">Type inconnu : ${esc(f.type)}</p>`;
    }
  }

  function cardHTML(card) {
    return `<article class="card${card.wide ? ' card-wide' : ''}">
      <div class="card-head"><h2>${iconHTML(card.icon ?? 'i-sliders')}${card.title}</h2>${card.tag ? `<span class="tag">${card.tag}</span>` : ''}</div>
      ${card.note ? `<p class="note">${iconHTML('i-alert')}<span>${card.note}</span></p>` : ''}
      <div class="fields" style="--cols:${card.cols ?? 1}">${card.fields.map((f) => fieldHTML(f)).join('')}</div>
    </article>`;
  }

  // ------------------------------------------------------------------ construction d'une page
  function build(name, def, container) {
    const start = registry.length;
    const section = document.createElement('section');
    section.className = 'page form-page';
    section.id = `page-${name}`;
    section.dataset.form = name;
    const leafTabs = [];
    const tabsHTML = def.tabs
      .map((t, i) => `<button class="tab${i === 0 ? ' active' : ''}" data-tab="${t.id}">${t.icon ? iconHTML(t.icon) : ''}<span>${t.label}</span></button>`)
      .join('');
    const panels = def.tabs
      .map((t, i) => {
        if (t.tabs) {
          const sub = t.tabs.map((s, j) => `<button class="${j === 0 ? 'active' : ''}" data-sub="${s.id}">${s.label}</button>`).join('');
          const subPanels = t.tabs
            .map((s, j) => {
              leafTabs.push(`${t.id}.${s.id}`);
              return `<div class="tab-panel form-grid${j === 0 ? ' active' : ''}" data-panel="${t.id}.${s.id}">${s.intro ? `<p class="tab-intro wide">${s.intro}</p>` : ''}${s.cards.map(cardHTML).join('')}</div>`;
            })
            .join('');
          return `<div class="tab-group${i === 0 ? ' active' : ''}" data-group="${t.id}"><div class="segmented subtabs">${sub}</div>${subPanels}</div>`;
        }
        leafTabs.push(t.id);
        return `<div class="tab-group${i === 0 ? ' active' : ''}" data-group="${t.id}"><div class="tab-panel form-grid active" data-panel="${t.id}">${t.intro ? `<p class="tab-intro wide">${t.intro}</p>` : ''}${t.cards.map(cardHTML).join('')}</div></div>`;
      })
      .join('');
    // le parametre (groupe de comptes...) ne s'affiche que dans son onglet s'il en a un (param.tab)
    const paramHidden = def.param?.tab && def.param.tab !== def.tabs[0].id ? ' hidden' : '';
    const param = def.param
      ? `<label class="param"${paramHidden}>${def.param.label}<select data-param="${name}">${def.param.options.map(([v, l]) => `<option value="${esc(v)}">${l}</option>`).join('')}</select></label>`
      : '';
    section.innerHTML = `<div class="page-head">
        <div><h1>${def.title}</h1><p class="sub">${def.sub ?? ''}</p></div>
        <div class="head-actions">${param}<button class="btn" data-reload="${name}">${iconHTML('i-undo')}Recharger</button></div>
      </div>
      <div class="tabbar">${tabsHTML}</div>
      ${panels}`;
    container.append(section);
    pages[name] = { def, fields: registry.slice(start).map((_, k) => start + k), param: def.param?.options[0]?.[0] };
    return section;
  }

  // ------------------------------------------------------------------ valeurs <-> controles
  const pageFields = (name) => pages[name].fields.map((i) => registry[i]);

  function isOn(f, v) {
    if (f.type === 'bit') return (parseInt(v, 10) & f.bit) !== 0;
    if (f.on !== undefined) return String(v) === String(f.on);
    return isTrue(v) || (/^\d+$/.test(String(v)) && Number(v) > 0);
  }

  function splitList(v, n) {
    const parts = String(v ?? '').split('|');
    return Array.from({ length: n }, (_, i) => isTrue(parts[i]));
  }

  function joinList(bools, style) {
    return bools.map((b) => (style === 'bool' ? (b ? 'True' : 'False') : b ? '1' : '0')).join('|') + '|';
  }

  function listStyle(f) {
    return f.style ?? (/true|false/i.test(form.original[idOf(f)] ?? '') ? 'bool' : 'num');
  }

  function setControl(f, root) {
    const fi = f._fi;
    const el = root.querySelector(`[data-f="${fi}"]`);
    if (f.type === 'row') return f.fields.forEach((x) => setControl(x, root));
    if (!el) return;
    const v = form.values[idOf(f)];
    switch (f.type) {
      case 'toggle':
      case 'bit':
        el.checked = isOn(f, v);
        break;
      case 'number':
        el.value = f.scale ? Number(v || 0) / f.scale : v;
        break;
      case 'textarea':
        el.value = String(v ?? '').split(f.sep ?? '|').join('\n');
        break;
      case 'select': {
        const opts = normOptions(f);
        if (v !== '' && v !== undefined && !opts.some(([o]) => o === String(v))) opts.push([String(v), `${v} (valeur actuelle)`]);
        el.innerHTML = opts.map(([o, l]) => `<option value="${esc(o)}">${esc(l)}</option>`).join('');
        el.value = String(v ?? '');
        break;
      }
      case 'radio':
        el.querySelectorAll('button').forEach((b) => b.classList.toggle('active', b.dataset.v === String(v)));
        break;
      case 'radiokeys':
        el.querySelectorAll('button').forEach((b) => b.classList.toggle('active', isTrue(form.values[rid(b.dataset.v, form.param)])));
        break;
      case 'range':
        el.value = v;
        root.querySelector(`[data-out="${fi}"]`).textContent = `${v}${f.suffix ? ` ${f.suffix}` : ''}`;
        break;
      case 'pipeselects': {
        const parts = String(v ?? '').split('|');
        const optHTML = f.options.map(([o, l]) => `<option value="${esc(o)}">${esc(l)}</option>`).join('');
        el.querySelectorAll('select').forEach((s, i) => {
          s.innerHTML = optHTML;
          s.value = parts[i] ?? '';
        });
        break;
      }
      case 'hours':
      case 'days':
      case 'flags': {
        const n = f.type === 'hours' ? 24 : f.type === 'days' ? 7 : f.items.length;
        const bools = splitList(v, n);
        el.querySelectorAll('button').forEach((b) => b.classList.toggle('active', bools[Number(b.dataset.i)]));
        break;
      }
      default:
        el.value = v ?? '';
    }
  }

  function onControl(e) {
    const el = e.target.closest('[data-f]');
    if (!el || !form) return;
    const f = registry[Number(el.dataset.f)];
    if (!f || !pages[form.name].fields.includes(f._fi)) return;
    const id = idOf(f);
    const cur = form.values[id];
    switch (f.type) {
      case 'toggle': {
        const style = f.on === undefined && /^(true|false)$/i.test(form.original[id] ?? '') ? ['True', 'False'] : [f.on ?? '1', f.off ?? '0'];
        form.values[id] = el.checked ? style[0] : style[1];
        break;
      }
      case 'bit': {
        const n = parseInt(cur, 10) || 0;
        form.values[id] = String(el.checked ? n | f.bit : n & ~f.bit);
        break;
      }
      case 'number':
        if (el.value === '') return;
        form.values[id] = f.scale ? String(Math.round(Number(el.value) * f.scale)) : el.value;
        break;
      case 'textarea':
        form.values[id] = el.value.split(/\r?\n/).join(f.sep ?? '|');
        break;
      case 'radio':
      case 'radiokeys': {
        const btn = e.target.closest('button[data-v]');
        if (!btn || e.type !== 'click') return;
        if (f.type === 'radio') form.values[id] = btn.dataset.v;
        else for (const [k] of f.options) form.values[rid(k, form.param)] = k === btn.dataset.v ? '1' : '0';
        break;
      }
      case 'hours':
      case 'days':
      case 'flags': {
        const btn = e.target.closest('button[data-i]');
        if (!btn || e.type !== 'click') return;
        const n = f.type === 'hours' ? 24 : f.type === 'days' ? 7 : f.items.length;
        const bools = splitList(cur, n);
        bools[Number(btn.dataset.i)] = !bools[Number(btn.dataset.i)];
        form.values[id] = joinList(bools, listStyle(f));
        break;
      }
      case 'range':
        form.values[id] = el.value;
        break;
      case 'pipeselects':
        if (e.type !== 'change') return;
        form.values[id] = [...el.querySelectorAll('select')].map((s) => s.value).join('|');
        break;
      default:
        form.values[id] = el.value;
    }
    const section = document.getElementById(`page-${form.name}`);
    // les champs qui partagent l'id (bits, radiokeys) se redessinent ensemble
    for (const g of pageFields(form.name)) if (g.id && (idOf(g) === id || g.type === 'radiokeys')) setControl(g, section);
    refresh();
  }

  function onAllNone(e) {
    const btn = e.target.closest('[data-all], [data-none]');
    if (!btn || !form) return;
    const f = registry[Number(btn.dataset.all ?? btn.dataset.none)];
    const n = f.type === 'hours' ? 24 : f.items.length;
    form.values[idOf(f)] = joinList(Array(n).fill(btn.dataset.all !== undefined), listStyle(f));
    setControl(f, document.getElementById(`page-${form.name}`));
    refresh();
  }

  // ------------------------------------------------------------------ conditions
  function test(cond) {
    if (typeof cond === 'string') {
      const f = pageFields(form.name).find((x) => x.id === cond);
      return f ? isOn(f, form.values[rid(cond, form.param)]) : isTrue(form.values[rid(cond, form.param)]);
    }
    const v = String(form.values[rid(cond.id, form.param)] ?? '');
    if (cond.eq !== undefined) return v === String(cond.eq);
    if (cond.ne !== undefined) return v !== String(cond.ne);
    if (cond.in) return cond.in.map(String).includes(v);
    if (cond.gt !== undefined) return Number(v) > cond.gt;
    return isTrue(v);
  }

  function refresh() {
    const section = document.getElementById(`page-${form.name}`);
    for (const f of pageFields(form.name)) {
      if (!f.needs && !f.showIf) continue;
      const wrap = section.querySelector(`[data-wrap="${f._fi}"]`);
      if (!wrap) continue;
      if (f.showIf) wrap.hidden = !f.showIf.every(test);
      if (f.needs) {
        const on = f.needs.every(test);
        wrap.classList.toggle('disabled', !on);
        wrap.querySelectorAll('input, select, textarea, button').forEach((i) => (i.disabled = !on));
      }
    }
    ctx.onDirty(dirty().length);
  }

  // ------------------------------------------------------------------ chargement / enregistrement
  async function loadLists(name) {
    const sources = new Set(pageFields(name).filter((f) => f.source).map((f) => f.source));
    for (const s of sources) {
      if (s === 'profiles') lists.profiles = ((await ctx.backend.listProfiles()) ?? []).map((p) => p.name);
      else lists[s] = (await ctx.backend.list(s)) ?? [];
    }
  }

  async function load(name) {
    const fields = pageFields(name);
    await loadLists(name);
    const param = pages[name].param;
    const ids = [...new Set(fields.flatMap(fieldIds).map((id) => rid(id, param)))];
    const res = await ctx.guard(() => ctx.backend.getConfig(ids));
    if (!res) return;
    const original = {};
    for (const f of fields) {
      if (f.type === 'radiokeys') for (const [id] of f.options) original[rid(id, param)] = res.values[rid(id, param)] ?? '0';
      else if (f.id) original[rid(f.id, param)] = res.values[rid(f.id, param)] ?? defaultOf(f);
    }
    form = { name, original, values: { ...original }, param, files: res.files ?? {} };
    const section = document.getElementById(`page-${name}`);
    for (const f of fields) setControl(f, section);
    refresh();
    if (res.files && res.files.config === false) ctx.toast("Ce profil n'a pas encore de config.ini : lancez le bot une fois avec ce profil.", 'info');
  }

  function dirty() {
    if (!form) return [];
    return Object.keys(form.values).filter((id) => String(form.values[id]) !== String(form.original[id]));
  }

  async function save() {
    const ids = dirty();
    if (!ids.length) return 0;
    const values = Object.fromEntries(ids.map((id) => [id, form.values[id]]));
    // cles calculees par la page (totaux des armees rapides, paquet du distributeur...), ecrites avec le reste
    const derive = pages[form.name].def.derive;
    if (derive) {
      const changed = new Set(ids.map((id) => id.replace(/^config:/, '')));
      Object.assign(values, derive((id) => form.values[rid(id, form.param)], changed));
    }
    const res = await ctx.guard(() => ctx.backend.setConfig(values));
    if (!res) return -1;
    if (!res.ok) {
      ctx.toast(res.error, 'error');
      return -1;
    }
    for (const [id, v] of Object.entries(values)) {
      form.original[id] = v;
      if (id in form.values) form.values[id] = v;
    }
    for (const f of pageFields(form.name)) setControl(f, document.getElementById(`page-${form.name}`));
    refresh();
    return ids.length;
  }

  function leave() {
    form = null;
    ctx.onDirty(0);
  }

  // ------------------------------------------------------------------ onglets
  function wireTabs(section) {
    section.addEventListener('click', (e) => {
      const tab = e.target.closest('.tabbar .tab');
      if (tab) {
        section.querySelectorAll('.tabbar .tab').forEach((t) => t.classList.toggle('active', t === tab));
        section.querySelectorAll('.tab-group').forEach((g) => g.classList.toggle('active', g.dataset.group === tab.dataset.tab));
        const paramTab = pages[section.dataset.form].def.param?.tab;
        if (paramTab) section.querySelector('.param').hidden = tab.dataset.tab !== paramTab;
        return;
      }
      const sub = e.target.closest('.subtabs button');
      if (sub) {
        const group = sub.closest('.tab-group');
        group.querySelectorAll('.subtabs button').forEach((b) => b.classList.toggle('active', b === sub));
        group.querySelectorAll('.tab-panel').forEach((p) => p.classList.toggle('active', p.dataset.panel === `${group.dataset.group}.${sub.dataset.sub}`));
      }
    });
    section.querySelector('[data-param]')?.addEventListener('change', async (e) => {
      const name = e.target.dataset.param;
      if (form?.name === name && dirty().length && !confirm('Des modifications ne sont pas enregistrées. Les abandonner ?')) {
        e.target.value = pages[name].param;
        return;
      }
      pages[name].param = e.target.value;
      await load(name);
    });
  }

  function init(context, defs, container, before) {
    ctx = context;
    for (const [name, def] of Object.entries(defs)) {
      const section = build(name, def, container);
      container.insertBefore(section, before);
      wireTabs(section);
    }
    document.addEventListener('change', onControl);
    document.addEventListener('input', (e) => {
      const el = e.target.closest('[data-f]');
      if (el && /^(INPUT|TEXTAREA)$/.test(el.tagName) && el.type !== 'checkbox') onControl(e);
    });
    document.addEventListener('click', (e) => {
      if (e.target.closest('.segmented[data-f] button, .hours[data-f] button, .flags[data-f] button')) onControl(e);
      else onAllNone(e);
      const reveal = e.target.closest('.reveal');
      if (reveal) {
        const input = reveal.parentElement.querySelector('input');
        input.type = input.type === 'password' ? 'text' : 'password';
      }
    });
  }

  // toutes les cles lues ou ecrites par les pages (pour les verifications)
  function allIds() {
    return [...new Set(registry.flatMap(fieldIds))];
  }

  window.FormEngine = { init, load, save, dirty, leave, has: (name) => Boolean(pages[name]), current: () => form?.name, allIds, isTrue };
})();
