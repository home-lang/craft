# Craft Core (Zig)

The native Zig implementation of Craft - a high-performance framework for building cross-platform desktop applications.

## Overview

This package contains the Zig source code for Craft, providing:
- **Native window management** - Cross-platform window creation and management
- **WebView integration** - WKWebView (macOS), WebKit2GTK (Linux), WebView2 (Windows)
- **GPU-accelerated rendering** - Hardware-accelerated graphics pipeline
- **35 native UI components** - Production-ready component library
- **System integration** - Notifications, clipboard, file dialogs, system tray
- **Mobile support** - iOS and Android targets
- **Advanced features** - IPC, hot reload with state preservation, comprehensive dev tools
- **Error handling** - Context-aware error system with stack traces
- **Performance monitoring** - Built-in benchmarking and profiling suite
- **Accessibility** - WCAG 2.1 AAA compliance with ARIA support

## For TypeScript Users

**You don't need to touch this package!** Use the TypeScript SDK instead:

```bash
bun add ts-craft
```

See [ts-craft documentation](../ts-craft/README.md) for the TypeScript API.

## For Advanced Users (Zig Development)

If you want to contribute to the Zig core or build custom Zig applications:

### Requirements

- Zig 0.15.0 or later
- Platform-specific dependencies (see below)

### Platform Dependencies

**macOS:**
```bash
# Xcode Command Line Tools (for Cocoa/WebKit)
xcode-select --install
```

**Linux:**
```bash
# WebKit2GTK and GTK3
sudo apt-get install -y libgtk-3-dev libwebkit2gtk-4.0-dev
```

**Windows:**
```bash
# WebView2
winget install Microsoft.EdgeWebView2Runtime
```

### Building

```bash
# Development build
zig build

# Optimized release build
zig build -Doptimize=ReleaseSafe

# Run examples
zig build run
zig build run-minimal
```

### Testing

```bash
# Run all tests
zig build test

# Format code
zig fmt src/ build.zig

# Check formatting
zig fmt --check src/ build.zig
```

### iOS Build

```bash
# Build for iOS device (arm64)
zig build build-ios

# Build for iOS Simulator
zig build build-ios-simulator

# Build for both
zig build build-ios-all
```

Output libraries are in `zig-out/lib/`:
- `libcraft-ios.a` - iOS device
- `libcraft-ios-simulator-arm64.a` - iOS Simulator (Apple Silicon)
- `libcraft-ios-simulator-x64.a` - iOS Simulator (Intel)

## Features

### 🎨 UI Components (35 total)

**Core Components:**
- Button, TextInput, Checkbox, Radio
- Dropdown, Tabs, Modal, ProgressBar
- Toast, Tooltip, Slider, ColorPicker

**Advanced Components:**
- Chart (line, bar, pie charts)
- DataGrid (sortable, filterable tables)
- TreeView (hierarchical data)
- DatePicker (calendar widget)
- Autocomplete (fuzzy search)
- CodeEditor (syntax highlighting)
- MediaPlayer (video/audio)

### 🔧 Developer Experience

**Hot Reload with State Preservation:**
- Automatic file watching
- Preserves scroll position across reloads
- Maintains form data and input states
- Restores focus and cursor position
- Custom state persistence via `window.__ZYTE_STATE__`

**Enhanced Error Messages:**
- Color-coded error output
- Stack traces with source context
- Actionable suggestions for common errors
- Beautiful error overlays in dev mode
- Integration with error context system

**Dev Tools:**
- Real-time FPS monitoring
- Memory usage tracking
- Event listener counting
- Performance profiling
- Debug overlay (Ctrl+Shift+D)

### ⚡ Performance

**Benchmarking Suite:**
- Component rendering benchmarks
- Memory allocation tracking
- Statistical analysis (mean, median, std dev)
- JSON/text report generation
- Comparison framework for optimizations

**Performance Utilities:**
- Object pooling
- Memory caching with LRU eviction
- Lazy loading
- Debouncing and throttling
- Batch processing
- Work queue with thread pool

### ♿ Accessibility

**ARIA Support:**
- 40+ semantic roles
- Complete state management (checked, disabled, selected, etc.)
- Live regions for screen readers
- Keyboard navigation system
- Focus management with trap support

**WCAG 2.1 AAA Compliance:**
- Contrast ratio checker
- Screen reader announcements
- Keyboard shortcut system
- Semantic HTML mapping
- Focus indicators

### 🛡️ Error Handling

**Error Context System:**
- 40+ categorized error codes (1000-1999 range)
- Stack trace capture
- Error metadata and cause chaining
- Recovery strategies (retry, fallback, ignore, fail)
- Beautiful formatting for CLI and web

### 🔌 System Integration

- File system operations
- Clipboard access
- Native notifications
- System tray/menu bar
- File dialogs (open, save, select folder)
- Drag and drop
- Deep linking

## Project Structure

```
packages/zig/
├── src/                      # Zig source code
│   ├── main.zig             # Main entry point
│   ├── components/          # UI components
│   │   ├── button.zig
│   │   ├── tooltip.zig
│   │   ├── slider.zig
│   │   ├── autocomplete.zig
│   │   ├── color_picker.zig
│   │   └── ... (30+ more)
│   ├── error_context.zig    # Error handling system
│   ├── benchmark.zig        # Performance benchmarking
│   ├── accessibility.zig    # ARIA and a11y features
│   ├── hotreload.zig        # Hot reload with state preservation
│   ├── devmode.zig          # Developer experience tools
│   ├── api.zig              # Core API
│   ├── gpu.zig              # GPU rendering
│   ├── system.zig           # System integration
│   ├── mobile.zig           # Mobile support
│   ├── ipc.zig              # Inter-process communication
│   ├── performance.zig      # Performance optimizations
│   └── ...
├── test/                    # Test suite (69 tests)
│   ├── components/          # Component tests
│   ├── benchmark_test.zig
│   ├── error_context_test.zig
│   └── ...
├── examples/                # Zig examples
├── build.zig                # Build configuration
└── package.json             # Package metadata
```

## Example Usage (Zig)

### Basic Window

```zig
const std = @import("std");
const craft = @import("craft");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = craft.App.init(allocator);
    defer app.deinit();

    const html =
        \\<!DOCTYPE html>
        \\<html>
        \\<body>
        \\  <h1>Hello from Craft!</h1>
        \\</body>
        \\</html>
    ;

    _ = try app.createWindow("My App", 800, 600, html);
    try app.run();
}
```

### iOS App

```zig
const std = @import("std");
const ios = @import("craft").ios;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const html = @embedFile("app.html");

    var app = ios.CraftAppDelegate.init(allocator, .{
        .name = "My iOS App",
        .initial_content = .{ .html = html },
        .status_bar_style = .light,
        .orientations = &[_]ios.CraftAppDelegate.AppConfig.Orientation{
            .portrait,
            .landscape_left,
            .landscape_right,
        },
    });

    // Register lifecycle callbacks
    app.onLaunch(onAppLaunch);
    app.onBackground(onAppBackground);

    try app.run();
}

fn onAppLaunch() void {
    std.debug.print("App launched!\n", .{});
}

fn onAppBackground() void {
    std.debug.print("App went to background\n", .{});
}
```

### Cross-Platform (Desktop + iOS)

```zig
const std = @import("std");
const craft = @import("craft");
const builtin = @import("builtin");

const app_html = @embedFile("app.html");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    switch (builtin.target.os.tag) {
        .macos, .linux, .windows => {
            // Desktop
            var app = craft.App.init(allocator);
            defer app.deinit();
            _ = try app.createWindow("My App", 1200, 800, app_html);
            try app.run();
        },
        .ios => {
            // iOS
            const ios = @import("craft").ios;
            var app = ios.CraftAppDelegate.init(allocator, .{
                .name = "My App",
                .initial_content = .{ .html = app_html },
            });
            try app.run();
        },
        else => return error.UnsupportedPlatform,
    }
}
```

### JavaScript Bridge (Web App)

Your web app can call native functions:

```javascript
// Check if running in Craft native environment
if (window.craft) {
    // Get platform info
    const platform = await craft.invoke('getPlatform');
    // { os: 'ios', version: '17.0', device: 'iPhone', native: true }

    // Show native alert
    await craft.invoke('showAlert', {
        title: 'Hello',
        message: 'Native alert!'
    });

    // Trigger haptic feedback (iOS)
    await craft.invoke('haptic', { type: 'success' });

    // Get safe area insets (iOS notch/home indicator)
    const insets = await craft.invoke('getSafeArea');
    // { top: 47, bottom: 34, left: 0, right: 0 }

    // Copy to clipboard
    await craft.invoke('setClipboard', { text: 'Hello!' });

    // Open URL in browser
    await craft.invoke('openURL', { url: 'https://example.com' });

    // Share content
    await craft.invoke('share', { text: 'Check this out!' });
}
```

### File Dialogs

```zig
const std = @import("std");
const craft = @import("craft");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Open file dialog with filters
    const filters = [_]craft.FileFilter{
        craft.FileFilter.create("Text Files", &[_][]const u8{ "txt", "md", "json" }),
        craft.FileFilter.create("All Files", &[_][]const u8{"*"}),
    };

    if (try craft.Dialog.showFileOpen(allocator, .{
        .title = "Open File",
        .filters = &filters,
    })) |result| {
        switch (result) {
            .file_path => |path| std.debug.print("Selected: {s}\n", .{path}),
            else => {},
        }
    }

    // Save file dialog
    if (try craft.Dialog.showFileSave(allocator, .{
        .title = "Save As",
        .default_path = "untitled.txt",
    })) |result| {
        switch (result) {
            .file_path => |path| std.debug.print("Save to: {s}\n", .{path}),
            else => {},
        }
    }

    // Select folder dialog
    if (try craft.Dialog.showDirectory(allocator, .{
        .title = "Select Folder",
    })) |result| {
        switch (result) {
            .directory_path => |path| std.debug.print("Folder: {s}\n", .{path}),
            else => {},
        }
    }

    // Message dialog
    _ = try craft.Dialog.showMessage(allocator, .{
        .title = "Info",
        .message = "Operation completed!",
        .type = .info,
    });

    // Confirm dialog
    const confirmed = try craft.Dialog.showConfirm(allocator, .{
        .title = "Confirm",
        .message = "Are you sure?",
        .destructive = true,
    });
    if (confirmed == .ok) {
        std.debug.print("User confirmed\n", .{});
    }
}
```

Run the file dialogs example:
```bash
zig build run-dialogs
```

### Notifications

```zig
const std = @import("std");
const craft = @import("craft");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var notifications = craft.Notifications.init(allocator);
    defer notifications.deinit();

    // Basic notification
    try notifications.send(.{
        .title = "Hello!",
        .body = "This is a native notification.",
    });

    // Notification with sound
    try notifications.send(.{
        .title = "Download Complete",
        .body = "Your file is ready.",
        .sound = "Glass", // macOS sound name
    });

    // Notification with action button
    const actions = [_]craft.NotificationAction{
        .{ .id = "view", .title = "View" },
    };
    try notifications.send(.{
        .title = "New Message",
        .body = "You have unread messages.",
        .actions = &actions,
    });
}
```

Run: `zig build run-notifications`

### System Tray

```zig
const std = @import("std");
const craft = @import("craft");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var tray = craft.SystemTray.init(allocator, "My App");
    defer tray.deinit();

    tray.icon_text = "🚀 App";
    try tray.setTooltip("My Application");
    tray.setClickCallback(onTrayClick);
    try tray.show();

    // Update title dynamically
    try tray.setTitle("📊 Active");

    // Animate the icon
    const frames = [_][]const u8{ "⏳.", "⏳..", "⏳..." };
    try tray.animate(&frames, 500);
}

fn onTrayClick() void {
    std.debug.print("Tray clicked!\n", .{});
}
```

Run: `zig build run-tray`

### Clipboard

```zig
const std = @import("std");
const craft = @import("craft");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var clipboard = craft.ClipboardBridge.init(allocator);
    defer clipboard.deinit();

    // Write text to clipboard
    try clipboard.handleMessageWithData("writeText", "{\"text\":\"Hello!\"}");

    // Read text from clipboard
    try clipboard.handleMessageWithData("readText", null);

    // Write HTML to clipboard
    try clipboard.handleMessageWithData("writeHTML", "{\"html\":\"<b>Bold</b>\"}");

    // Check clipboard contents
    try clipboard.handleMessageWithData("hasText", null);
    try clipboard.handleMessageWithData("hasHTML", null);
    try clipboard.handleMessageWithData("hasImage", null);

    // Clear clipboard
    try clipboard.handleMessageWithData("clear", null);
}
```

Run: `zig build run-clipboard`

### Hot Reload

```zig
const std = @import("std");
const craft = @import("craft");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Set up file watcher
    var hot_reload = try craft.HotReload.init(allocator, .{
        .enabled = true,
        .watch_paths = &[_][]const u8{ "src/", "index.html" },
        .debounce_ms = 300,
    });
    defer hot_reload.deinit();

    hot_reload.setCallback(onReload);
    hot_reload.start();

    // Start WebSocket server for browser/mobile reload
    var server = craft.ReloadServer.init(allocator, .{
        .port = 3456,
        .host = "0.0.0.0",
    });
    defer server.deinit();
    try server.start();

    // Poll for changes in your event loop
    while (true) {
        try hot_reload.poll();
        std.time.sleep(100 * std.time.ns_per_ms);
    }
}

fn onReload() void {
    std.debug.print("Reloading...\n", .{});
}
```

**State Preservation:** Hot reload automatically preserves:
- Scroll position
- Form data
- Focus state
- Custom state via `window.__CRAFT_STATE__`

Run: `zig build run-hotreload`

### Using Components

```zig
const std = @import("std");
const craft = @import("craft");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Create a button component
    const button = try craft.Button.init(allocator, .{});
    defer button.deinit();

    button.setLabel("Click Me!");
    button.setVariant(.primary);
    button.onClick(handleClick);

    // Create a slider
    const slider = try craft.Slider.init(allocator, .{});
    defer slider.deinit();

    try slider.setRange(0, 100);
    try slider.setValue(50);
    slider.onChange(handleSliderChange);
}

fn handleClick() void {
    std.debug.print("Button clicked!\n", .{});
}

fn handleSliderChange(value: f64) void {
    std.debug.print("Slider value: {d}\n", .{value});
}
```

### Error Handling

```zig
const std = @import("std");
const error_context = @import("error_context.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Create error with context
    const err_ctx = try error_context.ErrorContext.init(
        allocator,
        .file_not_found,
        "Could not load configuration file"
    );
    defer err_ctx.deinit();

    // Add stack trace
    _ = try err_ctx.addStackFrame("loadConfig", "config.zig", 42);
    _ = try err_ctx.addStackFrame("main", "main.zig", 10);

    // Add metadata
    _ = try err_ctx.addMetadata("path", "/etc/app/config.json");
    _ = try err_ctx.addMetadata("user", "john_doe");

    // Print formatted error
    try err_ctx.print();
}
```

### Performance Benchmarking

```zig
const std = @import("std");
const benchmark = @import("benchmark.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Create a benchmark suite
    const suite = try benchmark.BenchmarkSuite.init(allocator, "My Benchmarks");
    defer suite.deinit();

    // Benchmark memory allocation
    const alloc_result = try benchmark.benchmarkAllocation(allocator, 1024, 1000);
    try suite.addResult(alloc_result);

    // Benchmark HashMap operations
    const hashmap_result = try benchmark.benchmarkHashMapOperations(allocator, 1000);
    try suite.addResult(hashmap_result);

    // Generate report
    const report = try suite.generateReport(allocator);
    defer allocator.free(report);
    std.debug.print("{s}\n", .{report});
}
```

### Hot Reload with State

```html
<!DOCTYPE html>
<html>
<head>
    <title>Hot Reload Demo</title>
</head>
<body>
    <h1>Hot Reload with State Preservation</h1>

    <form id="my-form">
        <input type="text" name="username" placeholder="Username">
        <input type="email" name="email" placeholder="Email">
        <button type="submit">Submit</button>
    </form>

    <script>
        // Custom state that persists across hot reloads
        window.__ZYTE_STATE__ = {
            count: (window.__ZYTE_STATE__?.count || 0) + 1,
            lastUpdate: new Date().toISOString()
        };

        // Listen for state restoration
        window.addEventListener('craft:state-restored', (event) => {
            console.log('State restored:', event.detail);
        });

        console.log('Page loads:', window.__ZYTE_STATE__.count);
    </script>
</body>
</html>
```

## Contributing

See the main [CONTRIBUTING.md](../../CONTRIBUTING.md) for contribution guidelines.

## License

MIT © [Chris Breuer](https://github.com/chrisbbreuer)
