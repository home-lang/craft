# Craft Todo App

A cross-platform Todo application demonstrating Craft's capabilities.

## Features

- **Persistent Storage**: Uses Craft's SQLite database API for local storage
- **Cross-Platform**: Runs on iOS, Android, macOS, Windows, and Linux
- **Native Feel**: Haptic feedback on mobile, keyboard shortcuts on desktop
- **Dark Mode**: Automatic theme switching based on system preference
- **Accessibility**: Full keyboard navigation and screen reader support

## Project Structure

```
todo-app/
├── src/
│   ├── index.ts      # Main application code
│   └── styles.css    # Application styles
├── index.html        # Entry point
├── craft.config.ts   # Craft configuration
└── package.json      # Dependencies
```

## Getting Started

### Development

```bash
# Install dependencies
bun install

# Start development server
bun run dev
```

### Building

```bash
# Build for current platform
bun run build

# Build for specific platforms
bun run build:ios
bun run build:android
bun run build:macos
bun run build:windows
bun run build:linux
```

## Craft APIs Used

### Database API

```typescript
import { db } from '@stacksjs/ts-craft'

const database = db.openDatabase('todos.db')

await database.execute(`
  CREATE TABLE IF NOT EXISTS todos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    text TEXT NOT NULL,
    completed INTEGER DEFAULT 0
  )
`)

const todos = await database.query('SELECT * FROM todos')
```

### Mobile APIs

```typescript
import { haptics, isMobile } from '@stacksjs/ts-craft'

if (isMobile()) {
  // Light haptic feedback when adding a todo
  haptics.impact('light')

  // Success notification when completing a todo
  haptics.notification('success')
}
```

### Platform Detection

```typescript
import { getPlatform, isDesktop, isMobile } from '@stacksjs/ts-craft'

console.log(getPlatform()) // 'ios', 'android', 'macos', 'windows', 'linux'

if (isDesktop()) {
  // Register keyboard shortcuts
  document.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'n') {
      // Focus new todo input
    }
  })
}
```

## Styling

The app uses vanilla CSS with CSS custom properties for theming. It supports:

- Light and dark mode via `prefers-color-scheme`
- Reduced motion via `prefers-reduced-motion`
- Safe area insets for iOS notch/home indicator
- Responsive design for all screen sizes

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl+N` | Focus new todo input |
| `Enter` | Add new todo / Save edit |
| `Escape` | Cancel editing |
| `Double-click` | Edit todo |

## License

MIT
