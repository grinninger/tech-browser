'use strict';

const { app, BrowserWindow, WebContentsView, ipcMain, session, shell } = require('electron');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { findStartUrl, normalizeInput } = require('./navigation');

// Backstage is a restricted Windows desktop. Force Chromium away from GPU/DWM paths
// that commonly produce black or partially refreshed browser windows there.
app.disableHardwareAcceleration();
app.commandLine.appendSwitch('disable-gpu');
app.commandLine.appendSwitch('disable-gpu-compositing');
app.commandLine.appendSwitch('disable-gpu-rasterization');
app.commandLine.appendSwitch('disable-direct-composition');
app.commandLine.appendSwitch('disable-backgrounding-occluded-windows');
app.commandLine.appendSwitch('disable-renderer-backgrounding');

const TOOLBAR_HEIGHT = 52;
const SMOKE_TEST = process.argv.includes('--smoke-test');
let mainWindow;
let browserView;

function safeDownloadPath(filename) {
  const downloadDir = path.join(os.tmpdir(), 'Tech Browser Downloads');
  fs.mkdirSync(downloadDir, { recursive: true });
  const safeName = path.basename(filename).replace(/[<>:"/\\|?*\x00-\x1F]/g, '_');
  return path.join(downloadDir, safeName || 'download');
}

function sendState(extra = {}) {
  if (!mainWindow || mainWindow.isDestroyed() || !browserView || browserView.webContents.isDestroyed()) return;

  mainWindow.webContents.send('browser:state', {
    url: browserView.webContents.getURL(),
    title: browserView.webContents.getTitle(),
    canGoBack: browserView.webContents.canGoBack(),
    canGoForward: browserView.webContents.canGoForward(),
    loading: browserView.webContents.isLoading(),
    ...extra
  });
}

function layoutBrowser() {
  if (!mainWindow || mainWindow.isDestroyed() || !browserView) return;
  const [width, height] = mainWindow.getContentSize();
  browserView.setBounds({ x: 0, y: TOOLBAR_HEIGHT, width, height: Math.max(0, height - TOOLBAR_HEIGHT) });
}

function navigate(rawInput) {
  const target = normalizeInput(rawInput);
  browserView.webContents.loadURL(target).catch((error) => {
    sendState({ message: `Seite konnte nicht geladen werden: ${error.message}` });
  });
}

function wireBrowserEvents() {
  const contents = browserView.webContents;
  const update = () => sendState();

  for (const eventName of ['did-navigate', 'did-navigate-in-page', 'did-start-loading', 'did-stop-loading', 'page-title-updated']) {
    contents.on(eventName, update);
  }

  contents.on('did-fail-load', (_event, errorCode, errorDescription, validatedURL, isMainFrame) => {
    if (isMainFrame && errorCode !== -3) {
      sendState({ message: `${errorDescription} (${errorCode}) – ${validatedURL}` });
    }
  });

  contents.setWindowOpenHandler(({ url }) => {
    navigate(url);
    return { action: 'deny' };
  });
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1180,
    height: 820,
    minWidth: 640,
    minHeight: 420,
    title: 'Tech Browser',
    backgroundColor: '#f4f6f8',
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: false
    }
  });

  browserView = new WebContentsView({
    webPreferences: {
      partition: `tech-browser-${process.pid}`,
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: false,
      autoplayPolicy: 'document-user-activation-required'
    }
  });

  mainWindow.contentView.addChildView(browserView);
  mainWindow.on('resize', layoutBrowser);
  mainWindow.on('maximize', layoutBrowser);
  mainWindow.on('unmaximize', layoutBrowser);
  mainWindow.on('closed', () => {
    if (browserView && !browserView.webContents.isDestroyed()) browserView.webContents.close();
    browserView = undefined;
    mainWindow = undefined;
  });

  wireBrowserEvents();
  mainWindow.loadFile(path.join(__dirname, 'toolbar.html'));
  mainWindow.webContents.once('did-finish-load', () => {
    layoutBrowser();
    if (SMOKE_TEST) {
      const timeout = setTimeout(() => app.exit(2), 15000);
      browserView.webContents.once('did-finish-load', () => {
        clearTimeout(timeout);
        console.log('Tech Browser smoke test passed.');
        app.exit(0);
      });
      browserView.webContents.loadURL('data:text/html,<title>Smoke Test</title><h1>OK</h1>');
    } else {
      mainWindow.show();
      navigate(findStartUrl(process.argv.slice(1)));
    }
  });
}

app.whenReady().then(() => {
  const browserSession = session.fromPartition(`tech-browser-${process.pid}`);
  browserSession.setPermissionRequestHandler((_webContents, _permission, callback) => callback(false));
  browserSession.on('will-download', (_event, item) => {
    const savePath = safeDownloadPath(item.getFilename());
    item.setSavePath(savePath);
    item.once('done', (_downloadEvent, state) => {
      if (state === 'completed') {
        sendState({ message: `Download gespeichert: ${savePath}`, downloadPath: savePath });
      } else {
        sendState({ message: `Download ${state}: ${item.getFilename()}` });
      }
    });
  });

  createWindow();
});

ipcMain.handle('browser:navigate', (_event, value) => navigate(value));
ipcMain.handle('browser:back', () => browserView?.webContents.canGoBack() && browserView.webContents.goBack());
ipcMain.handle('browser:forward', () => browserView?.webContents.canGoForward() && browserView.webContents.goForward());
ipcMain.handle('browser:reload', () => browserView?.webContents.reload());
ipcMain.handle('browser:stop', () => browserView?.webContents.stop());
ipcMain.handle('browser:home', () => navigate('about:blank'));
ipcMain.handle('browser:open-download', (_event, downloadPath) => {
  if (typeof downloadPath === 'string' && downloadPath.startsWith(path.join(os.tmpdir(), 'Tech Browser Downloads'))) {
    return shell.showItemInFolder(downloadPath);
  }
  return undefined;
});
ipcMain.handle('browser:get-state', () => {
  if (!browserView) return {};
  return {
    url: browserView.webContents.getURL(),
    title: browserView.webContents.getTitle(),
    canGoBack: browserView.webContents.canGoBack(),
    canGoForward: browserView.webContents.canGoForward(),
    loading: browserView.webContents.isLoading()
  };
});

app.on('window-all-closed', () => app.quit());
