# Craft Examples

This directory contains example applications demonstrating various features of Craft.

## System Tray / Menubar Apps

### 1. System Tray App (`system-tray-app.ts`)

A comprehensive example showing how to build a system tray application with Craft.

**Features:**
- System tray icon
- Background operation
- Desktop notifications
- Quick actions menu
- Activity logging
- Window show/hide functionality

**Run it:**
```bash
bun run examples/system-tray-app.ts
```

**What it demonstrates:**
- Creating a system tray application
- Managing window visibility
- Sending notifications
- Background processing
- User interaction logging
- Keyboard shortcuts (ESC to hide)

---

### 2. Pomodoro Timer (`pomodoro.ts`) ⭐ NEW!

A minimal, fully functional Pomodoro timer with live menubar updates.

**Features:**
- **Live timer in menubar** - Shows countdown in window title (visible in menubar)
- 25-minute work sessions (🍅 emoji)
- 5-minute breaks (☕ emoji)
- Real-time updates every second
- Session statistics (today, streak, total)
- Persistent stats across restarts
- Desktop notifications
- Keyboard shortcuts
- Pause indicator in menubar
- Clean, minimal UI

**Run it:**
```bash
bun examples/pomodoro.ts
```

**Menubar Display:**
- Before starting: `🍅 25:00`
- While running: `🍅 24:32`
- When paused: `🍅 15:45 (Paused)`
- During break: `☕ 5:00`

**Keyboard Shortcuts:**
- `Space`: Start/Pause timer
- `R`: Reset current session
- `S`: Skip to next session
- `⌘H`: Hide window (timer continues)

---

### 3. Menubar Pomodoro Timer (`menubar-timer.ts`)

A more feature-rich Pomodoro timer with progress visualization.

**Features:**
- 25-minute work sessions
- 5-minute breaks
- Session tracking and statistics
- Desktop notifications on session complete
- Persistent stats across restarts
- Minimal, focused UI
- Always-on-top mode

**Run it:**
```bash
bun run examples/menubar-timer.ts
```

**Keyboard Shortcuts:**
- `Space`: Start/Pause timer
- `R`: Reset current session
- `S`: Skip to next session
- `ESC`: Hide window (app stays in menubar)

**What it demonstrates:**
- Building a productivity tool
- State persistence with localStorage
- Timer and interval management
- Session tracking
- Notification integration
- Keyboard shortcuts
- Progress visualization

---

## How These Examples Work

All examples use the Craft TypeScript SDK (`ts-craft`) which provides a simple API to create native desktop applications:

```typescript
import { createApp } from '../packages/typescript/src/index.ts'

const app = createApp({
  html: '<!DOCTYPE html>...',  // Your HTML content
  window: {
    title: 'My App',
    width: 600,
    height: 400,
    systemTray: true,          // Enable system tray icon
    darkMode: true,
    alwaysOnTop: false,
  }
})

await app.show()
```

## System Tray Functionality

When you enable `systemTray: true`, your app will:

1. **Show an icon in the system tray/menubar**
   - macOS: Top menu bar
   - Windows: System tray (bottom-right)
   - Linux: System tray area

2. **Support window hide/show**
   - Click tray icon to show/hide window
   - App continues running in background
   - Perfect for utility apps and background services

3. **Right-click menu (coming soon)**
   - Custom menu items
   - Quick actions
   - Show/hide toggle
   - Quit option

## Running the Examples

### Prerequisites

1. **Build the Craft core** (if not already built):
   ```bash
   cd packages/zig
   zig build
   ```

2. **Install Bun** (if not already installed):
   ```bash
   curl -fsSL https://bun.sh/install | bash
   ```

### Running an Example

From the repository root:

```bash
# System tray app
bun run examples/system-tray-app.ts

# Pomodoro timer
bun run examples/menubar-timer.ts
```

## Creating Your Own System Tray App

Here's a minimal example to get started:

```typescript
#!/usr/bin/env bun
import { createApp } from '@stacksjs/ts-craft'

const html = `
<!DOCTYPE html>
<html>
<head>
  <title>My Tray App</title>
  <style>
    body {
      margin: 0;
      padding: 20px;
      font-family: system-ui;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
    }
  </style>
</head>
<body>
  <h1>Hello from System Tray!</h1>
  <p>This app runs in your menubar/system tray.</p>
  <button onclick="alert('Button clicked!')">Click Me</button>
</body>
</html>
`

const app = createApp({
  html,
  window: {
    title: 'My Tray App',
    width: 400,
    height: 300,
    systemTray: true,  // This enables system tray mode
  }
})

await app.show()
```

Save as `my-tray-app.ts` and run with:
```bash
bun run my-tray-app.ts
```

## Tips for System Tray Apps

1. **Keep the window small** - Tray apps typically have compact UIs (300-600px wide)

2. **Use dark mode** - Many users expect menubar apps to match system appearance
   ```typescript
   window: { darkMode: true }
   ```

3. **Support keyboard shortcuts** - Add ESC to hide window
   ```javascript
   document.addEventListener('keydown', (e) => {
     if (e.key === 'Escape') {
       // Hide window (in future version)
       console.log('Hide window')
     }
   })
   ```

4. **Add notifications** - Alert users when background tasks complete
   ```javascript
   function notify(title, body) {
     // Will trigger native notification
     console.log(`Notification: ${title} - ${body}`)
   }
   ```

5. **Persist state** - Use localStorage for settings and data
   ```javascript
   localStorage.setItem('myData', JSON.stringify(data))
   const saved = JSON.parse(localStorage.getItem('myData'))
   ```

## Troubleshooting

### Binary not found
```bash
❌ Craft binary not found
```
**Solution:** Build the Craft core first:
```bash
cd packages/zig
zig build
```

### Permission denied
```bash
❌ Permission denied
```
**Solution:** Make the binary executable:
```bash
chmod +x packages/zig/zig-out/bin/craft
```

### Window doesn't appear
- Check console for errors
- Verify HTML content is valid
- Try without `systemTray: true` first to debug

## More Examples Coming Soon

- 📊 Network monitor
- 📝 Quick notes app
- 🎵 Music player controls
- 💬 Chat notifications
- 🌡️ System stats monitor
- 📅 Calendar widget

## Contributing

Have an idea for an example? PRs welcome!

1. Create your example in `examples/your-example.ts`
2. Add documentation to this README
3. Make sure it runs with `bun run examples/your-example.ts`
4. Submit a PR

## License

All examples are MIT licensed - feel free to use them as starting points for your own apps!
