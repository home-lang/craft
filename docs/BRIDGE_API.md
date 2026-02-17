# Craft JavaScript Bridge API

The Craft JavaScript Bridge provides a seamless interface for your web application to control native features like the system tray, window management, and application behavior.

## Table of Contents

- [Overview](#overview)
- [Getting Started](#getting-started)
- [System Tray API](#system-tray-api)
- [Window API](#window-api)
- [App API](#app-api)
- [TypeScript Support](#typescript-support)
- [Examples](#examples)

## Overview

The bridge is automatically injected into your WebView at document start. No additional setup is required - simply use `window.craft` in your JavaScript code.

```javascript
// Wait for bridge to be ready
window.addEventListener('craft:ready', () => {
  console.log('Craft bridge is ready!');
  // Your code here
});

// Or check if already available
if (window.craft) {
  // Bridge is ready
}
```

## Getting Started

### Basic Usage

```javascript
// Update system tray
await window.craft.tray.setTitle('🍅 25:00');

// Toggle window visibility
await window.craft.window.toggle();

// Hide dock icon (menubar-only mode)
await window.craft.app.hideDockIcon();
```

### CLI Integration

Enable system tray from the command line:

```bash
craft http://localhost:3000 --system-tray --hide-dock-icon
```

### TypeScript Integration

```typescript
import { createApp } from '@stacksjs/ts-craft'

const app = createApp({
  url: 'http://localhost:3000',
  window: {
    systemTray: true,
    hideDockIcon: true,
    width: 400,
    height: 600
  }
})

await app.show()
```

## System Tray API

Control the system tray icon from your web application.

### `window.craft.tray.setTitle(title: string): Promise<void>`

Update the system tray title/text.

```javascript
// Show a Pomodoro timer
await window.craft.tray.setTitle('🍅 25:00');

// Show app status
await window.craft.tray.setTitle('✓ Ready');
```

**Note:** On macOS, titles are limited to ~20 characters to avoid menubar overflow.

### `window.craft.tray.setTooltip(tooltip: string): Promise<void>`

Set tooltip text that appears on hover.

```javascript
await window.craft.tray.setTooltip('Pomodoro Timer - Click to toggle');
```

### `window.craft.tray.onClick(callback: Function): Function`

Register a click handler for the tray icon.

```javascript
const unregister = window.craft.tray.onClick((event) => {
  console.log('Tray clicked!', event);
  // event.button: 'left' | 'right' | 'middle'
  // event.timestamp: number
  // event.modifiers: { command?, shift?, option?, control? }
});

// Later: unregister the handler
unregister();
```

### `window.craft.tray.onClickToggleWindow(): Function`

Convenience method: toggle window visibility on tray click.

```javascript
const unregister = window.craft.tray.onClickToggleWindow();
```

### `window.craft.tray.setMenu(items: MenuItem[]): Promise<void>`

Set a context menu for the tray icon.

```javascript
await window.craft.tray.setMenu([
  { label: 'Show Window', action: 'show' },
  { type: 'separator' },
  { label: 'Start Timer', action: 'start-timer' },
  { label: 'Pause Timer', action: 'pause-timer' },
  { type: 'separator' },
  { label: 'Quit', action: 'quit' }
]);

// Listen for custom menu actions
window.addEventListener('craft:tray:menu', (event) => {
  if (event.detail.action === 'start-timer') {
    startTimer();
  }
});
```

**MenuItem Interface:**

```typescript
interface MenuItem {
  id?: string
  label?: string
  type?: 'normal' | 'separator' | 'checkbox' | 'radio'
  checked?: boolean
  enabled?: boolean
  action?: 'show' | 'hide' | 'toggle' | 'quit' | string
  shortcut?: string
  submenu?: MenuItem[]
}
```

## Window API

Control the application window from JavaScript.

### `window.craft.window.show(): Promise<void>`

Show the window.

```javascript
await window.craft.window.show();
```

### `window.craft.window.hide(): Promise<void>`

Hide the window.

```javascript
await window.craft.window.hide();
```

### `window.craft.window.toggle(): Promise<void>`

Toggle window visibility.

```javascript
await window.craft.window.toggle();
```

### `window.craft.window.minimize(): Promise<void>`

Minimize the window.

```javascript
await window.craft.window.minimize();
```

### `window.craft.window.close(): Promise<void>`

Close the window (and quit the app if it's the last window).

```javascript
await window.craft.window.close();
```

## App API

Application-level controls.

### `window.craft.app.hideDockIcon(): Promise<void>`

Hide the dock icon (macOS only). Creates a menubar-only application.

```javascript
await window.craft.app.hideDockIcon();
```

**Note:** Best used with `--system-tray` to ensure the app remains accessible.

### `window.craft.app.showDockIcon(): Promise<void>`

Show the dock icon (macOS only).

```javascript
await window.craft.app.showDockIcon();
```

### `window.craft.app.quit(): Promise<void>`

Quit the application.

```javascript
await window.craft.app.quit();
```

### `window.craft.app.getInfo(): Promise<AppInfo>`

Get application information.

```javascript
const info = await window.craft.app.getInfo();
console.log(info);
// { name: 'MyApp', version: '1.0.0', platform: 'macos' }
```

## TypeScript Support

Full TypeScript definitions are included:

```typescript
declare global {
  interface Window {
    craft: {
      tray: {
        setTitle(title: string): Promise<void>
        setTooltip(tooltip: string): Promise<void>
        onClick(callback: (event: TrayClickEvent) => void): () => void
        onClickToggleWindow(): () => void
        setMenu(items: MenuItem[]): Promise<void>
      }
      window: {
        show(): Promise<void>
        hide(): Promise<void>
        toggle(): Promise<void>
        minimize(): Promise<void>
        close(): Promise<void>
      }
      app: {
        hideDockIcon(): Promise<void>
        showDockIcon(): Promise<void>
        quit(): Promise<void>
        getInfo(): Promise<AppInfo>
      }
    }
  }
}
```

Import types:

```typescript
import type { CraftBridgeAPI, TrayClickEvent, MenuItem } from '@stacksjs/ts-craft'
```

## Examples

### Pomodoro Timer

See the complete example in `packages/typescript/examples/pomodoro-timer.html`

Key features:
- Updates tray title with countdown
- Click tray to toggle window
- Shows window when timer completes
- Menubar-only mode (optional)

Run it:

```bash
# From the repository root
craft packages/typescript/examples/pomodoro-timer.html --system-tray

# Or with menubar-only mode
craft packages/typescript/examples/pomodoro-timer.html --system-tray --hide-dock-icon
```

### Music Player

```javascript
let isPlaying = false;

// Update tray based on playback state
function updateTray() {
  const icon = isPlaying ? '▶️' : '⏸️';
  const title = `${icon} ${currentTrack.title}`;
  window.craft.tray.setTitle(title);
}

// Set up tray menu
window.craft.tray.setMenu([
  { label: 'Play/Pause', action: 'toggle-playback' },
  { label: 'Next Track', action: 'next-track' },
  { label: 'Previous Track', action: 'prev-track' },
  { type: 'separator' },
  { label: 'Show Window', action: 'show' },
  { label: 'Quit', action: 'quit' }
]);

// Handle menu actions
window.addEventListener('craft:tray:menu', (event) => {
  switch (event.detail.action) {
    case 'toggle-playback':
      togglePlayback();
      break;
    case 'next-track':
      nextTrack();
      break;
    case 'prev-track':
      previousTrack();
      break;
  }
});
```

### System Monitor

```javascript
// Update tray with system stats
async function updateStats() {
  const cpu = await getCPUUsage();
  const mem = await getMemoryUsage();

  const title = `CPU: ${cpu}% | RAM: ${mem}%`;
  await window.craft.tray.setTitle(title);
}

// Update every 2 seconds
setInterval(updateStats, 2000);

// Click tray to show detailed view
window.craft.tray.onClick(() => {
  window.craft.window.show();
});
```

### Download Manager

```javascript
// Show progress in tray
function updateProgress(percent) {
  const bars = Math.floor(percent / 10);
  const progress = '▓'.repeat(bars) + '░'.repeat(10 - bars);
  window.craft.tray.setTitle(`⬇️ ${percent}%`);
  window.craft.tray.setTooltip(`Downloading: ${progress}`);
}

// Show window when complete
async function onComplete() {
  await window.craft.tray.setTitle('✓ Done');
  await window.craft.window.show();
}
```

## Platform Support

| Feature | macOS | Windows | Linux |
|---------|-------|---------|-------|
| Tray Title | ✅ | ✅ | ✅ |
| Tray Tooltip | ✅ | ✅ | ✅ |
| Tray Click | ✅ | 🚧 | 🚧 |
| Tray Menu | 🚧 | 🚧 | 🚧 |
| Window Control | ✅ | ✅ | ✅ |
| Hide Dock Icon | ✅ | ➖ | ➖ |

✅ Implemented | 🚧 In Progress | ➖ Not Applicable

## Best Practices

1. **Always check for bridge availability:**
   ```javascript
   if (window.craft) {
     // Safe to use
   }
   ```

2. **Handle errors gracefully:**
   ```javascript
   try {
     await window.craft.tray.setTitle('Title');
   } catch (err) {
     console.warn('Failed to update tray:', err);
   }
   ```

3. **Keep tray titles short:**
   - Max 20 characters on macOS
   - Use emoji for visual indicators: 🍅 ✓ ⏸️ ▶️

4. **Unregister event listeners:**
   ```javascript
   const unregister = window.craft.tray.onClick(handler);
   // When done:
   unregister();
   ```

5. **Combine with system tray:**
   - Always use `--system-tray` when using tray API
   - Consider `--hide-dock-icon` for menubar-only apps

## Troubleshooting

### Bridge not available

If `window.craft` is undefined:

1. Ensure you're using Craft 1.3.0 or later
2. Wait for the `craft:ready` event
3. Check the browser console for injection errors

### Tray not updating

Common issues:

1. Tray not created: Use `--system-tray` flag
2. Title too long: Keep under 20 characters
3. Invalid emoji: Some emoji may not render properly

### TypeScript errors

Ensure you have the latest type definitions:

```bash
bun add ts-craft@latest
```

Or manually import types:

```typescript
/// <reference types="@stacksjs/ts-craft" />
```

## Contributing

Found a bug or have a feature request? Please open an issue on [GitHub](https://github.com/stacksjs/craft/issues).

## License

MIT License - see [LICENSE](../LICENSE) for details.
