# Craft JavaScript Bridge - Quick Reference

## 🚀 Getting Started

```javascript
// Wait for bridge to be ready
window.addEventListener('craft:ready', () => {
  // Your code here
});
```

## 📱 System Tray API

```javascript
// Update tray title
await window.craft.tray.setTitle('🍅 25:00')

// Set tooltip
await window.craft.tray.setTooltip('Click to toggle window')

// Handle clicks
const unregister = window.craft.tray.onClick((event) => {
  console.log('Clicked!', event.button)
})

// Toggle window on click (convenience)
window.craft.tray.onClickToggleWindow()

// Set context menu
await window.craft.tray.setMenu([
  { label: 'Show Window', action: 'show' },
  { type: 'separator' },
  { label: 'Quit', action: 'quit' }
])
```

## 🪟 Window API

```javascript
// Show window
await window.craft.window.show()

// Hide window
await window.craft.window.hide()

// Toggle visibility
await window.craft.window.toggle()

// Minimize
await window.craft.window.minimize()

// Close
await window.craft.window.close()
```

## 🎯 App API

```javascript
// Hide dock icon (menubar-only mode)
await window.craft.app.hideDockIcon()

// Show dock icon
await window.craft.app.showDockIcon()

// Quit app
await window.craft.app.quit()

// Get app info
const info = await window.craft.app.getInfo()
```

## 🛠️ CLI Usage

```bash
# Basic system tray
craft http://localhost:3000 --system-tray

# Menubar-only app
craft http://localhost:3000 --system-tray --hide-dock-icon

# All options
craft http://localhost:3000 \
  --title "My App" \
  --width 400 \
  --height 600 \
  --system-tray \
  --hide-dock-icon \
  --dark
```

## 📦 TypeScript Usage

```typescript
import { createApp, type CraftBridgeAPI } from '@craft-native/craft'

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
  window.craft.tray.setTitle(`🍅 ${mins}:${secs.toString().padStart(2, '0')}`)
}

setInterval(() => {
  if (timeLeft > 0) timeLeft--
  updateTray()
}, 1000)

window.craft.tray.onClickToggleWindow()
```

### Status Monitor

```javascript
async function updateStatus() {
  const status = await getSystemStatus()
  window.craft.tray.setTitle(`CPU: ${status.cpu}%`)
}

setInterval(updateStatus, 2000)
```

### Download Progress

```javascript
function updateProgress(percent) {
  window.craft.tray.setTitle(`⬇️ ${percent}%`)

  if (percent === 100) {
    window.craft.window.show()
  }
}
```

## ⚡ Quick Tips

1. **Keep tray titles short** - Max 20 chars on macOS
2. **Use emoji** - Great for visual status: 🍅 ✓ ⏸️ ▶️
3. **Always catch errors** - Bridge calls can fail
4. **Unregister listeners** - Prevent memory leaks
5. **Wait for ready** - Use `craft:ready` event

## 🐛 Troubleshooting

### Bridge not available

```javascript
if (!window.craft) {
  console.error('Craft bridge not available')
  return
}
```

### Safe async calls

```javascript
try {
  await window.craft.tray.setTitle('Title')
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

Found a bug or want a feature? Open an issue on [GitHub](https://github.com/home-lang/craft/issues).
