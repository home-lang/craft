# Zyte Core (Zig)

The native Zig implementation of Zyte - the core that powers the TypeScript SDK.

## Overview

This package contains the Zig source code for Zyte, providing:
- Native window management
- WebView integration (WKWebView, WebKit2GTK, WebView2)
- GPU-accelerated rendering
- 31 native UI components
- System integration (notifications, clipboard, file dialogs, etc.)
- Mobile support (iOS, Android)
- Advanced features (IPC, hot reload, dev tools)

## For TypeScript Users

**You don't need to touch this package!** Use the TypeScript SDK instead:

```bash
bun add ts-zyte
```

See [ts-zyte documentation](../ts-zyte/README.md) for the TypeScript API.

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

## Project Structure

```
packages/zig/
├── src/               # Zig source code
│   ├── api.zig        # Core API
│   ├── window.zig     # Window management
│   ├── components.zig # Native components
│   ├── gpu.zig        # GPU rendering
│   ├── system.zig     # System integration
│   ├── mobile.zig     # Mobile support
│   ├── menubar.zig    # Menubar apps
│   ├── ipc.zig        # Inter-process communication
│   ├── state.zig      # State management
│   ├── animation.zig  # Animation engine
│   └── ...
├── test/              # Test suite
├── examples/          # Zig examples
├── build.zig          # Build configuration
└── package.json       # Package metadata
```

## Example Usage (Zig)

```zig
const std = @import("std");
const zyte = @import("zyte");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = zyte.App.init(allocator);
    defer app.deinit();

    const html =
        \\<!DOCTYPE html>
        \\<html>
        \\<body>
        \\  <h1>Hello from Zyte!</h1>
        \\</body>
        \\</html>
    ;

    _ = try app.createWindow("My App", 800, 600, html);
    try app.run();
}
```

## Contributing

See the main [CONTRIBUTING.md](../../CONTRIBUTING.md) for contribution guidelines.

## License

MIT © [Chris Breuer](https://github.com/chrisbbreuer)
