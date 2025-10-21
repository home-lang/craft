# Zyte JavaScript Bridge - Quick Reference

## 🚀 Getting Started

```javascript
// Wait for bridge to be ready
window.addEventListener('zyte:ready', () => {
  // Your code here
});
```

## 📱 System Tray API

```javascript
// Update tray title
await window.zyte.tray.setTitle('🍅 25:00')

// Set tooltip
await window.zyte.tray.setTooltip('Click to toggle window')

// Handle clicks
const unregister = window.zyte.tray.onClick((event) => {
  console.log('Clicked!', event.button)
})

// Toggle window on click (convenience)
window.zyte.tray.onClickToggleWindow()

// Set context menu
await window.zyte.tray.setMenu([
  { label: 'Show Window', action: 'show' },
  { type: 'separator' },
  { label: 'Quit', action: 'quit' }
])
```

## 🪟 Window API

```javascript
// Show window
await window.zyte.window.show()

// Hide window
await window.zyte.window.hide()

// Toggle visibility
await window.zyte.window.toggle()

// Minimize
await window.zyte.window.minimize()

// Close
await window.zyte.window.close()
```

## 🎯 App API

```javascript
// Hide dock icon (menubar-only mode)
await window.zyte.app.hideDockIcon()

// Show dock icon
await window.zyte.app.showDockIcon()

// Quit app
await window.zyte.app.quit()

// Get app info
const info = await window.zyte.app.getInfo()
```

## 🛠️ CLI Usage

```bash
# Basic system tray
zyte http://localhost:3000 --system-tray

# Menubar-only app
zyte http://localhost:3000 --system-tray --hide-dock-icon

# All options
zyte http://localhost:3000 \
  --title "My App" \
  --width 400 \
  --height 600 \
  --system-tray \
  --hide-dock-icon \
  --dark
```

## 📦 TypeScript Usage

```typescript
import { createApp, type ZyteBridgeAPI } from 'ts-zyte'

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

## 💡 Common Patterns

### Pomodoro Timer

```javascript
let timeLeft = 25 * 60

function updateTray() {
  const mins = Math.floor(timeLeft / 60)
  const secs = timeLeft % 60
  window.zyte.tray.setTitle(`🍅 ${mins}:${secs.toString().padStart(2, '0')}`)
}

setInterval(() => {
  if (timeLeft > 0) timeLeft--
  updateTray()
}, 1000)

window.zyte.tray.onClickToggleWindow()
```

### Status Monitor

```javascript
async function updateStatus() {
  const status = await getSystemStatus()
  window.zyte.tray.setTitle(`CPU: ${status.cpu}%`)
}

setInterval(updateStatus, 2000)
```

### Download Progress

```javascript
function updateProgress(percent) {
  window.zyte.tray.setTitle(`⬇️ ${percent}%`)

  if (percent === 100) {
    window.zyte.window.show()
  }
}
```

## ⚡ Quick Tips

1. **Keep tray titles short** - Max 20 chars on macOS
2. **Use emoji** - Great for visual status: 🍅 ✓ ⏸️ ▶️
3. **Always catch errors** - Bridge calls can fail
4. **Unregister listeners** - Prevent memory leaks
5. **Wait for ready** - Use `zyte:ready` event

## 🐛 Troubleshooting

### Bridge not available?

```javascript
if (!window.zyte) {
  console.error('Zyte bridge not available')
  return
}
```

### Safe async calls

```javascript
try {
  await window.zyte.tray.setTitle('Title')
} catch (err) {
  console.warn('Failed:', err)
}
```

## 📚 Full Documentation

See [BRIDGE_API.md](./BRIDGE_API.md) for complete API reference.

## 🎨 Examples

See `packages/typescript/examples/` for working demos:
- `pomodoro-timer.html` - Complete Pomodoro timer app

## 🤝 Contributing

Found a bug or want a feature? Open an issue on [GitHub](https://github.com/stacksjs/zyte/issues).
