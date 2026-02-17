# Introduction

Craft is a lightweight, high-performance cross-platform application framework. Build native desktop apps using web technologies with a tiny 1.4MB binary and blazing fast startup times.

## What is Craft?

Craft enables you to create native desktop applications using HTML, CSS, and JavaScript, powered by a high-performance Zig runtime. Think of it as a modern, lightweight alternative to Electron.

## Key Highlights

- **Tiny Binary**: 1.4MB vs Electron's 150MB
- **Fast Startup**: <100ms startup time
- **Low Memory**: ~92MB vs Electron's ~200MB
- **Cross-Platform**: macOS, Linux, Windows, iOS, and Android
- **Native Performance**: Built with Zig for maximum efficiency

## Platform Support

| Platform | Status | WebView |
|----------|--------|---------|
| macOS | Production | WKWebView |
| Linux | Production | WebKit2GTK 4.0+ |
| Windows | Production | WebView2 (Edge) |
| iOS | Beta | WKWebView |
| Android | Beta | WebView |

## Quick Start

### Using TypeScript (Recommended)

The easiest way to build Craft apps is with TypeScript:

```bash
# Install the TypeScript SDK
bun add ts-craft

# Create your app
```

```typescript
// app.ts
import { show } from '@stacksjs/ts-craft'

const html = `
<!DOCTYPE html>
<html>
<head>
  <style>
    body {
      margin: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      font-family: system-ui;
    }
  </style>
</head>
<body>
  <h1>My First Craft App</h1>
</body>
</html>
`

await show(html, { title: 'My App', width: 800, height: 600 })
```

```bash
# Run it
bun run app.ts
```

### Using create-craft

Scaffold a new project quickly:

```bash
# Create a new Craft app
bun create craft my-app

# Navigate to your app
cd my-app

# Start development
bun run dev
```

## Core Features

### Window Management

Full control over window appearance and behavior:

```typescript
import { show } from '@stacksjs/ts-craft'

await show(html, {
  title: 'My App',
  width: 1200,
  height: 800,
  frameless: true,
  transparent: true,
  alwaysOnTop: false,
})
```

### Webview Integration

Load any web content - HTML strings, local files, or URLs:

```typescript
// HTML string
await show('<h1>Hello World</h1>')

// Local file
await show({ file: './index.html' })

// URL
await show({ url: 'https://example.com' })
```

### JavaScript Bridge

Seamless communication between your web content and native code:

```typescript
// In your JavaScript
window.craft.send('greet', { name: 'World' })

// In your native code
app.on('greet', (data) => {
  console.log(`Hello, ${data.name}!`)
})
```

### Native Components

35+ native UI components available:

- Input: Button, TextInput, Checkbox, Slider, DatePicker
- Display: Label, ImageView, ProgressBar, Avatar, Badge
- Layout: ScrollView, SplitView, Modal, Tabs
- Data: ListView, Table, TreeView, DataGrid, Chart
- Navigation: TabView, Menu, Toolbar

### Menubar Applications

Build native system tray/menubar apps:

```typescript
import { createMenubar } from '@stacksjs/ts-craft'

const menubar = await createMenubar({
  icon: './icon.png',
  tooltip: 'My App',
  menu: [
    { label: 'Show Window', click: () => app.show() },
    { type: 'separator' },
    { label: 'Quit', click: () => app.quit() },
  ],
})
```

### System Integration

Access native system features:

- **Notifications**: Native OS notifications
- **Clipboard**: Read/write text and images
- **File Dialogs**: Open, save, select directory
- **System Info**: OS, CPU, memory, battery
- **URL Handling**: Custom URL schemes

## Performance Comparison

| Metric | Craft | Electron | Tauri |
|--------|-------|----------|-------|
| Binary Size | **1.4MB** | ~150MB | ~2MB |
| Memory (idle) | **~92MB** | ~200MB | ~80MB |
| Startup Time | **<100ms** | ~1000ms | ~100ms |
| CPU (idle) | **<1%** | ~4% | <1% |

## Architecture

Craft uses a modular architecture:

```
Your App (HTML/CSS/JS)
        │
        ▼
┌───────────────────────────────────────┐
│           JavaScript Bridge           │
├───────────────────────────────────────┤
│              Craft Core               │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ │
│  │ Window  │ │ WebView │ │  IPC    │ │
│  └─────────┘ └─────────┘ └─────────┘ │
├───────────────────────────────────────┤
│         Platform Abstraction          │
├───────────────────────────────────────┤
│    macOS    │   Linux   │   Windows   │
│  WKWebView  │ WebKit2GTK│  WebView2   │
└───────────────────────────────────────┘
```

## Use Cases

### Desktop Applications

Build full-featured desktop apps:

- Productivity tools
- Creative applications
- Development tools
- Data visualization

### Menubar Utilities

Create lightweight system tray apps:

- Status monitors
- Quick actions
- Timers and reminders
- Clipboard managers

### Internal Tools

Build cross-platform internal tools:

- Admin dashboards
- Database viewers
- Log analyzers
- DevOps utilities

## Next Steps

- [Installation](/install) - Install Craft
- [Usage](/usage) - Learn the basics
- [Configuration](/config) - Configure your app
- [Window Management](/features/window-management) - Control windows
- [IPC Communication](/features/ipc-communication) - Bridge native and web
