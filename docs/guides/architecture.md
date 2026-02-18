# Architecture

Understanding how Craft works under the hood.

## Overview

Craft is a cross-platform application framework that combines:

1. **Zig Core** - Native runtime for performance-critical operations
2. **WebView** - Platform-native WebView for rendering
3. **TypeScript SDK** - Developer-friendly APIs
4. **Native Bridge** - Communication between JS and native code

```
┌─────────────────────────────────────────────────────────────┐
│                     Your Application                         │
│                  (HTML, CSS, JavaScript)                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    TypeScript SDK                            │
│   window, notification, fs, db, http, crypto, process       │
│   mobile (haptics, biometrics, location, camera)            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Native Bridge                            │
│            JSON-RPC over WebView messaging                   │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌───────────────────┐ ┌─────────────┐ ┌─────────────────────┐
│   Zig Core        │ │  WebView    │ │  Platform Native    │
│   - Memory mgmt   │ │  - WKWebView│ │  - Swift/ObjC (iOS) │
│   - Performance   │ │  - WebView2 │ │  - Kotlin (Android) │
│   - Crypto        │ │  - WebKitGTK│ │  - Win32 (Windows)  │
│   - Networking    │ │             │ │  - GTK (Linux)      │
└───────────────────┘ └─────────────┘ └─────────────────────┘
```

## Zig Core

The Zig core provides:

- **Cross-compilation** - Build for any platform from any platform
- **Memory safety** - No garbage collection, predictable performance
- **Small binaries** - Final apps are typically <10MB
- **Fast startup** - ~168 ms cold start on most platforms

### Key Modules

```
packages/zig/src/
├── main.zig           # Entry point
├── webview.zig        # WebView management
├── window.zig         # Window management
├── system.zig         # System integration
├── bridge.zig         # JS-native bridge
├── mobile.zig         # Mobile platform support
├── memory.zig         # Memory management
├── gpu.zig            # GPU acceleration
├── hotreload.zig      # Development hot reload
└── platform/
    ├── macos.zig      # macOS-specific code
    ├── windows.zig    # Windows-specific code
    ├── linux.zig      # Linux-specific code
    ├── ios.zig        # iOS-specific code
    └── android.zig    # Android-specific code
```

## WebView

Craft uses the platform's native WebView:

| Platform | WebView |
|----------|---------|
| macOS | WKWebView |
| Windows | WebView2 (Edge Chromium) |
| Linux | WebKitGTK |
| iOS | WKWebView |
| Android | Android WebView |

Benefits of native WebView:
- **Smaller app size** - No bundled browser
- **System updates** - WebView updated by OS
- **Native feel** - Matches platform behavior
- **Security** - Sandboxed by default

## Native Bridge

The bridge connects JavaScript to native functionality:

```typescript
// JavaScript side
const result = await window.craft.invoke('fs.readFile', {
  path: '/path/to/file.txt'
})

// Bridge protocol
{
  "id": "123",
  "method": "fs.readFile",
  "params": { "path": "/path/to/file.txt" }
}

// Response
{
  "id": "123",
  "result": "file contents here"
}
```

### Bridge Features

1. **Async by default** - All calls return Promises
2. **Type-safe** - TypeScript definitions match native implementations
3. **Batching** - Multiple calls can be batched for efficiency
4. **Binary support** - Efficient transfer of binary data
5. **Streaming** - Support for streaming responses

## TypeScript SDK

The SDK provides a clean API layer:

```
packages/typescript/src/
├── index.ts           # Main exports
├── types.ts           # Type definitions
├── api/
│   ├── window.ts      # Window API
│   ├── notification.ts# Notification API
│   ├── fs.ts          # File system API
│   ├── db.ts          # Database API
│   ├── http.ts        # HTTP client API
│   ├── crypto.ts      # Crypto API
│   ├── process.ts     # Process API
│   └── mobile.ts      # Mobile APIs
├── components/
│   └── index.ts       # UI components
├── styles/
│   └── headwind.ts    # CSS utilities
└── utils/
    ├── react.ts       # React bindings
    ├── vue.ts         # Vue bindings
    └── svelte.ts      # Svelte bindings
```

## Build Process

```
Source Files                      Build Output
─────────────────────────────────────────────────
craft.config.ts    ─┐
src/main.ts        ─┼──▶ Bundler ──▶ dist/
src/styles.css     ─┤              ├── index.html
index.html         ─┘              ├── main.js
                                   └── styles.css

Zig Sources        ─┐
├── main.zig       ─┤
├── webview.zig    ─┼──▶ Zig Build ──▶ Platform Binary
├── window.zig     ─┤                  ├── MyApp.app (macOS)
└── platform/*.zig ─┘                  ├── MyApp.exe (Windows)
                                       └── myapp (Linux)
```

## Platform-Specific Details

### macOS

```
MyApp.app/
├── Contents/
│   ├── Info.plist
│   ├── MacOS/
│   │   └── MyApp           # Zig binary
│   ├── Resources/
│   │   ├── AppIcon.icns
│   │   └── web/            # Web assets
│   │       ├── index.html
│   │       ├── main.js
│   │       └── styles.css
│   └── Frameworks/
│       └── (optional frameworks)
```

### Windows

```
MyApp/
├── MyApp.exe               # Zig binary
├── WebView2Loader.dll      # WebView2 bootstrap
├── resources/
│   └── web/
│       ├── index.html
│       ├── main.js
│       └── styles.css
└── app.ico
```

### iOS

```
MyApp.app/
├── MyApp                   # Binary
├── Info.plist
├── Assets.car              # Asset catalog
├── www/                    # Web assets
│   ├── index.html
│   ├── main.js
│   └── styles.css
└── Frameworks/
```

### Android

```
app/
├── src/main/
│   ├── java/.../MainActivity.kt
│   ├── assets/web/         # Web assets
│   │   ├── index.html
│   │   ├── main.js
│   │   └── styles.css
│   ├── res/
│   └── AndroidManifest.xml
└── build.gradle
```

## Memory Model

Craft uses a hybrid memory model:

1. **JavaScript heap** - Managed by WebView's JS engine
2. **Native memory** - Managed by Zig's allocator
3. **Bridge buffers** - Shared memory for data transfer

```
┌─────────────────────────────────────────────┐
│                  WebView                     │
│  ┌─────────────────────────────────────┐    │
│  │         JavaScript Heap              │    │
│  │   (V8/JavaScriptCore managed)        │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
                    │ Bridge
                    ▼
┌─────────────────────────────────────────────┐
│               Native (Zig)                   │
│  ┌─────────────────────────────────────┐    │
│  │      General Purpose Allocator       │    │
│  │   - Arena allocators for requests    │    │
│  │   - Pool allocators for objects      │    │
│  │   - Tracking for leak detection      │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

## Security Model

Craft implements multiple security layers:

1. **WebView sandbox** - Web content is sandboxed
2. **Capability-based permissions** - Apps declare needed permissions
3. **Code signing** - All releases are signed
4. **Hardened runtime** - macOS hardened runtime enabled

```typescript
// Permissions in craft.config.ts
macos: {
  entitlements: {
    'com.apple.security.network.client': true,
    'com.apple.security.files.user-selected.read-write': true
    // Only requested permissions are available
  }
}
```

## Performance Characteristics

| Metric | Typical Value |
|--------|---------------|
| Cold start | ~168 ms |
| Binary size | 5-15 MB |
| Memory usage | 50-150 MB |
| Bridge latency | <1ms |
| JS execution | V8/JSC speed |

## Comparison with Alternatives

| Feature | Craft | Electron | Tauri | React Native |
|---------|-------|----------|-------|--------------|
| Binary size | Small | Large | Small | Medium |
| Memory | Low | High | Low | Medium |
| Startup | Fast | Slow | Fast | Medium |
| Web tech | Yes | Yes | Yes | No (native) |
| Desktop | Yes | Yes | Yes | Limited |
| Mobile | Yes | No | In progress | Yes |
| Language | Zig/TS | JS | Rust | JS |
