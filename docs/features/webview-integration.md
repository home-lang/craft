# Webview Integration

Craft uses native webviews (WKWebView, WebKit2GTK, WebView2) to render web content with native performance.

## Overview

Webview integration provides:

- **Native Rendering**: Platform-native webview components
- **JavaScript Execution**: Run JavaScript in the webview
- **Content Loading**: Load HTML, files, or URLs
- **DevTools**: Built-in developer tools
- **Custom Protocols**: Register custom URL schemes

## Loading Content

### HTML String

```typescript
import { show } from '@stacksjs/ts-craft'

const html = `
<!DOCTYPE html>
<html>
<head>
  <title>My App</title>
</head>
<body>
  <h1>Hello, World!</h1>
</body>
</html>
`

await show(html, { title: 'HTML App' })
```

### Local File

```typescript
await show({ file: './index.html' }, { title: 'File App' })
```

### Remote URL

```typescript
await show({ url: 'https://example.com' }, { title: 'Web App' })
```

### Development Server

```typescript
await show({ url: 'http://localhost:3000' }, {
  title: 'Dev App',
  hotReload: true,
})
```

## Webview Configuration

### Full Options

```typescript
const window = await createWindow(html, {
  webview: {
    // Developer tools
    devTools: true,

    // JavaScript
    javascript: true,
    javascriptCanOpenWindows: false,

    // Storage
    localStorage: true,
    sessionStorage: true,
    indexedDB: true,

    // Media
    autoplayMedia: false,

    // Security
    webSecurity: true,

    // User agent
    userAgent: 'MyApp/1.0',

    // Appearance
    darkMode: true,
    transparentBackground: false,
  },
})
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `devTools` | boolean | `false` | Enable DevTools |
| `javascript` | boolean | `true` | Enable JavaScript |
| `localStorage` | boolean | `true` | Enable localStorage |
| `webSecurity` | boolean | `true` | Enable CORS/security |
| `userAgent` | string | - | Custom user agent |
| `darkMode` | boolean | `false` | Dark mode appearance |

## DevTools

### Enable DevTools

```typescript
const window = await createWindow(html, {
  webview: {
    devTools: true,
  },
})
```

### Open DevTools Programmatically

```typescript
// Open DevTools
window.openDevTools()

// Close DevTools
window.closeDevTools()

// Toggle DevTools
window.toggleDevTools()

// Check if open
const isOpen = window.isDevToolsOpen()
```

### DevTools Shortcuts

In development mode, use standard shortcuts:
- **macOS**: Cmd + Option + I
- **Windows/Linux**: Ctrl + Shift + I

Or right-click and select "Inspect Element".

## JavaScript Execution

### Execute JavaScript

```typescript
// Execute and get result
const result = await window.executeJavaScript('document.title')
console.log(result) // "My App"

// Execute complex script
await window.executeJavaScript(`
  const elements = document.querySelectorAll('.item')
  Array.from(elements).map(el => el.textContent)
`)
```

### Inject CSS

```typescript
await window.injectCSS(`
  body {
    background: #1a1a1a;
    color: white;
  }
`)
```

### Inject JavaScript

```typescript
// Inject script at document start
await window.injectJavaScript(`
  console.log('Script injected!')
`, { runAt: 'document-start' })
```

## Navigation

### Navigate to URL

```typescript
window.loadURL('https://example.com')
```

### Load HTML

```typescript
window.loadHTML('<h1>New Content</h1>')
```

### Load File

```typescript
window.loadFile('./pages/about.html')
```

### Navigation Events

```typescript
window.on('navigation-start', (url) => {
  console.log('Navigating to:', url)
})

window.on('navigation-end', (url) => {
  console.log('Loaded:', url)
})

window.on('navigation-error', (error) => {
  console.error('Navigation failed:', error)
})
```

### Navigation Control

```typescript
// Go back
window.goBack()

// Go forward
window.goForward()

// Reload
window.reload()

// Stop loading
window.stop()

// Check navigation
const canGoBack = window.canGoBack()
const canGoForward = window.canGoForward()
```

## Custom Protocols

### Register Protocol

```typescript
import { registerProtocol } from '@stacksjs/ts-craft'

registerProtocol('app', async (request) => {
  const path = request.url.replace('app://', '')

  if (path === 'config.json') {
    return {
      data: JSON.stringify({ version: '1.0.0' }),
      mimeType: 'application/json',
    }
  }

  // Load from file system
  const file = await Bun.file(`./app/${path}`)
  return {
    data: await file.arrayBuffer(),
    mimeType: file.type,
  }
})
```

### Use Custom Protocol

```html
<link rel="stylesheet" href="app://styles/main.css">
<script src="app://scripts/app.js"></script>
<img src="app://images/logo.png">
```

## Content Security

### Content Security Policy

```typescript
const window = await createWindow(html, {
  webview: {
    contentSecurityPolicy: "default-src 'self'; script-src 'self' 'unsafe-inline'",
  },
})
```

### Web Security

```typescript
// Disable CORS (development only!)
const window = await createWindow(html, {
  webview: {
    webSecurity: false, // Not recommended for production
  },
})
```

## Media

### Autoplay

```typescript
const window = await createWindow(html, {
  webview: {
    autoplayMedia: true,
  },
})
```

### Media Permissions

```typescript
window.on('permission-request', async (permission) => {
  if (permission.type === 'media') {
    // Auto-allow camera/microphone
    return true
  }
  return false
})
```

## Print

### Print Page

```typescript
window.print()
```

### Print to PDF

```typescript
const pdfBuffer = await window.printToPDF({
  pageSize: 'A4',
  margins: { top: 20, bottom: 20, left: 20, right: 20 },
  printBackground: true,
})

await Bun.write('output.pdf', pdfBuffer)
```

## Screenshots

### Capture Screenshot

```typescript
const imageBuffer = await window.captureScreenshot()
await Bun.write('screenshot.png', imageBuffer)
```

### Capture Region

```typescript
const imageBuffer = await window.captureScreenshot({
  x: 0,
  y: 0,
  width: 800,
  height: 600,
})
```

## Zoom

### Set Zoom

```typescript
// Set zoom level (1.0 = 100%)
window.setZoomLevel(1.5) // 150%

// Get zoom level
const zoom = window.getZoomLevel()
```

### Zoom Controls

```typescript
// Zoom in
window.zoomIn()

// Zoom out
window.zoomOut()

// Reset zoom
window.resetZoom()
```

## User Agent

### Custom User Agent

```typescript
const window = await createWindow(html, {
  webview: {
    userAgent: 'MyApp/1.0 (Craft)',
  },
})
```

### Platform-Specific User Agent

```typescript
const userAgent = process.platform === 'darwin'
  ? 'MyApp/1.0 (macOS)'
  : 'MyApp/1.0 (Windows)'

const window = await createWindow(html, {
  webview: { userAgent },
})
```

## Hot Reload

### Enable Hot Reload

```typescript
const window = await createWindow({ url: 'http://localhost:3000' }, {
  webview: {
    hotReload: true,
  },
})
```

### State Preservation

Hot reload preserves:
- Scroll position
- Form input values
- Focus state
- Custom state (via `window.craft.state`)

```html
<script>
  // Save state before reload
  window.craft.state.myData = { count: 5 }

  // State is preserved after hot reload
  console.log(window.craft.state.myData.count) // 5
</script>
```

## Best Practices

### Security

- Enable `webSecurity` in production
- Use Content Security Policy
- Validate all user input
- Avoid `executeJavaScript` with user data

### Performance

- Minimize DOM operations
- Use lazy loading for heavy content
- Avoid blocking the main thread

### Compatibility

- Test across all target platforms
- Use feature detection
- Provide fallbacks for unsupported features

## Next Steps

- [IPC Communication](/features/ipc-communication) - Native-web communication
- [Native APIs](/features/native-apis) - System integration
- [Configuration](/advanced/configuration) - Advanced webview config
