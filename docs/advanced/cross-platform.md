# Cross-Platform Development

Craft supports building applications for macOS, Linux, Windows, iOS, and Android from a single codebase.

## Platform Support

| Platform | Status | WebView | Native Components |
|----------|--------|---------|-------------------|
| **macOS** | Production | WKWebView | Full support |
| **Linux** | Production | WebKit2GTK 4.0+ | Full support |
| **Windows** | Production | WebView2 (Edge) | Full support |
| **iOS** | Beta | WKWebView | UIKit |
| **Android** | Beta | WebView | Material |

## Platform Detection

### Runtime Detection

```typescript
import { platform, arch, isDesktop, isMobile } from 'ts-craft'

console.log(platform) // 'darwin' | 'win32' | 'linux' | 'ios' | 'android'
console.log(arch) // 'arm64' | 'x64'
console.log(isDesktop) // true for macOS/Windows/Linux
console.log(isMobile) // true for iOS/Android
```

### Conditional Code

```typescript
import { platform } from 'ts-craft'

if (platform === 'darwin') {
  // macOS-specific code
  enableDockIntegration()
}
else if (platform === 'win32') {
  // Windows-specific code
  enableTaskbarIntegration()
}
else if (platform === 'linux') {
  // Linux-specific code
  enableDesktopIntegration()
}
```

### Platform-Specific Imports

```typescript
// Dynamically import platform-specific modules
const platformFeatures = await import(
  platform === 'darwin'
    ? './features/macos'
    : platform === 'win32'
      ? './features/windows'
      : './features/linux'
)
```

## Platform-Specific Features

### macOS

```typescript
import { mac } from 'ts-craft/platform'

// Dock
mac.dock.setBadge('3')
mac.dock.setIcon('./assets/icon.png')
mac.dock.bounce() // Bounce dock icon

// Touch Bar
mac.touchBar.setItems([
  { type: 'button', label: 'Action', click: () => {} },
  { type: 'slider', min: 0, max: 100, value: 50 },
])

// Menu Bar
mac.systemMenu.setApplicationMenu(menu)

// Vibrancy
window.setVibrancy('under-window')
```

### Windows

```typescript
import { win } from 'ts-craft/platform'

// Taskbar
win.taskbar.setProgress(0.5)
win.taskbar.setOverlayIcon('./badge.ico', 'Status')
win.taskbar.setFlashFrame(true)

// Jump List
win.jumpList.setItems([
  {
    type: 'task',
    title: 'New Window',
    program: process.execPath,
    args: '--new-window',
  },
])

// Thumbnail Toolbar
win.thumbnailToolbar.setButtons([
  { icon: './play.ico', tooltip: 'Play', click: () => play() },
  { icon: './pause.ico', tooltip: 'Pause', click: () => pause() },
])
```

### Linux

```typescript
import { linux } from 'ts-craft/platform'

// Desktop Integration
linux.desktop.setCategory('Utility')
linux.desktop.setKeywords(['editor', 'code'])

// Unity Launcher
linux.unity.setBadge('5')
linux.unity.setProgress(0.75)

// System Tray
linux.tray.setIcon('./tray-icon.png')
linux.tray.setTooltip('My App')
```

## UI Considerations

### Native Look and Feel

```typescript
// Use system font
const html = `
<style>
  body {
    font-family: system-ui, -apple-system, BlinkMacSystemFont,
      "Segoe UI", Roboto, Ubuntu, "Helvetica Neue", sans-serif;
  }
</style>
`

// Respect system dark mode
const window = await createWindow(html, {
  webview: {
    darkMode: 'auto', // Follow system preference
  },
})
```

### Platform-Specific Styling

```css
/* macOS-style buttons */
@supports (-webkit-appearance: none) and (font: -apple-system-body) {
  .button {
    border-radius: 6px;
    background: linear-gradient(180deg, #fff 0%, #f2f2f2 100%);
  }
}

/* Windows-style buttons */
@media (-ms-high-contrast: none), (-ms-high-contrast: active) {
  .button {
    border-radius: 2px;
    background: #0078d4;
  }
}
```

### Responsive Window Sizing

```typescript
const window = await createWindow(html, {
  // Different defaults per platform
  width: platform === 'darwin' ? 1200 : 1000,
  height: platform === 'darwin' ? 800 : 700,

  // Minimum sizes
  minWidth: 800,
  minHeight: 600,
})
```

## File System Differences

### Path Handling

```typescript
import { path } from 'ts-craft'

// Use platform-agnostic path joining
const configPath = path.join(app.getPath('userData'), 'config.json')

// Platform-specific paths
const paths = {
  darwin: '~/Library/Application Support/MyApp',
  win32: '%APPDATA%/MyApp',
  linux: '~/.config/MyApp',
}
```

### File Dialogs

```typescript
import { dialog } from 'ts-craft'

const result = await dialog.showOpenDialog({
  // Platform-appropriate defaults
  defaultPath: platform === 'darwin'
    ? '~/Documents'
    : platform === 'win32'
      ? '%USERPROFILE%/Documents'
      : '~/Documents',

  // Platform-appropriate filters
  filters: [
    {
      name: 'Documents',
      extensions: platform === 'darwin'
        ? ['doc', 'docx', 'pages']
        : ['doc', 'docx'],
    },
  ],
})
```

## Keyboard Shortcuts

### Platform-Aware Shortcuts

```typescript
import { platform, shortcuts } from 'ts-craft'

// Use platform-appropriate modifier
const modifier = platform === 'darwin' ? 'Cmd' : 'Ctrl'

shortcuts.register(`${modifier}+S`, save)
shortcuts.register(`${modifier}+Shift+S`, saveAs)
shortcuts.register(`${modifier}+Q`, quit) // macOS only typically

// Or use accelerators
shortcuts.register('CmdOrCtrl+S', save) // Automatically uses Cmd on macOS
```

### Platform-Specific Shortcuts

```typescript
if (platform === 'darwin') {
  // macOS-specific shortcuts
  shortcuts.register('Cmd+,', openPreferences) // Standard on macOS
}
else {
  // Windows/Linux shortcuts
  shortcuts.register('Ctrl+Alt+S', openSettings)
}
```

## Building for Multiple Platforms

### Build Configuration

```typescript
// craft.config.ts
export default {
  build: {
    target: ['macos', 'linux', 'windows'],

    mac: {
      target: ['dmg', 'pkg'],
      arch: ['arm64', 'x64'], // Universal binary
      category: 'public.app-category.productivity',
    },

    win: {
      target: ['msi', 'nsis'],
      arch: ['x64'],
    },

    linux: {
      target: ['deb', 'rpm', 'AppImage'],
      arch: ['x64'],
    },
  },
}
```

### CI/CD for Cross-Platform

```yaml
# .github/workflows/build.yml
name: Build

on: [push, pull_request]

jobs:
  build:
    strategy:
      matrix:
        os: [macos-latest, ubuntu-latest, windows-latest]

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - uses: oven-sh/setup-bun@v1

      - name: Install dependencies
        run: bun install

      - name: Build
        run: bun run build

      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: build-${{ matrix.os }}
          path: dist/
```

## Testing Cross-Platform

### Platform-Specific Tests

```typescript
import { describe, test, expect } from 'bun:test'
import { platform } from 'ts-craft'

describe('Platform Features', () => {
  test.skipIf(platform !== 'darwin')('macOS dock badge', async () => {
    const { mac } = await import('ts-craft/platform')
    mac.dock.setBadge('5')
    expect(mac.dock.getBadge()).toBe('5')
  })

  test.skipIf(platform !== 'win32')('Windows taskbar', async () => {
    const { win } = await import('ts-craft/platform')
    win.taskbar.setProgress(0.5)
    expect(win.taskbar.getProgress()).toBe(0.5)
  })
})
```

### Virtual Machine Testing

```bash
# Test on macOS (requires macOS)
bun run test:mac

# Test on Windows (VM or cross-compile)
bun run test:win

# Test on Linux (VM or container)
docker run -v $(pwd):/app craft-linux-test
```

## Mobile Support (Beta)

### iOS

```typescript
import { ios } from 'ts-craft/platform'

// iOS-specific features
ios.haptic.feedback('impact') // Haptic feedback
ios.statusBar.setStyle('light') // Status bar
ios.safeArea.getInsets() // Safe area for notch

// Permissions
await ios.requestPermission('camera')
await ios.requestPermission('notifications')
```

### Android

```typescript
import { android } from 'ts-craft/platform'

// Android-specific features
android.vibrate(100) // Vibration
android.statusBar.setColor('#000000') // Status bar color
android.navigationBar.setColor('#ffffff') // Navigation bar

// Permissions
await android.requestPermission('CAMERA')
await android.requestPermission('READ_EXTERNAL_STORAGE')
```

## Best Practices

### Design Guidelines

1. **Follow platform conventions**: Use native patterns
2. **Respect system preferences**: Dark mode, font size, etc.
3. **Use native controls**: When possible
4. **Test on real devices**: Don't rely only on emulators

### Code Organization

```
src/
├── core/            # Platform-agnostic code
├── platform/
│   ├── common.ts    # Shared platform code
│   ├── macos.ts     # macOS-specific
│   ├── windows.ts   # Windows-specific
│   ├── linux.ts     # Linux-specific
│   └── index.ts     # Platform detection & export
└── main.ts          # Entry point
```

### Feature Detection

```typescript
import { features } from 'ts-craft'

// Check feature availability
if (features.touchBar) {
  enableTouchBar()
}

if (features.darkMode) {
  enableDarkModeToggle()
}

if (features.notifications) {
  enableNotifications()
}
```

## Next Steps

- [Configuration](/advanced/configuration) - Platform-specific config
- [Performance](/advanced/performance) - Platform optimization
- [Custom Bindings](/advanced/custom-bindings) - Native platform code
