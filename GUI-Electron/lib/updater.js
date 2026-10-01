// Updates of the whole application (interface and bot), from the GitHub Releases of the project.
//
// The installed application updates itself with electron-updater: the Windows installer (NSIS, downloading only the
// blocks that changed) and the Linux AppImage. The bot comes inside the application, so the same update brings the new
// bot too; BotInstall then copies it into the bot folder (see bot-install.js) without touching the profiles.
//
// Run from the sources (Lancer MyBot GUI.bat / .sh) there is nothing to install: a check only tells which version is
// the latest on GitHub.
const { EventEmitter } = require('node:events');

const REPO = { owner: 'augustinktzz', repo: 'mybotrun_v10' }; // keep in step with "build.publish" in package.json
const RELEASES_PAGE = `https://github.com/${REPO.owner}/${REPO.repo}/releases`;
const CHECK_EVERY = 6 * 60 * 60 * 1000;

// the release notes of GitHub come as HTML: plain text for the page
function notesText(notes) {
  if (Array.isArray(notes)) return notes.map((n) => `${n.version}\n${notesText(n.note)}`).join('\n\n');
  return String(notes ?? '')
    .replace(/<\s*br\s*\/?>/gi, '\n')
    .replace(/<\s*li[^>]*>/gi, '• ')
    .replace(/<\/\s*(p|li|h\d|ul|ol|div)\s*>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, '&')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

// semver-ish comparison of "12.0.1" and "12.0.0-beta.2": > 0 when a is newer
function compareVersions(a, b) {
  const parse = (v) => {
    const [main, pre = ''] = String(v).replace(/^v/, '').split('-');
    return { nums: main.split('.').map((n) => Number(n) || 0), pre };
  };
  const x = parse(a);
  const y = parse(b);
  for (let i = 0; i < 3; i++) if ((x.nums[i] ?? 0) !== (y.nums[i] ?? 0)) return (x.nums[i] ?? 0) - (y.nums[i] ?? 0);
  if (x.pre === y.pre) return 0;
  if (!x.pre) return 1;
  if (!y.pre) return -1;
  return x.pre < y.pre ? -1 : 1;
}

class Updater extends EventEmitter {
  // app: Electron's app; options: { autoCheck, beta }
  constructor(app, options) {
    super();
    this.app = app;
    this.options = { autoCheck: true, beta: false, ...options };
    this.state = { phase: 'idle' };
    this.timer = null;
    this.updater = null;

    // electron-updater only works in the installed application: on Windows, and on Linux as an AppImage
    this.installed = app.isPackaged && (process.platform === 'win32' || Boolean(process.env.APPIMAGE));
    if (!this.installed) return;

    const { autoUpdater } = require('electron-updater');
    this.updater = autoUpdater;
    autoUpdater.autoDownload = false;
    autoUpdater.autoInstallOnAppQuit = true; // a downloaded update left aside is installed when the application quits
    autoUpdater.allowPrerelease = this.options.beta;
    autoUpdater.logger = null;
    autoUpdater.on('checking-for-update', () => this.set({ phase: 'checking' }));
    autoUpdater.on('update-available', (info) => this.set(this.available(info)));
    autoUpdater.on('update-not-available', () => this.set({ phase: 'latest', checkedAt: Date.now() }));
    autoUpdater.on('download-progress', (p) =>
      this.set({ ...this.state, phase: 'downloading', percent: p.percent, transferred: p.transferred, total: p.total, speed: p.bytesPerSecond }),
    );
    autoUpdater.on('update-downloaded', (info) => this.set({ ...this.available(info), phase: 'downloaded' }));
    autoUpdater.on('error', (err) => this.set({ ...this.state, phase: 'error', error: this.explain(err) }));
  }

  available(info) {
    return { phase: 'available', version: info.version, date: info.releaseDate, notes: notesText(info.releaseNotes), checkedAt: Date.now() };
  }

  explain(err) {
    const msg = String(err?.message ?? err);
    if (/404|Unable to find latest version|No published versions/i.test(msg)) return 'No version has been published on GitHub yet.';
    if (/ENOTFOUND|ECONNREFUSED|ETIMEDOUT|net::ERR/i.test(msg)) return 'GitHub cannot be reached. Check the internet connection.';
    return msg.split('\n')[0];
  }

  set(state) {
    this.state = state;
    this.emit('state', this.getState());
  }

  getState() {
    return { ...this.state, installed: this.installed, current: this.app.getVersion(), options: { ...this.options }, releasesPage: RELEASES_PAGE };
  }

  setOptions(patch) {
    this.options = { ...this.options, ...patch };
    if (this.updater) this.updater.allowPrerelease = this.options.beta;
    this.schedule();
    this.emit('state', this.getState());
    return this.getState();
  }

  // the first check a few seconds after the start, then every few hours, while automatic checks are on
  schedule() {
    clearInterval(this.timer);
    this.timer = null;
    if (!this.options.autoCheck) return;
    this.timer = setInterval(() => this.check(true), CHECK_EVERY);
  }

  start() {
    this.schedule();
    if (this.options.autoCheck) setTimeout(() => this.check(true), 5000);
  }

  async check(quiet = false) {
    if (['checking', 'downloading', 'downloaded'].includes(this.state.phase)) return this.getState();
    if (this.updater) {
      try {
        await this.updater.checkForUpdates();
      } catch (err) {
        // already reported by the 'error' event; a quiet check stays quiet
        if (quiet) this.set({ phase: 'idle' });
      }
      return this.getState();
    }
    return this.checkGitHub(quiet);
  }

  // run from the sources: only tell which version is the latest
  async checkGitHub(quiet) {
    this.set({ phase: 'checking' });
    try {
      const res = await fetch(`https://api.github.com/repos/${REPO.owner}/${REPO.repo}/releases?per_page=20`, {
        headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'MyBot' },
      });
      if (!res.ok) throw new Error(`GitHub answered ${res.status}`);
      const release = (await res.json()).find((r) => !r.draft && (this.options.beta || !r.prerelease));
      if (!release) this.set({ phase: 'error', error: 'No version has been published on GitHub yet.' });
      else if (compareVersions(release.tag_name, this.app.getVersion()) > 0) {
        this.set({ phase: 'available', version: release.tag_name.replace(/^v/, ''), date: release.published_at, notes: notesText(release.body), checkedAt: Date.now() });
      } else this.set({ phase: 'latest', checkedAt: Date.now() });
    } catch (err) {
      this.set(quiet ? { phase: 'idle' } : { phase: 'error', error: this.explain(err) });
    }
    return this.getState();
  }

  async download() {
    if (!this.updater) throw new Error('Updates install themselves only in the installed application');
    if (this.state.phase !== 'available') throw new Error('No update to download');
    this.set({ ...this.state, phase: 'downloading', percent: 0 });
    await this.updater.downloadUpdate();
    return this.getState();
  }

  // quits, installs and starts the new version (the Windows installer runs silently)
  install() {
    if (!this.updater || this.state.phase !== 'downloaded') throw new Error('No downloaded update to install');
    setImmediate(() => this.updater.quitAndInstall(true, true));
  }
}

module.exports = { Updater, compareVersions, notesText, RELEASES_PAGE };
