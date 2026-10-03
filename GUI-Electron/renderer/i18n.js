'use strict';
// Langue de l'interface : Reglages > Langue de l'interface (reglage `language` du GUI : 'fr' ou 'en').
//
// Les textes de la page sont ecrits en francais (index.html, app.js, form-engine.js, forms/*.js). En anglais, ce script
// remplace chaque texte affiche par sa traduction (i18n-en.js) : les noeuds texte et les attributs title, placeholder et
// aria-label de la page statique, puis tout ce qui est construit ensuite (pages de form-engine.js, toasts, notes,
// etats...) grace a un MutationObserver. Le texte d'origine est garde a part (WeakMap) : repasser en francais le remet
// tel quel, sans recharger la page. confirm() traduit aussi son message.
//
// Jamais traduits : le journal du bot, les noms de profils et de strategies, les chemins et les fichiers, les valeurs
// des champs (seuls les noeuds texte et ces trois attributs le sont, jamais `value`), et tout element translate="no".
//
// Ajouter un texte a l'interface : l'ecrire en francais, puis sa traduction dans i18n-en.js (`strings` pour un texte
// fixe, `patterns` pour un texte avec une partie variable : nombre, nom de profil...).
(function () {
  const DICTIONARIES = { en: window.I18N_EN };
  const LANGS = ['fr', ...Object.keys(DICTIONARIES).filter((l) => DICTIONARIES[l])];
  const STORE_KEY = 'mybot-gui-lang'; // langue du dernier lancement : appliquee avant que les reglages n'arrivent
  const ATTRS = ['title', 'placeholder', 'aria-label'];
  // jamais traduits, ni ce qu'ils contiennent : lignes du journal, noms de profils et de strategies, notes de version,
  // valeurs du tableau de bord (la ligue est lue dans le journal)
  // (le texte d'un textarea est sa valeur : jamais traduit non plus, voir setText ; son placeholder l'est)
  const SKIP = [
    'script', 'style', 'svg', '[translate="no"]', '.line', '#sbLast', '#updNotes', '.tile-value',
    '.strategy-name', '.strategy-first', '#pillProfile', '#pillInstance', '#heroProfile', '#heroInstance',
    '.profile-card strong', '.profile-card .avatar',
  ].join(', ');
  // une valeur (chemin, fichier, notes, instance) ou un texte fixe : seulement les textes fixes du dictionnaire
  const EXACT = ['code', '#sbFile', '#strategyNotes', '.profile-info'].join(', ');
  const TEXT = 3;
  const ELEMENT = 1;

  // ------------------------------------------------------------------ dictionnaires
  const norm = (s) => s.replace(/\s+/g, ' ').trim();
  const HAS_LETTER = /\p{L}/u;

  function compile(raw) {
    const strings = new Map(Object.entries(raw.strings ?? {}).map(([k, v]) => [norm(k), v]));
    const contexts = (raw.contexts ?? []).map(([sel, map]) => [sel, new Map(Object.entries(map).map(([k, v]) => [norm(k), v]))]);
    const contextKeys = new Set(contexts.flatMap(([, map]) => [...map.keys()]));
    return { strings, contexts, contextKeys, patterns: raw.patterns ?? [] };
  }

  const compiled = {};
  const dictOf = (l) => (l === 'fr' || !DICTIONARIES[l] ? null : (compiled[l] ??= compile(DICTIONARIES[l])));

  // la traduction d'un texte deja normalise, ou null ; el = l'element qui l'affiche (textes qui dependent de l'endroit)
  function lookup(dict, key, el, exact) {
    if (el && dict.contextKeys.has(key)) {
      for (const [sel, map] of dict.contexts) if (map.has(key) && el.closest(sel)) return map.get(key);
    }
    const fixed = dict.strings.get(key);
    if (fixed !== undefined) return fixed;
    if (exact) return null;
    for (const [re, rep] of dict.patterns) {
      const m = re.exec(key);
      if (!m) continue;
      if (typeof rep === 'function') return rep(m, (s) => part(dict, s));
      // $1 : la partie variable telle quelle ; {1} : la partie variable traduite
      return rep.replace(/\$(\d)|\{(\d)\}/g, (_, raw, tr) => (raw ? m[raw] ?? '' : part(dict, m[tr] ?? '')));
    }
    return null;
  }
  const part = (dict, s) => lookup(dict, norm(s), null, false) ?? s;

  // la traduction d'un texte affiche (espaces de debut et de fin gardes), ou null s'il n'en a pas
  function translateText(dict, text, el, exact) {
    if (!dict || !HAS_LETTER.test(text)) return null;
    const out = lookup(dict, norm(text), el, exact);
    if (out === null) return null;
    return text.match(/^\s*/)[0] + out + text.match(/\s*$/)[0];
  }

  // ------------------------------------------------------------------ la page
  let lang = 'fr';
  let dict = null;
  const texts = new WeakMap(); // noeud texte -> { src: texte d'origine, out: texte affiche }
  const attrs = new WeakMap(); // element -> { attribut: { src, out } }

  function setText(node, exact) {
    if (node.parentElement?.tagName === 'TEXTAREA') return;
    const rec = texts.get(node);
    if (rec && node.data === rec.out) return; // deja traduit
    const out = translateText(dict, node.data, node.parentElement, exact);
    if (out === null || out === node.data) {
      if (rec) texts.delete(node);
      return;
    }
    texts.set(node, { src: node.data, out });
    node.data = out;
  }

  function setAttrs(el, exact) {
    for (const name of ATTRS) {
      const value = el.getAttribute(name);
      if (value === null) continue;
      let recs = attrs.get(el);
      if (recs?.[name]?.out === value) continue;
      const out = translateText(dict, value, el, exact);
      if (out === null || out === value) {
        if (recs) delete recs[name];
        continue;
      }
      if (!recs) attrs.set(el, (recs = {}));
      recs[name] = { src: value, out };
      el.setAttribute(name, out);
    }
  }

  // un element et tout ce qu'il contient
  function visit(el, exact) {
    if (el.matches(SKIP)) return;
    exact = exact || el.matches(EXACT);
    setAttrs(el, exact);
    for (let n = el.firstChild; n; n = n.nextSibling) {
      if (n.nodeType === TEXT) setText(n, exact);
      else if (n.nodeType === ELEMENT) visit(n, exact);
    }
  }

  // un noeud ajoute ou modifie apres coup
  function apply(node) {
    if (!dict || !node.isConnected) return;
    const parent = node.parentElement;
    if (parent?.closest(SKIP)) return;
    const exact = Boolean(parent?.closest(EXACT));
    if (node.nodeType === TEXT) setText(node, exact);
    else if (node.nodeType === ELEMENT) visit(node, exact);
  }

  // remet le francais d'origine (sauf ce que la page a change entre-temps : c'est deja du francais)
  function restore(el) {
    const recs = attrs.get(el);
    if (recs) {
      for (const [name, r] of Object.entries(recs)) if (el.getAttribute(name) === r.out) el.setAttribute(name, r.src);
      attrs.delete(el);
    }
    for (let n = el.firstChild; n; n = n.nextSibling) {
      if (n.nodeType === TEXT) {
        const r = texts.get(n);
        if (!r) continue;
        if (n.data === r.out) n.data = r.src;
        texts.delete(n);
      } else if (n.nodeType === ELEMENT) restore(n);
    }
  }

  const observer =
    typeof MutationObserver === 'undefined'
      ? null
      : new MutationObserver((records) => {
          for (const r of records) {
            if (r.type === 'childList') r.addedNodes.forEach(apply);
            else if (r.type === 'characterData') apply(r.target);
            else if (dict && r.target.isConnected && !r.target.closest(SKIP)) setAttrs(r.target, Boolean(r.target.closest(EXACT)));
          }
          observer.takeRecords(); // les changements faits ici : deja traduits
        });

  function setLang(next) {
    next = LANGS.includes(next) ? next : 'fr';
    try {
      localStorage.setItem(STORE_KEY, next);
    } catch {
      // stockage indisponible : la langue arrive avec les reglages
    }
    document.documentElement.lang = next;
    if (next === lang) return;
    if (dict) {
      observer.disconnect();
      restore(document.body);
    }
    lang = next;
    dict = dictOf(next);
    if (dict) {
      visit(document.body, false);
      observer.observe(document.body, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ATTRS });
    }
    document.dispatchEvent(new CustomEvent('langchange', { detail: next }));
  }

  // un texte qui ne passe pas par la page (confirm...) ; translate() rend null quand il n'y a pas de traduction
  const translate = (text, l = lang) => translateText(dictOf(l), String(text), null, false);
  const t = (text, l = lang) => translate(text, l) ?? String(text);

  if (typeof window.confirm === 'function') {
    const nativeConfirm = window.confirm;
    window.confirm = (message) => nativeConfirm.call(window, t(message ?? ''));
  }

  window.I18n = {
    langs: LANGS,
    get lang() {
      return lang;
    },
    setLang,
    t,
    translate,
    apply,
  };

  // la langue du dernier lancement, tout de suite (les reglages la confirment une fois lus)
  if (typeof document !== 'undefined' && document.body) {
    let saved = 'fr';
    try {
      saved = localStorage.getItem(STORE_KEY) || 'fr';
    } catch {
      // stockage indisponible
    }
    setLang(saved);
  }
})();
