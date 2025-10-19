<p align="center"><img src=".github/art/cover.jpg" alt="Social Card of this repo"></p>

[![npm version][npm-version-src]][npm-version-href]
[![GitHub Actions][github-actions-src]][github-actions-href]
[![Commitizen friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/)
<!-- [![npm downloads][npm-downloads-src]][npm-downloads-href] -->
<!-- [![Codecov][codecov-src]][codecov-href] -->

# Zyte

**Build desktop apps with web languages, powered by Zig**

Zyte is a lightweight, high-performance desktop application framework. Create native desktop apps that work on macOS, Linux, and Windows with web technologies - all with a tiny 1.4MB binary and blazing fast <100ms startup time.

**Version 1.3.0** | **79 Features** | **1.4MB Binary** | **Production-Ready** | **Cross-Platform**

## Features

Zyte comes pre-configured with comprehensive desktop app capabilities:

### 🎯 Core Platform
- ⚡ **Native Performance** - <100ms startup, <1% CPU idle, ~92MB memory
- 🪶 **Tiny Binary** - 1.4MB binary size (vs 150MB Electron)
- 🌍 **Cross-Platform** - macOS, Linux, and Windows support
- 🚀 **WebView Integration** - WKWebView (macOS), WebKit2GTK (Linux), WebView2 (Windows)
- 🔧 **Zig-Powered** - Built with Zig 0.15.1 for maximum performance

### 🛠️ Developer Experience
- 📟 **Powerful CLI** - 20+ command-line flags for quick prototyping
- 🔍 **DevTools** - Built-in WebKit DevTools (right-click > Inspect Element)
- 🎨 **Custom Styles** - Frameless, transparent, always-on-top windows
- 🌉 **JavaScript Bridge** - Seamless communication between JS and Zig
- 💾 **File Dialogs** - Native open/save dialogs
- 📋 **Clipboard** - Read/write clipboard access
- ⚙️ **Configuration** - TOML-based config files
- 📊 **Logging** - Structured logging system
- 🍔 **Menu Support** - Native menu bars
- 🔥 **Hot Reload** - File watching and auto-reload

### 🪟 Window Management
- 📏 **Position Control** - Precise window positioning (x, y)
- 🖥️ **Fullscreen** - Native fullscreen mode
- 🔄 **State Management** - Minimize, maximize, close, hide, show
- 🔔 **Notifications** - Native OS notifications
- ↔️ **Resize Control** - Custom resize behavior
- 🪟 **Multi-Window** - Multiple window support
- 🖥️ **Multi-Monitor** - Multi-monitor awareness

### 🎨 Advanced Features (v1.1.0)
- 🎮 **GPU Acceleration** - Metal (macOS), Vulkan (Linux/Windows), OpenGL fallback
- 📡 **Advanced IPC** - Message passing, channels, RPC, shared memory
- 🖌️ **Native Rendering** - Canvas API, component system, pixel manipulation
- ⌨️ **Enhanced Shortcuts** - 90+ key codes with modifiers
- ♿ **Accessibility** - WCAG 2.1 AAA compliance, screen readers

### 🎭 Theming & Performance (v1.2.0)
- 🌓 **Advanced Theming** - Nord, Dracula, Gruvbox, custom themes
- 💨 **Performance** - LRU caching, object pooling, lazy loading, memoization
- 📊 **Monitoring** - Built-in performance profiling

### ✨ Latest - v1.3.0
- 🔄 **Async/Await** - Non-blocking I/O, streaming, promises, channels
- 🧩 **WebAssembly** - WASM plugin system with sandboxing
- 💬 **Native Dialogs** - File, directory, color, font pickers
- 🎬 **Animations** - 31 easing functions, keyframes, springs
- 🔄 **State Management** - Reactive state with observers, undo/redo

### 🏢 Enterprise Ready
- 🔌 **Plugin System** - Dynamic library loading
- 🛡️ **Sandbox** - 7 permission types for security
- 🌐 **i18n** - Internationalization with RTL support
- 🔐 **Code Signing** - macOS, Windows, Linux
- 📦 **Installers** - DMG, PKG, MSI, DEB, RPM, AppImage
- 🔄 **Auto-Updater** - Built-in update mechanism
- 📸 **Screen Capture** - Screenshots and recording
- 🖨️ **Print Support** - Native printing
- 📥 **Downloads** - Download management
- 🔌 **WebSocket** - Real-time communication
- 🔗 **Custom Protocols** - Register custom URL handlers (zyte://)
- 🎯 **Drag & Drop** - File drag and drop support

## Get Started

### Quick Installation

```bash
# Install via npm
npm install -g @stacksjs/zyte

# Or with Bun (recommended)
bun add -g @stacksjs/zyte
```

### Build from Source

```bash
# Clone the repository
git clone https://github.com/stacksjs/zyte.git
cd zyte

# Install Zig 0.15.1
# macOS
brew install zig

# Linux
wget https://ziglang.org/download/0.15.1/zig-linux-x86_64-0.15.1.tar.xz
tar -xf zig-linux-x86_64-0.15.1.tar.xz

# Build
zig build

# Run
./zig-out/bin/zyte-minimal http://localhost:3000
```

### Platform-Specific Dependencies

**Linux:**
```bash
sudo apt-get install -y libgtk-3-dev libwebkit2gtk-4.0-dev
```

**Windows:**
```powershell
winget install Microsoft.EdgeWebView2Runtime
```

## Usage

### Simple Window

```bash
# Launch a local development server
zyte http://localhost:3000

# With custom options
zyte http://localhost:3000 \
  --title "My App" \
  --width 1200 \
  --height 800 \
  --dark \
  --hot-reload
```

### CLI Options

```bash
zyte [OPTIONS] [URL]

Window Content:
  -u, --url <URL>          Load URL in the window
      --html <HTML>        Load HTML content directly

Window Appearance:
  -t, --title <TITLE>      Window title (default: "Zyte App")
  -w, --width <WIDTH>      Window width (default: 1200)
      --height <HEIGHT>    Window height (default: 800)
  -x, --x <X>              Window x position
  -y, --y <Y>              Window y position

Window Style:
      --frameless          Create frameless window
      --transparent        Make window transparent
      --always-on-top      Keep window always on top
  -f, --fullscreen         Start in fullscreen mode
      --no-resize          Disable window resizing

Theme:
      --dark               Force dark mode
      --light              Force light mode

Features:
      --hot-reload         Enable hot reload
      --system-tray        Show system tray icon
      --no-devtools        Disable WebKit DevTools

Information:
  -h, --help               Show help
  -v, --version            Show version
```

### Zig API

```zig
const std = @import("std");
const zyte = @import("zyte");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = zyte.App.init(allocator);
    defer app.deinit();

    _ = try app.createWindowWithURL(
        "My App",
        1200,
        800,
        "http://localhost:3000",
        .{
            .dark_mode = true,
            .hot_reload = true,
        },
    );

    try app.run();
}
```

## Examples

### Multi-Window App

```zig
// Main window
_ = try app.createWindowWithURL(
    "Main",
    1920,
    1080,
    "http://localhost:3000/main",
    .{ .x = 0, .y = 0 },
);

// Secondary window
_ = try app.createWindowWithURL(
    "Secondary",
    1920,
    1080,
    "http://localhost:3000/secondary",
    .{ .x = 1920, .y = 0 },
);
```

### WebSocket Integration

```zig
const ws = try WebSocket.connect(allocator, "ws://localhost:8080");
defer ws.deinit();

try ws.send("Hello, Server!");
const message = try ws.receive();
ws.close();
```

### State Management

```zig
const state = State.init(allocator);
defer state.deinit();

// Set values
try state.set("count", StateValue{ .int = 0 });

// Observe changes
try state.observe("count", Observer{
    .id = 1,
    .fn_ptr = onCountChange,
});

// Update triggers observer
try state.set("count", StateValue{ .int = 1 });
```

### Animations

```zig
var animation = Animation.init(0.0, 1.0, 300, .ease_in_out_quad);
animation.start();

while (!animation.isComplete()) {
    const value = animation.update();
    // Use animated value
}
```

More examples in the [examples/](examples/) directory and [API_REFERENCE.md](API_REFERENCE.md).

## Performance

| Metric | Zyte | Electron | Tauri |
|--------|------|----------|-------|
| Binary Size | **1.4MB** | ~150MB | ~2MB |
| Memory (idle) | **~92MB** | ~200MB | ~80MB |
| Startup Time | **<100ms** | ~1000ms | ~100ms |
| CPU (idle) | **<1%** | ~4% | <1% |
| Features | **79** | High | Medium |

## Documentation

- 📖 [API Reference](API_REFERENCE.md) - Complete API documentation
- 🚀 [Quick Start](QUICK_START.md) - Get started quickly
- 📘 [Getting Started](GETTING_STARTED.md) - Detailed guide
- ✨ [Features](FEATURES.md) - Complete feature list
- 🤝 [Contributing](CONTRIBUTING.md) - Contribution guide
- 📋 [Changelog](https://github.com/stacksjs/zyte/releases) - Release history

## Platform Support

| Platform | Status | WebView | Features |
|----------|--------|---------|----------|
| **macOS** | ✅ Production | WKWebView | All 79 features |
| **Linux** | ✅ Production | WebKit2GTK 4.0+ | All 79 features |
| **Windows** | ✅ Production | WebView2 (Edge) | All 79 features |

## Roadmap

### v1.4.0 (Next)
- Enhanced plugin marketplace
- Additional animation presets
- Improved state management patterns
- More dialog types

### v2.0.0 (Future)
- Mobile platform support (iOS/Android)
- Advanced GPU rendering
- Native components library
- Breaking API improvements

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Community

For help, discussion about best practices, or any other conversation:

- 💬 [Discussions on GitHub](https://github.com/stacksjs/zyte/discussions)
- 💭 [Join the Stacks Discord Server](https://discord.gg/stacksjs)

## Postcardware

Zyte is free software, but we'd love to receive a postcard from where you're using it! We showcase them on our website.

**Our address:** Stacks.js, 12665 Village Ln #2306, Playa Vista, CA 90094, United States 🌎

## Sponsors

We would like to extend our thanks to the following sponsors for funding Stacks development:

- [JetBrains](https://www.jetbrains.com/)
- [The Solana Foundation](https://solana.com/)

## License

The MIT License (MIT). Please see [LICENSE](LICENSE.md) for more information.

Made with 💙

<!-- Badges -->
[npm-version-src]: https://img.shields.io/npm/v/@stacksjs/zyte?style=flat-square
[npm-version-href]: https://npmjs.com/package/@stacksjs/zyte
[github-actions-src]: https://img.shields.io/github/actions/workflow/status/stacksjs/zyte/ci.yml?style=flat-square&branch=main
[github-actions-href]: https://github.com/stacksjs/zyte/actions?query=workflow%3Aci
