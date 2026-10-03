#!/usr/bin/env node
// Builds the installable MyBot: the Windows installer (NSIS) and, on Linux, the AppImage, each carrying the bot.
//
//   node scripts/build-release.js              build into GUI-Electron/dist
//   node scripts/build-release.js --publish    build, then upload to a DRAFT release on GitHub (needs GH_TOKEN);
//                                              users get it once you press "Publish release" on GitHub
//   --allow-dirty                              build even if GUI-Electron has uncommitted changes
//   --linux-only                               only the AppImage, from the bot a Windows build left in payload/
//                                              (run under WSL after the Windows build: no AutoIt, no Wine needed)
//
// The bot is taken from the last commit (git HEAD), not from the working folder: what is released is what is committed,
// and local files (profiles, logs, a lib/ changed by hand) never end up in it. Steps:
//   1. the repository at HEAD is extracted to payload/src
//   2. Au3Check, then Aut2Exe compiles MyBot.run, its Watchdog and Wmi, MultiBot (and the Linux bridge)
//   3. payload/bot = the files the bot needs, plus bot-manifest.json (version + SHA-256 of each file)
//   4. electron-builder: Windows installer (and AppImage on Linux), the bot in resources/bot
//
// AutoIt (x86, "Full Installation") is needed: on Windows in Program Files, on Linux in the Wine prefix ~/.wine32
// (or $WINEPREFIX), as for _tools/au3check.sh.
const { execFileSync, spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { writeManifest } = require('../lib/bot-install');

const GUI_DIR = path.resolve(__dirname, '..');
const REPO_DIR = path.resolve(GUI_DIR, '..');
const PAYLOAD = path.join(GUI_DIR, 'payload');
// the sources are compiled in a short folder: Aut2Exe cannot open an #include whose path is longer than 260
// characters, which a repository in a deep folder reaches ("Error opening the file")
const SRC = process.platform === 'win32' ? path.join(os.tmpdir(), 'mybot-release-src') : path.join(PAYLOAD, 'src');
const BOT = path.join(PAYLOAD, 'bot');
const BRIDGE = path.join(PAYLOAD, 'bridge');
const IS_WINDOWS = process.platform === 'win32';

const args = new Set(process.argv.slice(2));
const PUBLISH = args.has('--publish');
const ALLOW_DIRTY = args.has('--allow-dirty');
const LINUX_ONLY = args.has('--linux-only');

// the folders and files of the repository that are tools or sources of the interface, not part of the bot
const NOT_IN_BOT = new Set(['GUI-Electron', '_release', '_tools', '_backup_avant_fix_bs5', 'enginesrc', 'dllsrc', 'tatus', '.gitignore', '.gitattributes', 'Lancer MyBot GUI.bat', 'Lancer MyBot GUI.sh']);
// what Aut2Exe compiles: [source, executable]
const PROGRAMS = [
  ['MyBot.run.au3', 'MyBot.run.exe'],
  ['MyBot.run.Watchdog.au3', 'MyBot.run.Watchdog.exe'],
  ['MyBot.run.Wmi.au3', 'MyBot.run.Wmi.exe'],
  ['MultiBot.au3', 'MultiBot.exe'],
];

function step(msg) {
  console.log(`\n== ${msg}`);
}

function fail(msg) {
  console.error(`\nERROR: ${msg}`);
  process.exit(1);
}

function git(...a) {
  return execFileSync('git', a, { cwd: REPO_DIR, encoding: 'utf8' });
}

// ------------------------------------------------------------------------------------------------------------- AutoIt
const wine = IS_WINDOWS ? null : { prefix: process.env.WINEPREFIX || path.join(os.homedir(), '.wine32') };

function autoitDir() {
  if (!IS_WINDOWS) {
    const dir = path.join(wine.prefix, 'drive_c', 'Program Files', 'AutoIt3');
    if (!fs.existsSync(path.join(dir, 'Aut2Exe', 'Aut2exe.exe'))) fail(`AutoIt was not found in the Wine prefix ${wine.prefix}`);
    return 'C:\\Program Files\\AutoIt3';
  }
  for (const base of [process.env['ProgramFiles(x86)'], process.env.ProgramFiles]) {
    const dir = base && path.join(base, 'AutoIt3');
    if (dir && fs.existsSync(path.join(dir, 'Aut2Exe', 'Aut2exe.exe'))) return dir;
  }
  fail('AutoIt was not found (install AutoIt3, "Full Installation")');
}

// a path as the AutoIt tools see it: unchanged on Windows, through the Z: drive under Wine
function toolPath(p) {
  return IS_WINDOWS ? p : `Z:${path.resolve(p).replace(/\//g, '\\')}`;
}

function runTool(exe, toolArgs) {
  const cmd = IS_WINDOWS ? exe : 'wine';
  const full = IS_WINDOWS ? toolArgs : [exe, ...toolArgs];
  const env = IS_WINDOWS ? process.env : { ...process.env, WINEPREFIX: wine.prefix, WINEARCH: 'win32', WINEDEBUG: '-all' };
  const res = spawnSync(cmd, full, { env, encoding: 'utf8', timeout: 10 * 60 * 1000 });
  return { status: res.status, out: `${res.stdout ?? ''}${res.stderr ?? ''}`.split('\n').filter((l) => !/:(err|fixme|warn):/.test(l)).join('\n') };
}

function au3check(dir, file) {
  const { out } = runTool(`${dir}\\Au3Check.exe`, ['-q', '-d', toolPath(file)]);
  const errors = out.split('\n').filter((l) => / error:/.test(l));
  if (errors.length) fail(`Au3Check found ${errors.length} error(s) in ${path.basename(file)}:\n${errors.slice(0, 10).join('\n')}`);
}

function aut2exe(dir, src, out, extra = []) {
  fs.rmSync(out, { force: true });
  runTool(`${dir}\\Aut2Exe\\Aut2exe.exe`, ['/in', toolPath(src), '/out', toolPath(out), '/x86', '/nopack', ...extra]);
  if (!fs.existsSync(out)) fail(`Aut2Exe did not produce ${path.basename(out)}`);
}

// --------------------------------------------------------------------------------------------------------------- main
// one build at a time: a second one would empty payload/ under the first
const LOCK = path.join(GUI_DIR, 'payload.lock');
function lock() {
  try {
    const pid = Number(fs.readFileSync(LOCK, 'utf8'));
    process.kill(pid, 0); // throws when that build is no longer running
    fail(`Another build is already running (process ${pid}). Wait for it to finish.`);
  } catch (err) {
    if (err.code !== 'ENOENT' && err.code !== 'ESRCH') throw err;
  }
  fs.writeFileSync(LOCK, String(process.pid));
  process.on('exit', () => fs.rmSync(LOCK, { force: true }));
}

// the AppImage alone, from payload/ as the Windows build left it: the bot is the same Windows programs on both systems
async function linuxOnly() {
  if (IS_WINDOWS) fail('--linux-only builds the AppImage: run it under Linux (WSL), after the Windows build');
  const manifest = JSON.parse(fs.readFileSync(path.join(BOT, 'bot-manifest.json'), 'utf8'));
  if (!fs.existsSync(path.join(BRIDGE, 'MyBotBridge.exe'))) fail(`No ${path.join(BRIDGE, 'MyBotBridge.exe')}: build on Windows first`);
  step(`Building the AppImage of ${manifest.version} from payload/`);
  const builder = require('electron-builder');
  const artifacts = await builder.build({
    projectDir: GUI_DIR,
    targets: builder.Platform.LINUX.createTarget(),
    publish: PUBLISH ? 'always' : 'never',
    config: { extraMetadata: { version: manifest.version } },
  });
  step('Done');
  for (const a of artifacts) if (/\.(AppImage|yml)$/.test(a)) console.log(`  ${a}`);
}

async function main() {
  lock();
  if (LINUX_ONLY) return linuxOnly();
  step('Checks');
  const head = git('rev-parse', '--short', 'HEAD').trim();
  const versionFile = git('show', 'HEAD:MyBot.run.version.au3');
  const version = /\$g_sBotVersion\s*=\s*"v(\d+\.\d+\.\d+)"/.exec(versionFile)?.[1];
  if (!version) fail('No $g_sBotVersion "vX.Y.Z" in MyBot.run.version.au3 at HEAD');
  console.log(`version ${version}, commit ${head}`);

  const dirtyGui = git('status', '--porcelain', '--', 'GUI-Electron').trim();
  if (dirtyGui && !ALLOW_DIRTY) fail(`GUI-Electron has uncommitted changes (commit them, or pass --allow-dirty):\n${dirtyGui}`);
  const dirtyOther = git('status', '--porcelain', '--untracked-files=no').split('\n').filter((l) => l && !l.includes('GUI-Electron/'));
  if (dirtyOther.length) console.log(`not in this build (uncommitted, the build uses HEAD):\n  ${dirtyOther.join('\n  ')}`);
  if (PUBLISH && !process.env.GH_TOKEN) fail('--publish needs a GitHub token in the GH_TOKEN environment variable');

  step('Extracting the repository at HEAD');
  fs.rmSync(PAYLOAD, { recursive: true, force: true });
  fs.rmSync(SRC, { recursive: true, force: true });
  fs.mkdirSync(PAYLOAD, { recursive: true });
  fs.mkdirSync(SRC, { recursive: true });
  const tar = path.join(PAYLOAD, 'head.tar');
  git('archive', '--format=tar', '-o', tar, 'HEAD');
  // Windows' own tar: from Git Bash, the tar found first is GNU tar, which takes "C:" for a remote host
  const tarExe = IS_WINDOWS && process.env.SystemRoot ? path.join(process.env.SystemRoot, 'System32', 'tar.exe') : 'tar';
  execFileSync(fs.existsSync(tarExe) ? tarExe : 'tar', ['-xf', tar, '-C', SRC]);
  fs.rmSync(tar);

  step('Compiling the bot (Au3Check + Aut2Exe)');
  const dir = autoitDir();
  for (const [src, exe] of PROGRAMS) {
    process.stdout.write(`  ${src} ... `);
    au3check(dir, path.join(SRC, src));
    aut2exe(dir, path.join(SRC, src), path.join(SRC, exe));
    console.log('ok');
  }
  // the Linux bridge: a console program, so that the interface can talk to it on its standard input and output
  fs.mkdirSync(BRIDGE, { recursive: true });
  process.stdout.write('  MyBotBridge.au3 ... ');
  aut2exe(dir, path.join(SRC, 'GUI-Electron', 'bridge', 'MyBotBridge.au3'), path.join(BRIDGE, 'MyBotBridge.exe'), ['/console']);
  console.log('ok');

  step('Assembling the bot');
  for (const entry of fs.readdirSync(SRC)) {
    if (NOT_IN_BOT.has(entry)) continue;
    fs.cpSync(path.join(SRC, entry), path.join(BOT, entry), { recursive: true });
  }
  fs.rmSync(SRC, { recursive: true, force: true });
  const count = writeManifest(BOT, version);
  console.log(`  ${count} files, manifest written`);

  step('Building the installer');
  const builder = require('electron-builder');
  const targets = IS_WINDOWS ? builder.Platform.WINDOWS.createTarget() : new Map([...builder.Platform.WINDOWS.createTarget(), ...builder.Platform.LINUX.createTarget()]);
  const artifacts = await builder.build({
    projectDir: GUI_DIR,
    targets,
    publish: PUBLISH ? 'always' : 'never',
    config: { extraMetadata: { version } },
  });

  step('Done');
  for (const a of artifacts) if (/\.(exe|AppImage)$/.test(a)) console.log(`  ${path.relative(REPO_DIR, a)}`);
  if (PUBLISH) console.log(`\nUploaded to a DRAFT release v${version} on GitHub: check it, then press "Publish release".`);
}

main().catch((err) => fail(err.stack ?? err.message));
