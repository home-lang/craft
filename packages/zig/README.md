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
