/**
 * Electron Hello World - Benchmark App
 *
 * Minimal Electron app for startup time measurement.
 * Uses the same HTML as Craft and Tauri versions.
 *
 * Set BENCHMARK=1 env var to auto-quit after window renders.
 */
const { app, BrowserWindow } = require('electron')
const path = require('path')

const isBenchmark = process.env.BENCHMARK === '1'

app.whenReady().then(() => {
  const win = new BrowserWindow({
    width: 400,
    height: 300,
    title: 'Hello World',
    resizable: false,
    webPreferences: {
      devTools: false,
    },
  })

  win.loadFile(path.join(__dirname, '..', 'hello.html'))

  if (isBenchmark) {
    win.webContents.on('did-finish-load', () => {
      process.stdout.write('ready\n')
      app.quit()
    })
  }
})

app.on('window-all-closed', () => {
  app.quit()
})
