# Migrating from Electron

A guide to migrating your Electron application to Craft.

## Overview

| Aspect | Electron | Craft |
|--------|----------|-------|
| Runtime | Chromium + Node.js | Native WebView + Zig |
| Binary size | ~392 MB | ~297 KB |
| Memory | ~369 MB | ~86 MB |
| Startup | ~412 ms | ~168 ms |
| Mobile | Not supported | iOS & Android |

## Project Structure

### Electron
```
electron-app/
├── main.js           # Main process
├── preload.js        # Preload script
├── renderer/         # Renderer process
│   ├── index.html
│   └── renderer.js
└── package.json
```

### Craft
```
craft-app/
├── craft.config.ts   # Configuration
├── index.html        # Entry point
├── src/
│   └── main.ts       # Application code
└── package.json
```

## API Mapping

### Window Management

**Electron:**
```javascript
const { BrowserWindow } = require('electron')

const win = new BrowserWindow({
  width: 800,
  height: 600,
  title: 'My App'
})

win.setTitle('New Title')
win.maximize()
win.close()
```

**Craft:**
```typescript
import { window } from '@stacksjs/ts-craft'

// Configuration in craft.config.ts
window: {
  width: 800,
  height: 600,
  title: 'My App'
}

// Runtime control
window.setTitle('New Title')
window.maximize()
window.close()
```

### IPC / Bridge Communication

**Electron (main process):**
```javascript
const { ipcMain } = require('electron')

ipcMain.handle('read-file', async (event, path) => {
  return fs.promises.readFile(path, 'utf8')
})
```

**Electron (renderer):**
```javascript
const content = await window.electron.invoke('read-file', '/path/to/file')
```

**Craft:**
```typescript
import { fs } from '@stacksjs/ts-craft'

// No IPC setup needed - direct API
const content = await fs.readFile('/path/to/file')
```

### System Tray

**Electron:**
```javascript
const { Tray, Menu, nativeImage } = require('electron')

const tray = new Tray(nativeImage.createFromPath('icon.png'))
tray.setToolTip('My App')
tray.setContextMenu(Menu.buildFromTemplate([
  { label: 'Show', click: () => win.show() },
  { label: 'Quit', click: () => app.quit() }
]))
```

**Craft:**
```typescript
import { tray } from '@stacksjs/ts-craft'

await tray.create({
  icon: 'icon.png',
  tooltip: 'My App',
  menu: [
    { label: 'Show', action: 'show' },
    { label: 'Quit', action: 'quit' }
  ],
  onAction: (action) => {
    if (action === 'show') window.show()
    if (action === 'quit') window.close()
  }
})
```

### Notifications

**Electron:**
```javascript
const { Notification } = require('electron')

new Notification({
  title: 'Hello',
  body: 'World'
}).show()
```

**Craft:**
```typescript
import { notification } from '@stacksjs/ts-craft'

await notification.show({
  title: 'Hello',
  body: 'World'
})
```

### File System

**Electron (main):**
```javascript
const fs = require('fs').promises

ipcMain.handle('fs:read', async (e, path) => {
  return fs.readFile(path, 'utf8')
})

ipcMain.handle('fs:write', async (e, path, data) => {
  return fs.writeFile(path, data)
})
```

**Craft:**
```typescript
import { fs } from '@stacksjs/ts-craft'

// Direct access - no IPC needed
const content = await fs.readFile('/path/to/file')
await fs.writeFile('/path/to/file', 'content')
```

### Dialogs

**Electron:**
```javascript
const { dialog } = require('electron')

const result = await dialog.showOpenDialog({
  properties: ['openFile'],
  filters: [{ name: 'Text', extensions: ['txt'] }]
})
```

**Craft:**
```typescript
import { dialog } from '@stacksjs/ts-craft'

const result = await dialog.open({
  multiple: false,
  filters: [{ name: 'Text', extensions: ['txt'] }]
})
```

### Keyboard Shortcuts

**Electron:**
```javascript
const { globalShortcut } = require('electron')

globalShortcut.register('CommandOrControl+S', () => {
  saveDocument()
})
```

**Craft:**
```typescript
import { shortcuts } from '@stacksjs/ts-craft'

shortcuts.register('mod+s', () => {
  saveDocument()
})
```

### App Lifecycle

**Electron:**
```javascript
app.on('ready', () => {
  createWindow()
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})
```

**Craft:**
```typescript
// Craft handles lifecycle automatically
// Your app code runs when ready

// For custom lifecycle handling:
import { lifecycle } from '@stacksjs/ts-craft'

lifecycle.on('willQuit', () => {
  // Cleanup
})
```

## Step-by-Step Migration

### 1. Create New Craft Project

```bash
bunx craft init my-app
cd my-app
```

### 2. Copy Web Assets

Copy your renderer HTML, CSS, and JavaScript:
```bash
cp -r ../electron-app/renderer/* ./src/
```

### 3. Update Configuration

Replace `package.json` scripts and create `craft.config.ts`:

```typescript
// craft.config.ts
import type { CraftAppConfig } from '@stacksjs/ts-craft'

const config: CraftAppConfig = {
  name: 'My App',
  version: '1.0.0',
  identifier: 'com.mycompany.myapp',

  window: {
    title: 'My App',
    width: 1200,
    height: 800,
    // ... your Electron BrowserWindow options
  },

  entry: './index.html'
}

export default config
```

### 4. Replace IPC Calls

Find and replace all `ipcRenderer.invoke()` calls:

```typescript
// Before (Electron)
const data = await window.electron.invoke('read-file', path)

// After (Craft)
import { fs } from '@stacksjs/ts-craft'
const data = await fs.readFile(path)
```

### 5. Update Imports

```typescript
// Before (Electron preload)
const { contextBridge, ipcRenderer } = require('electron')

// After (Craft)
import { fs, db, http, window, notification } from '@stacksjs/ts-craft'
```

### 6. Remove Electron-Specific Code

Remove:
- `main.js` / main process
- `preload.js`
- `contextBridge` usage
- `ipcMain` / `ipcRenderer`
- `electron-builder` config

### 7. Build and Test

```bash
bun run dev    # Development
bun run build  # Production build
```

## Common Patterns

### Using React

**Electron:**
```jsx
import { ipcRenderer } from 'electron'

function App() {
  const [data, setData] = useState(null)

  useEffect(() => {
    ipcRenderer.invoke('get-data').then(setData)
  }, [])
}
```

**Craft:**
```jsx
import { useCraft } from 'ts-craft/react'
import { db } from '@stacksjs/ts-craft'

function App() {
  const { isReady } = useCraft()
  const [data, setData] = useState(null)

  useEffect(() => {
    if (isReady) {
      db.query('SELECT * FROM items').then(setData)
    }
  }, [isReady])
}
```

### Environment Variables

**Electron:**
```javascript
const isDev = !app.isPackaged
```

**Craft:**
```typescript
import { Platform } from '@stacksjs/ts-craft'

const isDev = Platform.isDev
```

## What's Different

### No Main/Renderer Split

Craft doesn't have separate processes. All code runs in the WebView context with native APIs available directly.

### No Node.js

Craft doesn't include Node.js. Native functionality is provided by the Craft APIs instead.

**If you need npm packages:**
- Most browser-compatible packages work
- Replace Node-specific packages with Craft APIs
- `fs` → `ts-craft` fs API
- `sqlite3` → `ts-craft` db API
- `node-fetch` → `ts-craft` http API

### No contextBridge

Craft APIs are available directly - no need to expose them via contextBridge.

### Smaller Bundle

Your app will be much smaller. Consider removing unused dependencies that were only needed for Electron.

## Troubleshooting

### "Module not found: fs"

You're trying to use Node.js fs module. Use Craft's fs API:
```typescript
import { fs } from '@stacksjs/ts-craft'
```

### "require is not defined"

Craft uses ES modules. Convert require to import:
```typescript
// Before
const something = require('something')

// After
import something from 'something'
```

### Missing Node API

Create a compatibility layer or use Craft equivalents:
```typescript
// Compatibility shim for process.env
const env = {
  NODE_ENV: Platform.isDev ? 'development' : 'production'
}
```
