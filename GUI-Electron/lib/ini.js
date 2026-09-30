// Lecture / ecriture des .ini du bot sans rien casser.
// Le bot ecrit config.ini en UTF-16 LE avec BOM (_Ini_Save, FO_UTF16_LE) et MultiBot-Profiles.ini en ANSI (IniWrite) :
// l'encodage est detecte au BOM et conserve a l'ecriture. Les lignes, commentaires et l'ordre des cles restent tels quels,
// seules les valeurs demandees changent. Sections et cles sont insensibles a la casse, comme IniRead d'AutoIt.
const fs = require('node:fs');

function decode(buf) {
  if (buf.length >= 2 && buf[0] === 0xff && buf[1] === 0xfe) return { text: buf.subarray(2).toString('utf16le'), encoding: 'utf16le' };
  if (buf.length >= 3 && buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf) return { text: buf.subarray(3).toString('utf8'), encoding: 'utf8bom' };
  return { text: buf.toString('latin1'), encoding: 'latin1' };
}

function encode(text, encoding) {
  if (encoding === 'utf16le') return Buffer.concat([Buffer.from([0xff, 0xfe]), Buffer.from(text, 'utf16le')]);
  if (encoding === 'utf8bom') return Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from(text, 'utf8')]);
  return Buffer.from(text, 'latin1');
}

const SECTION = /^\s*\[([^\]]+)\]\s*$/;
const ENTRY = /^\s*([^=;#][^=]*?)\s*=(.*)$/;

function load(file) {
  if (!fs.existsSync(file)) return { encoding: 'latin1', lines: [] };
  const { text, encoding } = decode(fs.readFileSync(file));
  return { encoding, lines: text.split(/\r?\n/) };
}

// { section: { key: value } } avec les noms en minuscules
function parse(lines) {
  const data = {};
  let section = '';
  for (const line of lines) {
    const s = SECTION.exec(line);
    if (s) {
      section = s[1].trim().toLowerCase();
      data[section] ??= {};
      continue;
    }
    const e = ENTRY.exec(line);
    if (e && section) data[section][e[1].toLowerCase()] = e[2];
  }
  return data;
}

function readAll(file) {
  return parse(load(file).lines);
}

function sectionNames(file) {
  const names = [];
  for (const line of load(file).lines) {
    const s = SECTION.exec(line);
    if (s) names.push(s[1].trim());
  }
  return names;
}

// ids = ["section/key", ...] -> { "section/key": valeur ou null }
function getValues(file, ids) {
  const data = readAll(file);
  const out = {};
  for (const id of ids) {
    const [section, key] = splitId(id);
    out[id] = data[section.toLowerCase()]?.[key.toLowerCase()] ?? null;
  }
  return out;
}

// values = { "section/key": valeur } ; les cles absentes sont ajoutees a la fin de leur section
function setValues(file, values) {
  const { encoding, lines } = load(file);
  const pending = new Map();
  for (const [id, value] of Object.entries(values)) {
    const [section, key] = splitId(id);
    const s = section.toLowerCase();
    if (!pending.has(s)) pending.set(s, { name: section, keys: new Map() });
    pending.get(s).keys.set(key.toLowerCase(), { name: key, value: String(value ?? '') });
  }

  const out = [];
  let current = null;
  const flush = () => {
    // cles de la section courante qui n'existaient pas encore
    if (!current) return;
    for (const { name, value } of current.keys.values()) out.push(`${name}=${value}`);
    pending.delete(current.id);
    current = null;
  };
  for (const line of lines) {
    const s = SECTION.exec(line);
    if (s) {
      // garde une eventuelle ligne vide de separation apres les cles ajoutees
      const blank = out.length && out[out.length - 1].trim() === '' ? out.pop() : null;
      flush();
      if (blank !== null) out.push(blank);
      const id = s[1].trim().toLowerCase();
      if (pending.has(id)) current = { id, keys: pending.get(id).keys };
      out.push(line);
      continue;
    }
    const e = ENTRY.exec(line);
    if (e && current?.keys.has(e[1].toLowerCase())) {
      out.push(`${e[1]}=${current.keys.get(e[1].toLowerCase()).value}`);
      current.keys.delete(e[1].toLowerCase());
      continue;
    }
    out.push(line);
  }
  while (out.length && out[out.length - 1] === '') out.pop();
  flush();
  for (const { name, keys } of pending.values()) {
    out.push(`[${name}]`);
    for (const { name: k, value } of keys.values()) out.push(`${k}=${value}`);
  }
  out.push('');
  fs.writeFileSync(file, encode(out.join('\r\n'), encoding));
}

function splitId(id) {
  const i = id.indexOf('/');
  if (i < 1) throw new Error(`Identifiant ini invalide: ${id} (attendu "section/cle")`);
  return [id.slice(0, i), id.slice(i + 1)];
}

module.exports = { readAll, sectionNames, getValues, setValues, decode };
