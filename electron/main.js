const { app, BrowserWindow, ipcMain, screen } = require('electron');
const fs = require('node:fs');
const path = require('node:path');

// 本机 GPU 合成会让这个无边框小窗卡在 loading（白屏），关掉硬件加速
app.disableHardwareAcceleration();

const stateFile = () => path.join(app.getPath('userData'), 'window.json');

function readState() {
  try { return JSON.parse(fs.readFileSync(stateFile(), 'utf8')); } catch { return {}; }
}
function writeState(patch) {
  try {
    const next = { ...readState(), ...patch };
    fs.writeFileSync(stateFile(), JSON.stringify(next));
  } catch {}
}

let win = null;
let saveTimer = null;

function createWindow() {
  const saved = readState();
  const display = screen.getPrimaryDisplay().workArea;
  const w = saved.width || 300;
  // 卡片化后内容需要 320，旧配置里存的 286 会把字裁掉
  const h = Math.max(280, saved.height || 280);
  let x = Number.isFinite(saved.x) ? saved.x : display.x + display.width - w - 24;
  let y = Number.isFinite(saved.y) ? saved.y : display.y + display.height - h - 24;
  // 保证窗口还在屏幕内
  if (x < display.x || x > display.x + display.width - 80) x = display.x + display.width - w - 24;
  if (y < display.y || y > display.y + display.height - 60) y = display.y + display.height - h - 24;

  win = new BrowserWindow({
    width: w, height: h, x, y, roundedCorners: true,
    frame: false,
    transparent: false,
    backgroundColor: '#E9EDF2',
    hasShadow: true,
    resizable: false,
    maximizable: false,
    fullscreenable: false,
    skipTaskbar: true,
    alwaysOnTop: true,
    show: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      backgroundThrottling: false,
    },
  });

  win.setAlwaysOnTop(true, 'screen-saver');
  const fs2 = require('node:fs');
  const logFile = path.join(__dirname, 'debug.log');
  const log = (...a) => { try { fs2.appendFileSync(logFile, new Date().toISOString() + ' ' + a.join(' ') + '\n'); } catch {} };
  win.webContents.on('did-finish-load', () => log('did-finish-load'));
  win.webContents.on('did-fail-load', (_e, code, desc, url) => log('did-fail-load', code, desc, url));
  win.webContents.on('console-message', (_e, level, msg) => log('console', level, msg));
  win.webContents.on('render-process-gone', (_e, d) => log('render-gone', JSON.stringify(d)));
  const target = path.join(__dirname, 'renderer', 'index.html');
  log('load', target, fs2.existsSync(target));
  win.loadFile(target).then(() => log('loadFile resolved')).catch((e) => log('loadFile error', String(e)));
  const showOnce = () => { if (win && !win.isDestroyed() && !win.isVisible()) win.show(); };
  win.once('ready-to-show', showOnce);
  win.once('did-finish-load', () => setTimeout(showOnce, 60));

  win.on('moved', () => {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      if (!win || win.isDestroyed()) return;
      const [nx, ny] = win.getPosition();
      writeState({ x: nx, y: ny });
    }, 400);
  });

  win.on('closed', () => { win = null; });
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (win) { win.show(); win.focus(); }
  });
  app.whenReady().then(createWindow);
}

ipcMain.on('win:close', () => { if (win) win.close(); });
ipcMain.on('win:minimize', () => { if (win) win.hide(); });
ipcMain.handle('win:getState', () => readState());
ipcMain.on('win:setSize', (_e, { width, height }) => {
  if (!win) return;
  const [x, y] = win.getPosition();
  win.setSize(Math.round(width), Math.round(height), false);
  win.setPosition(x, y, false);
});
