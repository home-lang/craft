# Configuration

Craft supports multiple configuration formats for maximum flexibility.

## Configuration Files

Craft searches for configuration files in this order:

1. `craft.toml` (TOML format)
2. `craft.json` (JSON format)
3. `package.jsonc` (JSON with comments)
4. `package.json` (standard JSON)
5. `craft.config.ts` (TypeScript)
6. `craft.config.js` (JavaScript)

## TOML Configuration

```toml
# craft.toml

[package]
name = "my-craft-app"
version = "1.0.0"
authors = ["Your Name <you@example.com>"]
description = "A cross-platform desktop application"
license = "MIT"

[window]
title = "My App"
width = 1200
height = 800
minWidth = 400
minHeight = 300
resizable = true
frameless = false
transparent = false
alwaysOnTop = false

[webview]
devTools = true
darkMode = true
hotReload = true

[build]
outDir = "./dist"
target = ["macos", "linux", "windows"]

[scripts]
dev = "bun run dev"
build = "bun run build"
test = "bun test"
```

## JSON Configuration

```json
{
  "name": "my-craft-app",
  "version": "1.0.0",
  "description": "A cross-platform desktop application",

  "window": {
    "title": "My App",
    "width": 1200,
    "height": 800,
    "minWidth": 400,
    "minHeight": 300
  },

  "webview": {
    "devTools": true,
    "darkMode": true
  },

  "build": {
    "outDir": "./dist",
    "target": ["macos", "linux", "windows"]
  }
}
```

## TypeScript Configuration

```typescript
// craft.config.ts
import type { CraftConfig } from '@stacksjs/ts-craft'

export default {
  // Package metadata
  name: 'my-craft-app',
  version: '1.0.0',
  description: 'A cross-platform desktop application',

  // Window configuration
  window: {
    title: 'My App',
    width: 1200,
    height: 800,
    minWidth: 400,
    minHeight: 300,
    maxWidth: 1920,
    maxHeight: 1080,
    center: true,
    resizable: true,
    frameless: false,
    transparent: false,
    alwaysOnTop: false,
  },

  // Webview configuration
  webview: {
    devTools: process.env.NODE_ENV === 'development',
    darkMode: true,
    hotReload: true,
    userAgent: undefined, // Custom user agent
  },

  // Build configuration
  build: {
    outDir: './dist',
    target: ['macos', 'linux', 'windows'],
    icon: './assets/icon.png',
    resources: ['./assets/**/*'],
  },

  // Development
  dev: {
    port: 3000,
    hotReload: true,
    watch: ['./src/**/*'],
  },
} satisfies CraftConfig
```

## Configuration Reference

### Package Options

| Option | Type | Description |
|--------|------|-------------|
| `name` | string | Application name |
| `version` | string | Version number (semver) |
| `description` | string | App description |
| `authors` | string[] | List of authors |
| `license` | string | License identifier |

### Window Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `title` | string | `'Craft'` | Window title |
| `width` | number | `800` | Initial width in pixels |
| `height` | number | `600` | Initial height in pixels |
| `minWidth` | number | - | Minimum width |
| `minHeight` | number | - | Minimum height |
| `maxWidth` | number | - | Maximum width |
| `maxHeight` | number | - | Maximum height |
| `x` | number | - | Initial X position |
| `y` | number | - | Initial Y position |
| `center` | boolean | `true` | Center window on screen |
| `resizable` | boolean | `true` | Allow resizing |
| `frameless` | boolean | `false` | Remove window frame |
| `transparent` | boolean | `false` | Transparent background |
| `alwaysOnTop` | boolean | `false` | Keep above other windows |
| `fullscreen` | boolean | `false` | Start in fullscreen |
| `maximized` | boolean | `false` | Start maximized |
| `minimized` | boolean | `false` | Start minimized |
| `visible` | boolean | `true` | Initially visible |

### Webview Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `devTools` | boolean | `false` | Enable developer tools |
| `darkMode` | boolean | `false` | Use dark mode |
| `hotReload` | boolean | `false` | Enable hot reload |
| `userAgent` | string | - | Custom user agent string |
| `javascript` | boolean | `true` | Enable JavaScript |
| `localStorage` | boolean | `true` | Enable localStorage |

### Build Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `outDir` | string | `'./dist'` | Output directory |
| `target` | string[] | `['current']` | Build targets |
| `icon` | string | - | Path to app icon |
| `resources` | string[] | - | Additional resources to bundle |
| `appId` | string | - | Application identifier |

### Development Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `port` | number | `3000` | Dev server port |
| `hotReload` | boolean | `true` | Enable hot reload |
| `watch` | string[] | - | Files to watch |
| `ignore` | string[] | - | Files to ignore |

## Environment Variables

Override configuration with environment variables:

```bash
CRAFT_WINDOW_WIDTH=1920
CRAFT_WINDOW_HEIGHT=1080
CRAFT_DEV_TOOLS=true
CRAFT_DARK_MODE=true
```

## Environment-Specific Configuration

```typescript
// craft.config.ts
const isDev = process.env.NODE_ENV === 'development'

export default {
  window: {
    title: isDev ? 'My App (Dev)' : 'My App',
    width: 1200,
    height: 800,
  },

  webview: {
    devTools: isDev,
    hotReload: isDev,
  },

  build: {
    outDir: isDev ? './dev-build' : './dist',
  },
}
```

## Dependencies Configuration

### Local Path Dependencies

```toml
[dependencies]
my-lib = { path = "../my-lib" }
```

### Git Dependencies

```toml
[dependencies]
craft-plugin = { git = "https://github.com/user/craft-plugin.git" }
```

### Version Dependencies

```toml
[dependencies]
some-lib = { version = "^1.0.0" }
# Or shorthand
another-lib = "^2.0.0"
```

## Workspace Configuration

For monorepo setups:

```toml
# Root craft.toml
[package]
name = "my-workspace"
version = "0.1.0"

[workspaces]
packages = [
    "packages/core",
    "packages/ui",
    "apps/*"
]

[scripts]
build = "zig build"
test = "zig build test"
```

## Scripts

Define custom commands:

```toml
[scripts]
dev = "bun run dev"
build = "zig build -Doptimize=ReleaseFast"
test = "bun test"
lint = "eslint src/"
format = "prettier --write src/"
```

Run with:

```bash
craft run dev
craft run build
```

## Complete Example

```toml
# craft.toml - Complete configuration example

[package]
name = "my-desktop-app"
version = "1.0.0"
authors = ["Your Name <you@example.com>"]
description = "A beautiful desktop application"
license = "MIT"

[window]
title = "My Desktop App"
width = 1200
height = 800
minWidth = 800
minHeight = 600
center = true
resizable = true
frameless = false
transparent = false
alwaysOnTop = false

[webview]
devTools = false
darkMode = true
hotReload = false

[build]
outDir = "./dist"
target = ["macos", "linux", "windows"]
icon = "./assets/icon.png"
resources = ["./assets/**/*"]
appId = "com.mycompany.myapp"

[dependencies]
craft-ui = "^1.0.0"

[scripts]
dev = "bun run dev"
build = "craft build"
build-mac = "craft build --target macos"
build-linux = "craft build --target linux"
build-windows = "craft build --target windows"
test = "bun test"
```

## Next Steps

- [Window Management](/features/window-management) - Window configuration details
- [Webview Integration](/features/webview-integration) - Webview options
- [Advanced Configuration](/advanced/configuration) - Advanced settings
