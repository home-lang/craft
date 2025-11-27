# Migrating from Tauri to Craft

This guide helps you migrate your Tauri application to Craft, covering the key differences and providing code examples for common patterns.

## Overview

Both Tauri and Craft share similar philosophies:
- Native performance with web technologies
- Small binary sizes
- System-level APIs through native code
- Cross-platform support

However, Craft offers some advantages:
- **Unified Zig codebase** - Single native layer for all platforms
- **TypeScript-first** - Full TypeScript SDK without Rust knowledge
- **Simpler architecture** - No IPC complexity, direct native calls
- **Built-in mobile support** - iOS and Android from the same codebase

## Project Structure Comparison

### Tauri Structure
```
my-tauri-app/
├── src/                    # Web frontend
├── src-tauri/
│   ├── Cargo.toml         # Rust dependencies
│   ├── tauri.conf.json    # Tauri configuration
│   └── src/
│       └── main.rs        # Rust backend
└── package.json
```

### Craft Structure
```
my-craft-app/
├── src/                    # Web frontend
│   └── main.ts
├── craft.config.ts         # Craft configuration
└── package.json
```

## Configuration Migration

### Tauri (tauri.conf.json)
```json
{
  "build": {
    "distDir": "../dist",
    "devPath": "http://localhost:5173"
  },
  "package": {
    "productName": "My App",
    "version": "1.0.0"
  },
  "tauri": {
    "bundle": {
      "identifier": "com.example.myapp",
      "icon": ["icons/icon.icns", "icons/icon.ico"]
    },
    "windows": [{
      "title": "My App",
      "width": 800,
      "height": 600
    }]
  }
}
```

### Craft (craft.config.ts)
```typescript
import { defineConfig } from 'ts-craft';

export default defineConfig({
  name: 'My App',
  version: '1.0.0',
  identifier: 'com.example.myapp',

  window: {
    title: 'My App',
    width: 800,
    height: 600,
  },

  build: {
    outDir: 'dist',
  },

  icons: {
    macos: 'icons/icon.icns',
    windows: 'icons/icon.ico',
    linux: 'icons/icon.png',
  },
});
```

## Command Migration

### Tauri Commands
```rust
// src-tauri/src/main.rs
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}!", name)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![greet])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

```typescript
// Frontend
import { invoke } from '@tauri-apps/api/tauri';

const greeting = await invoke('greet', { name: 'World' });
```

### Craft Equivalent
```typescript
// src/main.ts
import { bridge } from 'ts-craft';

// Native bridge is built-in, no Rust required
const result = await bridge.request('greet', { name: 'World' });

// Or use the built-in APIs directly
import { dialog } from 'ts-craft';
await dialog.message('Hello, World!');
```

## API Migration

### File System

**Tauri:**
```typescript
import { readTextFile, writeTextFile } from '@tauri-apps/api/fs';
import { BaseDirectory } from '@tauri-apps/api/path';

const content = await readTextFile('config.json', { dir: BaseDirectory.App });
await writeTextFile('config.json', JSON.stringify(data), { dir: BaseDirectory.App });
```

**Craft:**
```typescript
import { fs } from 'ts-craft';

const content = await fs.readFile('config.json', { encoding: 'utf-8' });
await fs.writeFile('config.json', JSON.stringify(data));
```

### Dialogs

**Tauri:**
```typescript
import { open, save, message, confirm } from '@tauri-apps/api/dialog';

const files = await open({
  multiple: true,
  filters: [{ name: 'Images', extensions: ['png', 'jpg'] }]
});

const confirmed = await confirm('Are you sure?', { title: 'Confirm' });
```

**Craft:**
```typescript
import { dialog } from 'ts-craft';

const files = await dialog.open({
  multiple: true,
  filters: [{ name: 'Images', extensions: ['png', 'jpg'] }]
});

const confirmed = await dialog.confirm('Are you sure?', { title: 'Confirm' });
```

### Window Management

**Tauri:**
```typescript
import { appWindow } from '@tauri-apps/api/window';

await appWindow.setTitle('New Title');
await appWindow.setSize(new LogicalSize(1200, 800));
await appWindow.center();
await appWindow.minimize();
await appWindow.maximize();
await appWindow.setFullscreen(true);
```

**Craft:**
```typescript
import { window } from 'ts-craft';

await window.setTitle('New Title');
await window.setSize(1200, 800);
await window.center();
await window.minimize();
await window.maximize();
await window.setFullscreen(true);
```

### System Tray

**Tauri:**
```typescript
import { TrayIcon } from '@tauri-apps/api/tray';
import { Menu, MenuItem } from '@tauri-apps/api/menu';

const menu = await Menu.new({
  items: [
    await MenuItem.new({ text: 'Show', action: () => appWindow.show() }),
    await MenuItem.new({ text: 'Quit', action: () => process.exit() }),
  ]
});

const tray = await TrayIcon.new({
  icon: 'icons/tray.png',
  menu,
  tooltip: 'My App'
});
```

**Craft:**
```typescript
import { tray, window } from 'ts-craft';

await tray.create({
  icon: 'icons/tray.png',
  tooltip: 'My App',
  menu: [
    { label: 'Show', onClick: () => window.show() },
    { label: 'Quit', onClick: () => process.exit() },
  ]
});
```

### HTTP Requests

**Tauri:**
```typescript
import { fetch } from '@tauri-apps/api/http';

const response = await fetch('https://api.example.com/data', {
  method: 'GET',
  timeout: 30
});
```

**Craft:**
```typescript
import { http } from 'ts-craft';

const response = await http.fetch('https://api.example.com/data', {
  method: 'GET',
  timeout: 30000
});

// Or use native fetch (no CORS restrictions in native apps)
const response = await fetch('https://api.example.com/data');
```

### Notifications

**Tauri:**
```typescript
import { sendNotification, requestPermission } from '@tauri-apps/api/notification';

await requestPermission();
sendNotification({
  title: 'Hello',
  body: 'This is a notification'
});
```

**Craft:**
```typescript
import { notification } from 'ts-craft';

await notification.requestPermission();
await notification.show({
  title: 'Hello',
  body: 'This is a notification'
});
```

### Clipboard

**Tauri:**
```typescript
import { writeText, readText } from '@tauri-apps/api/clipboard';

await writeText('Hello');
const text = await readText();
```

**Craft:**
```typescript
import { clipboard } from 'ts-craft';

await clipboard.writeText('Hello');
const text = await clipboard.readText();
```

### Shell Commands

**Tauri:**
```typescript
import { Command } from '@tauri-apps/api/shell';

const command = new Command('git', ['status']);
const output = await command.execute();
console.log(output.stdout);
```

**Craft:**
```typescript
import { process } from 'ts-craft';

const output = await process.exec('git', ['status']);
console.log(output.stdout);
```

## Event System

### Tauri Events
```typescript
import { listen, emit } from '@tauri-apps/api/event';

// Listen for events
const unlisten = await listen('my-event', (event) => {
  console.log(event.payload);
});

// Emit events
await emit('my-event', { data: 'value' });
```

### Craft Events
```typescript
import { events } from 'ts-craft';

// Listen for events
const unsubscribe = events.on('my-event', (payload) => {
  console.log(payload);
});

// Emit events
events.emit('my-event', { data: 'value' });
```

## Plugins

### Tauri Plugins
Tauri uses Rust plugins that require Cargo dependencies and Rust code.

### Craft Plugins
Craft uses TypeScript/JavaScript plugins:

```typescript
// craft.config.ts
import { defineConfig } from 'ts-craft';
import analyticsPlugin from '@craft/plugin-analytics';

export default defineConfig({
  plugins: [
    analyticsPlugin({
      trackingId: 'UA-XXXXX-X'
    })
  ]
});
```

## Building and Packaging

### Tauri
```bash
# Development
npm run tauri dev

# Build
npm run tauri build
```

### Craft
```bash
# Development
craft dev

# Build for current platform
craft build

# Build for specific platforms
craft build --platform macos,windows,linux
```

## Framework Integration

### With React

**Tauri (no built-in hooks):**
```typescript
import { appWindow } from '@tauri-apps/api/window';
import { useEffect, useState } from 'react';

function useWindow() {
  const [title, setTitle] = useState('');

  useEffect(() => {
    appWindow.title().then(setTitle);
  }, []);

  return { title, setTitle: (t) => appWindow.setTitle(t) };
}
```

**Craft (built-in hooks):**
```typescript
import { useWindow, useCraft, useTray } from 'ts-craft/utils/react';

function App() {
  const { title, setTitle, minimize, maximize } = useWindow();
  const { platform, isDarkMode } = useCraft();
  const { show: showTray, setMenu } = useTray();

  return <div>...</div>;
}
```

### With Vue

**Craft provides Vue composables:**
```vue
<script setup>
import { useCraft, useWindow, useTray } from 'ts-craft/utils/vue';

const { state: craft, setDarkMode } = useCraft();
const { state: window, setTitle, minimize } = useWindow();
const { show: showTray, setMenu } = useTray();
</script>
```

### With Svelte

**Craft provides Svelte stores and actions:**
```svelte
<script>
import { craftStore, windowStore, shortcut } from 'ts-craft/utils/svelte';

$: platform = $craftStore.platform;
$: isDark = $craftStore.isDarkMode;
</script>

<button use:shortcut={{ key: 'ctrl+s', callback: save }}>
  Save
</button>
```

## Mobile Support

One major advantage of Craft over Tauri is built-in mobile support:

```typescript
// craft.config.ts
export default defineConfig({
  // Same config works for desktop and mobile
  platforms: ['macos', 'windows', 'linux', 'ios', 'android'],

  ios: {
    bundleId: 'com.example.myapp',
    teamId: 'XXXXXXXXXX',
  },

  android: {
    packageName: 'com.example.myapp',
  },
});
```

## Migration Checklist

- [ ] Convert `tauri.conf.json` to `craft.config.ts`
- [ ] Replace `@tauri-apps/api/*` imports with `ts-craft`
- [ ] Remove `src-tauri` directory (no Rust needed)
- [ ] Update build scripts in `package.json`
- [ ] Migrate custom commands to TypeScript bridge calls
- [ ] Update any plugins to Craft equivalents
- [ ] Test on all target platforms

## Common Issues

### CORS Issues
Both Tauri and Craft run web content in a native webview, so CORS restrictions don't apply to HTTP requests made through the native APIs.

### Path Handling
Craft uses web-standard paths. For platform-specific paths, use the path utilities:
```typescript
import { path } from 'ts-craft';

const appDir = await path.appDir();
const homeDir = await path.homeDir();
```

### Binary Size
Craft typically produces smaller binaries than Tauri due to the optimized Zig runtime.

## Getting Help

- [Craft Documentation](https://craft.dev/docs)
- [Discord Community](https://discord.gg/craft)
- [GitHub Issues](https://github.com/example/craft/issues)
