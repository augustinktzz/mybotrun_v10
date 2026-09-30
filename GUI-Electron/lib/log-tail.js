// Suit le journal du bot : Profiles\<profil>\Logs\AAAA-MM-JJ_HH.MM.SS.log (CreateLogFile.au3).
// Le bot ouvre un nouveau fichier toutes les une a deux heures : le plus recent (le nom est chronologique) est suivi,
// et on bascule dessus des qu'il apparait. Chaque ligne a la forme
//     0: L [2026-09-30 14:00:00.123] message        (L = journal, D = debug ; 0/2 = fenetre du bot reduite ou non)
// Le fichier ne garde pas la couleur du message : le niveau est devine a partir du texte.
const fs = require('node:fs');
const path = require('node:path');
const { EventEmitter } = require('node:events');

const LOG_NAME = /^\d{4}-\d{2}-\d{2}_\d{2}\.\d{2}\.\d{2}\.log$/;
const LINE = /^\d+:\s+([LD])\s+\[(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})(?:\.\d+)?\]\s?(.*)$/;
const BACKLOG_BYTES = 64 * 1024; // a l'ouverture : la fin du fichier seulement

function levelOf(text, debug) {
  if (debug) return 'debug';
  if (/error|erreur|fail|cannot|can't|unable|exception|crash/i.test(text)) return 'error';
  if (/warn|attention|not found|timeout|retry|restart/i.test(text)) return 'warn';
  if (/\[G\]:|\[League\]:|success|complete|finished|collected|donated|upgraded|won|stars/i.test(text)) return 'success';
  return 'info';
}

function parseLine(raw) {
  const m = LINE.exec(raw);
  if (!m) return { time: '', level: 'info', text: raw };
  const debug = m[1] === 'D';
  return { time: m[3], level: levelOf(m[4], debug), text: m[4] };
}

class LogTail extends EventEmitter {
  constructor() {
    super();
    this.dir = '';
    this.file = '';
    this.offset = 0;
    this.partial = '';
    this.skipCut = false;
    this.timer = null;
  }

  start(logsDir) {
    this.stop();
    this.dir = logsDir;
    this.timer = setInterval(() => this.poll(), 750);
    this.poll();
  }

  stop() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    this.file = '';
    this.offset = 0;
    this.partial = '';
  }

  newestLog() {
    try {
      const names = fs.readdirSync(this.dir).filter((n) => LOG_NAME.test(n)).sort();
      return names.length ? path.join(this.dir, names[names.length - 1]) : '';
    } catch {
      return '';
    }
  }

  poll() {
    const newest = this.newestLog();
    if (!newest) return;
    if (newest !== this.file) {
      const first = this.file === '';
      this.file = newest;
      this.partial = '';
      const size = fs.statSync(newest).size;
      // au premier fichier, reprend la fin du journal ; un fichier qui vient d'etre cree se lit en entier
      this.offset = first ? Math.max(0, size - BACKLOG_BYTES) : 0;
      this.skipCut = this.offset > 0; // la premiere ligne lue est coupee en son milieu
      this.emit('file', path.basename(newest));
    }
    let size;
    try {
      size = fs.statSync(this.file).size;
    } catch {
      return;
    }
    if (size < this.offset) this.offset = 0; // fichier tronque
    if (size === this.offset) return;

    const fd = fs.openSync(this.file, 'r');
    try {
      const buf = Buffer.alloc(size - this.offset);
      fs.readSync(fd, buf, 0, buf.length, this.offset);
      this.offset = size;
      const chunks = (this.partial + buf.toString('latin1')).split(/\r?\n/);
      this.partial = chunks.pop();
      if (this.skipCut) {
        chunks.shift();
        this.skipCut = false;
      }
      const lines = chunks.filter((l) => l.trim() !== '').map(parseLine);
      if (lines.length) this.emit('lines', lines);
    } finally {
      fs.closeSync(fd);
    }
  }
}

module.exports = { LogTail, parseLine };
