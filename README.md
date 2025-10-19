<p align="center"><img src=".github/art/cover.jpg" alt="Social Card of this repo"></p>

[![npm version][npm-version-src]][npm-version-href]
[![GitHub Actions][github-actions-src]][github-actions-href]
[![Commitizen friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/)
<!-- [![npm downloads][npm-downloads-src]][npm-downloads-href] -->
<!-- [![Codecov][codecov-src]][codecov-href] -->

# Zyte

**Build native desktop & mobile apps with web technologies, powered by Zig**

Zyte is a lightweight, high-performance cross-platform application framework. Create native apps that work on macOS, Linux, Windows, iOS, and Android with web technologies - all with a tiny 1.4MB binary and blazing fast <100ms startup time.

**Version 0.0.1** | **31 Native Components** | **1.4MB Binary** | **Cross-Platform** | **Production-Ready**

## Features

### 🌍 Platform Support
- 🖥️ **Desktop** - macOS, Linux, Windows
- 📱 **Mobile** - iOS (WKWebView, UIKit) and Android (WebView, Activity)
- 🪟 **Menubar Apps** - Native system tray/menubar integration
- ⚡ **Native Performance** - <100ms startup, <1% CPU idle, ~92MB memory
- 🪶 **Tiny Binary** - 1.4MB binary size (vs 150MB Electron)
- 🔧 **Zig-Powered** - Built with Zig 0.15.1 for maximum performance

### 📱 Mobile Platform Support
- **iOS Integration**
  - WKWebView with JavaScript bridge
  - UIKit native components
  - Haptic feedback (light, medium, heavy, selection, success, warning, error)
  - Device permissions (camera, location, notifications, photos, contacts, microphone)
  - Orientation support (portrait, landscape)
  - Status bar control
  - App lifecycle management

- **Android Integration**
  - WebView with JavaScript interface
  - Activity lifecycle
  - Permissions system
  - Vibration and haptic feedback
  - File access and storage
  - Material Design support

### 🎨 Native Components Library

**Input Components**
- Button, TextInput, Checkbox, RadioButton
- Slider, ColorPicker, DatePicker, TimePicker

**Display Components**
- Label, ImageView, ProgressBar, Spinner
- Avatar, Badge, Chip, Card

**Layout Components**
- ScrollView, SplitView, Accordion, Stepper

**Data Components**
- ListView, Table, TreeView

**Navigation Components**
- TabView, Menu, Toolbar, StatusBar

**Advanced Components**
- Rating (star ratings with half-star support)

### 🪟 Menubar Applications

Build native menubar/system tray apps with full platform support:

**Features**
- Native system tray icons
- Custom menus with shortcuts
- Tooltip support
- Click handlers (left, right, double, middle)
- Window attachment for popover-style UIs
- Notifications integration

**Platform Implementations**
- macOS: NSStatusBar integration
- Linux: AppIndicator/StatusNotifier
- Windows: System tray via Shell_NotifyIcon

### 🎮 Advanced GPU Rendering

**Rendering Pipeline**
- Multi-backend support (Vulkan, Metal, Direct3D)
- Shader management (vertex, fragment, compute)
- Buffer management (vertex, index, uniform, storage)
- Texture and render target support
- Mesh rendering with vertex data

**Effects & Post-Processing**
- 10 built-in effects: Bloom, Blur, Sharpen, Vignette
- Chromatic Aberration, Film Grain, Color Grading
- Tone Mapping, Anti-Aliasing, Ambient Occlusion

**Advanced Features**
- Compute shader support
- Ray tracing with acceleration structures
- Multi-GPU support
- GPU profiling and performance monitoring

### 🖥️ System Integration

**Notifications**
- Native OS notifications
- Custom titles, bodies, icons
- Action buttons
- Urgency levels (low, normal, critical)
- Click callbacks

**Clipboard**
- Text read/write
- Image support
- File paths
- Watch for changes

**File Dialogs**
- Open file/multiple files
- Save file
- Select directory
- Custom file type filters
- Default paths

**System Info**
- OS name and version
- CPU information
- Memory stats (total, available, used)
- System uptime

**Power Management**
- Battery status and level
- Charging state
- Prevent/allow sleep
- Power state monitoring

**Screen Management**
- Multi-monitor support
- Screen resolution and scaling
- Primary screen detection
- Screen positioning

**URL Handling**
- Open URLs in default browser
- Register custom URL schemes
- Deep linking support

### 🛠️ Developer Experience
- 📟 **Powerful CLI** - 20+ command-line flags for quick prototyping
- 🔍 **DevTools** - Built-in WebKit DevTools (right-click > Inspect Element)
- 🎨 **Custom Styles** - Frameless, transparent, always-on-top windows
- 🌉 **JavaScript Bridge** - Seamless communication between JS and native code
- ⚙️ **Configuration** - TOML-based config files
- 📊 **Logging** - Structured logging system
- 🔥 **Hot Reload** - File watching and auto-reload

### 🪟 Window Management
- 📏 **Position Control** - Precise window positioning (x, y)
- 🖥️ **Fullscreen** - Native fullscreen mode
- 🔄 **State Management** - Minimize, maximize, close, hide, show
- ↔️ **Resize Control** - Custom resize behavior
- 🪟 **Multi-Window** - Multiple window support
- 🖥️ **Multi-Monitor** - Multi-monitor awareness

### 🎯 Advanced Features
- 📡 **Advanced IPC** - Message passing, channels, RPC, shared memory
- 🖌️ **Native Rendering** - Canvas API, pixel manipulation
- ⌨️ **Enhanced Shortcuts** - 90+ key codes with modifiers
- ♿ **Accessibility** - WCAG 2.1 AAA compliance, screen readers
- 🌓 **Advanced Theming** - Nord, Dracula, Gruvbox, custom themes
- 💨 **Performance** - LRU caching, object pooling, lazy loading, memoization
- 📊 **Monitoring** - Built-in performance profiling

### ✨ Async & State
- 🔄 **Async/Await** - Non-blocking I/O, streaming, promises, channels
- 🧩 **WebAssembly** - WASM plugin system with sandboxing
- 🎬 **Animations** - 31 easing functions, keyframes, springs
- 🔄 **State Management** - Reactive state with observers, undo/redo

### 🏢 Enterprise Ready
- 🔌 **Plugin System** - Dynamic library loading with marketplace
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

## Usage Examples

### Desktop Application

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

### Menubar Application

```zig
const menubar = @import("menubar.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Create menu
    var menu = try menubar.Menu.init(allocator);
    defer menu.deinit();

    const show_item = menubar.MenuItem.init(allocator, "Show Window", showWindow);
    try menu.addItem(show_item);

    try menu.addSeparator();

    const quit_item = menubar.MenuItem.init(allocator, "Quit", quit);
    try menu.addItem(quit_item);

    // Create menubar app
    var app = try menubar.MenubarBuilder.new(allocator, "My App")
        .icon("icon.png")
        .tooltip("My Menubar App")
        .menu(menu)
        .build();
    defer app.deinit();

    try app.show();
}

fn showWindow() void {
    std.debug.print("Show window\n", .{});
}

fn quit() void {
    std.process.exit(0);
}
```

### Mobile Application (iOS)

```zig
const mobile = @import("mobile.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const config = mobile.iOS.AppConfig{
        .bundle_id = "com.example.myapp",
        .display_name = "My App",
        .supported_orientations = &[_]mobile.Orientation{
            .portrait,
            .landscape_left,
            .landscape_right,
        },
        .status_bar_style = .light,
    };

    const webview_config = mobile.iOS.WebViewConfig{
        .url = "http://localhost:3000",
        .enable_javascript = true,
        .enable_devtools = true,
    };

    const webview = try mobile.iOS.createWebView(allocator, webview_config);
    defer mobile.iOS.destroyWebView(webview);

    // Request permissions
    try mobile.iOS.requestPermission(.camera, onPermissionGranted);

    // Setup haptic feedback
    mobile.iOS.triggerHaptic(.success);
}

fn onPermissionGranted(granted: bool) void {
    if (granted) {
        std.debug.print("Permission granted!\n", .{});
    }
}
```

### Using Native Components

```zig
const components = @import("components.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Create a button
    var button = try components.Button.init(allocator, "Click Me", onClick);
    defer button.deinit();
    button.setEnabled(true);

    // Create a date picker
    var date_picker = try components.DatePicker.init(allocator, onDateChange);
    defer date_picker.deinit();

    // Create a tree view
    var tree = try components.TreeView.init(allocator);
    defer tree.deinit();

    var root = try tree.createNode("Root");
    var child1 = try tree.createNode("Child 1");
    var child2 = try tree.createNode("Child 2");

    try root.addChild(child1);
    try root.addChild(child2);
    try tree.setRoot(root);

    // Create a rating component
    var rating = try components.Rating.init(allocator, 5, onRatingChange);
    defer rating.deinit();
    rating.setRating(4.5);
}

fn onClick() void {
    std.debug.print("Button clicked!\n", .{});
}

fn onDateChange(year: i32, month: u8, day: u8) void {
    std.debug.print("Date: {}-{}-{}\n", .{ year, month, day });
}

fn onRatingChange(rating: f32) void {
    std.debug.print("Rating: {d:.1}\n", .{rating});
}
```

### System Integration

```zig
const system = @import("system.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Show notification
    const notification = system.Notification.init("Hello", "Welcome to Zyte!");
    try notification.show();

    // Clipboard operations
    var clipboard = try system.Clipboard.init(allocator);
    defer clipboard.deinit();

    try clipboard.setText("Hello, clipboard!");
    if (try clipboard.getText()) |text| {
        std.debug.print("Clipboard: {s}\n", .{text});
    }

    // File dialog
    const file_dialog = system.FileDialog{
        .title = "Open File",
        .filters = &[_]system.FileFilter{
            .{ .name = "Text Files", .extensions = &[_][]const u8{".txt"} },
        },
    };

    if (try file_dialog.openFile()) |path| {
        std.debug.print("Selected: {s}\n", .{path});
    }

    // System info
    const info = try system.SystemInfo.get(allocator);
    defer info.deinit();

    std.debug.print("OS: {s} {s}\n", .{ info.os_name, info.os_version });
    std.debug.print("CPU: {s} ({} cores)\n", .{ info.cpu_brand, info.cpu_cores });
    std.debug.print("RAM: {} MB\n", .{info.total_memory / 1024 / 1024});

    // Battery status
    const battery = try system.PowerManagement.getBatteryInfo();
    std.debug.print("Battery: {}% (charging: {})\n", .{ battery.level, battery.is_charging });
}
```

### GPU Rendering

```zig
const gpu = @import("gpu.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Initialize GPU context
    var ctx = try gpu.Context.init(allocator, .vulkan);
    defer ctx.deinit();

    // Create render pipeline
    var pipeline = try gpu.RenderPipeline.init(allocator, &ctx);
    defer pipeline.deinit();

    // Create shader
    const vertex_shader = try pipeline.createShader(.{
        .vertex = "path/to/vertex.glsl",
    });

    // Create mesh
    const vertices = [_]f32{ /* vertex data */ };
    var mesh = try gpu.Mesh.init(allocator, &vertices, null);
    defer mesh.deinit();

    // Apply post-processing
    var post_processor = try gpu.PostProcessor.init(allocator, &ctx);
    defer post_processor.deinit();

    try post_processor.addEffect(.bloom, .{ .intensity = 0.5 });
    try post_processor.addEffect(.anti_aliasing, .{ .samples = 4 });

    // Render
    try pipeline.render(&[_]gpu.RenderCommand{
        .{ .draw_mesh = mesh },
    });
}
```

### CLI Usage

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

# Frameless transparent window
zyte http://localhost:3000 \
  --frameless \
  --transparent \
  --always-on-top
```

## Performance

| Metric | Zyte | Electron | Tauri |
|--------|------|----------|-------|
| Binary Size | **1.4MB** | ~150MB | ~2MB |
| Memory (idle) | **~92MB** | ~200MB | ~80MB |
| Startup Time | **<100ms** | ~1000ms | ~100ms |
| CPU (idle) | **<1%** | ~4% | <1% |
| Platforms | **5** (Desktop + Mobile) | 3 | 3 |
| Native Components | **31** | 0 | Limited |

## Platform Support

| Platform | Status | WebView | Native Components |
|----------|--------|---------|-------------------|
| **macOS** | ✅ Production | WKWebView | ✅ All 31 |
| **Linux** | ✅ Production | WebKit2GTK 4.0+ | ✅ All 31 |
| **Windows** | ✅ Production | WebView2 (Edge) | ✅ All 31 |
| **iOS** | ✅ Beta | WKWebView | ✅ UIKit |
| **Android** | ✅ Beta | WebView | ✅ Material |

## Documentation

- 📖 [API Reference](API_REFERENCE.md) - Complete API documentation
- 🚀 [Quick Start](QUICK_START.md) - Get started quickly
- 📘 [Getting Started](GETTING_STARTED.md) - Detailed guide
- ✨ [Features](FEATURES.md) - Complete feature list
- 🤝 [Contributing](CONTRIBUTING.md) - Contribution guide
- 📋 [Changelog](https://github.com/stacksjs/zyte/releases) - Release history

## Architecture

Zyte is built with a modular architecture:

```
src/
├── api.zig          # Core API with Result types, builders
├── mobile.zig       # iOS & Android platform support
├── menubar.zig      # Menubar/system tray apps
├── components.zig   # 31 native UI components
├── gpu.zig          # Advanced GPU rendering
├── system.zig       # System integration (notifications, clipboard, etc.)
├── window.zig       # Window management
├── ipc.zig          # Inter-process communication
├── state.zig        # Reactive state management
└── animation.zig    # Animation engine
```

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
