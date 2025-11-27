# React Hooks

React hooks for integrating Craft APIs with React applications.

## Import

```typescript
import {
  useCraft,
  useWindow,
  useTray,
  useNotification,
  useShortcut,
  useTheme,
  useMobile
} from 'ts-craft/react'
```

## Hooks

### useCraft()

Access the core Craft instance and initialization state.

```typescript
function App() {
  const { craft, isReady, error } = useCraft()

  if (!isReady) {
    return <Loading />
  }

  if (error) {
    return <Error message={error.message} />
  }

  return <MainApp />
}
```

**Returns:**
| Property | Type | Description |
|----------|------|-------------|
| craft | `Craft` | Craft instance |
| isReady | `boolean` | True when Craft is initialized |
| error | `Error \| null` | Initialization error, if any |

---

### useWindow()

Control the application window.

```typescript
function TitleBar() {
  const {
    title,
    setTitle,
    isFullscreen,
    setFullscreen,
    isMaximized,
    minimize,
    maximize,
    close
  } = useWindow()

  return (
    <div className="title-bar">
      <span>{title}</span>
      <div className="controls">
        <button onClick={minimize}>−</button>
        <button onClick={() => setFullscreen(!isFullscreen)}>⤢</button>
        <button onClick={close}>×</button>
      </div>
    </div>
  )
}
```

**Returns:**
| Property | Type | Description |
|----------|------|-------------|
| title | `string` | Window title |
| setTitle | `(title: string) => void` | Set window title |
| isFullscreen | `boolean` | Fullscreen state |
| setFullscreen | `(fullscreen: boolean) => void` | Toggle fullscreen |
| isMaximized | `boolean` | Maximized state |
| minimize | `() => void` | Minimize window |
| maximize | `() => void` | Maximize/restore window |
| close | `() => void` | Close window |
| focus | `() => void` | Focus window |
| center | `() => void` | Center window on screen |

---

### useTray(config?)

Manage the system tray icon.

```typescript
function AppWithTray() {
  const { isVisible, show, hide, setIcon, setTooltip } = useTray({
    icon: '/assets/tray-icon.png',
    tooltip: 'My App',
    menu: [
      { label: 'Show', action: 'show' },
      { label: 'Hide', action: 'hide' },
      { type: 'separator' },
      { label: 'Quit', action: 'quit' }
    ],
    onAction: (action) => {
      switch (action) {
        case 'show':
          window.show()
          break
        case 'quit':
          window.close()
          break
      }
    }
  })

  return (
    <div>
      <button onClick={() => setTooltip('New notification!')}>
        Update tooltip
      </button>
    </div>
  )
}
```

**Config:**
| Property | Type | Description |
|----------|------|-------------|
| icon | `string` | Path to tray icon |
| tooltip | `string` | Tooltip text |
| menu | `MenuItem[]` | Context menu items |
| onAction | `(action: string) => void` | Menu action handler |

**Returns:**
| Property | Type | Description |
|----------|------|-------------|
| isVisible | `boolean` | Tray visibility |
| show | `() => void` | Show tray icon |
| hide | `() => void` | Hide tray icon |
| setIcon | `(path: string) => void` | Update icon |
| setTooltip | `(text: string) => void` | Update tooltip |

---

### useNotification()

Show desktop notifications.

```typescript
function NotificationButton() {
  const { show, requestPermission, hasPermission } = useNotification()

  const handleClick = async () => {
    if (!hasPermission) {
      await requestPermission()
    }

    await show({
      title: 'New Message',
      body: 'You have a new message from John',
      icon: '/assets/icon.png',
      onClick: () => {
        navigateToMessages()
      }
    })
  }

  return <button onClick={handleClick}>Send Notification</button>
}
```

**Returns:**
| Property | Type | Description |
|----------|------|-------------|
| show | `(options: NotificationOptions) => Promise<void>` | Show notification |
| requestPermission | `() => Promise<boolean>` | Request permission |
| hasPermission | `boolean` | Permission granted |

---

### useShortcut(shortcut, handler)

Register global keyboard shortcuts.

```typescript
function Editor() {
  const [content, setContent] = useState('')

  // Save on Cmd+S / Ctrl+S
  useShortcut('mod+s', async (e) => {
    e.preventDefault()
    await saveDocument(content)
  })

  // Undo on Cmd+Z / Ctrl+Z
  useShortcut('mod+z', () => {
    undo()
  })

  // Open search with Cmd+K
  useShortcut('mod+k', () => {
    openSearchModal()
  })

  return <textarea value={content} onChange={e => setContent(e.target.value)} />
}
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| shortcut | `string` | Key combination (e.g., 'mod+s', 'shift+alt+p') |
| handler | `(event: KeyboardEvent) => void` | Callback function |

**Shortcut syntax:**
- `mod` - Command on macOS, Ctrl on Windows/Linux
- `ctrl`, `alt`, `shift`, `meta` - Modifier keys
- `+` - Combine keys (e.g., 'ctrl+shift+s')
- Letters, numbers, F1-F12, arrows, etc.

---

### useTheme()

Access and control the application theme.

```typescript
function ThemeToggle() {
  const { theme, setTheme, systemTheme } = useTheme()

  return (
    <select value={theme} onChange={e => setTheme(e.target.value)}>
      <option value="system">System ({systemTheme})</option>
      <option value="light">Light</option>
      <option value="dark">Dark</option>
    </select>
  )
}
```

**Returns:**
| Property | Type | Description |
|----------|------|-------------|
| theme | `'light' \| 'dark' \| 'system'` | Current theme setting |
| setTheme | `(theme: string) => void` | Set theme |
| systemTheme | `'light' \| 'dark'` | System preference |
| isDark | `boolean` | True if dark mode active |

---

### useMobile()

Access mobile-specific APIs (iOS/Android).

```typescript
function MobileApp() {
  const {
    platform,
    haptics,
    biometrics,
    secureStorage,
    safeAreaInsets
  } = useMobile()

  const handleTap = async () => {
    await haptics.impact('light')
  }

  const handleLogin = async () => {
    if (await biometrics.isAvailable()) {
      const result = await biometrics.authenticate({
        reason: 'Sign in to your account'
      })
      if (result.success) {
        // Logged in
      }
    }
  }

  return (
    <div style={{ paddingTop: safeAreaInsets.top }}>
      <button onClick={handleTap}>Tap me</button>
      <button onClick={handleLogin}>Login with Face ID</button>
    </div>
  )
}
```

**Returns:**
| Property | Type | Description |
|----------|------|-------------|
| platform | `'ios' \| 'android' \| null` | Mobile platform |
| haptics | `Haptics` | Haptics API |
| biometrics | `Biometrics` | Biometrics API |
| secureStorage | `SecureStorage` | Secure storage API |
| safeAreaInsets | `Insets` | Safe area insets |

## Example App

```typescript
import React, { useState, useEffect } from 'react'
import {
  useCraft,
  useWindow,
  useTheme,
  useShortcut,
  useNotification
} from 'ts-craft/react'

function App() {
  const { isReady } = useCraft()
  const { setTitle } = useWindow()
  const { isDark, setTheme } = useTheme()
  const { show: notify } = useNotification()
  const [count, setCount] = useState(0)

  // Update window title
  useEffect(() => {
    setTitle(`Counter: ${count}`)
  }, [count, setTitle])

  // Keyboard shortcuts
  useShortcut('mod+up', () => setCount(c => c + 1))
  useShortcut('mod+down', () => setCount(c => c - 1))
  useShortcut('mod+r', () => setCount(0))

  // Theme toggle shortcut
  useShortcut('mod+t', () => {
    setTheme(isDark ? 'light' : 'dark')
  })

  if (!isReady) {
    return <div>Loading...</div>
  }

  return (
    <div className={`app ${isDark ? 'dark' : 'light'}`}>
      <h1>Count: {count}</h1>

      <div className="buttons">
        <button onClick={() => setCount(c => c - 1)}>-</button>
        <button onClick={() => setCount(c => c + 1)}>+</button>
      </div>

      <button
        onClick={() => notify({
          title: 'Counter Update',
          body: `Count is now ${count}`
        })}
      >
        Notify
      </button>

      <p className="hint">
        Use ⌘↑/⌘↓ to increment/decrement, ⌘R to reset, ⌘T to toggle theme
      </p>
    </div>
  )
}

export default App
```
