# Craft Zig Package Code Structure

This document describes the organization of the Zig source code.

## Directory Structure

```
src/
├── components/     # UI components (Button, Label, ListView, etc.)
├── linux/          # Linux-specific implementations
├── macos/          # macOS-specific implementations
├── windows/        # Windows-specific implementations
├── js/             # JavaScript interop utilities
├── tests/          # Integration tests
└── *.zig           # Core modules
```

## Module Categories

### Bridge Modules (`bridge**.zig`)

Handle communication between JavaScript/TypeScript and native Zig code.

| Module | Description |
|--------|-------------|
| `bridge.zig` | Core bridge implementation |
| `bridge*api.zig` | API bridge interface |
| `bridge*app.zig` | Application lifecycle bridge |
| `bridge*async.zig` | Async operation bridge |
| `bridge*bluetooth.zig` | Bluetooth functionality |
| `bridge*clipboard.zig` | Clipboard operations |
| `bridge*dialog.zig` | Native dialogs |
| `bridge*fs.zig` | File system operations |
| `bridge*menu.zig` | Menu management |
| `bridge*network.zig` | Network operations |
| `bridge*notification.zig` | Notifications |
| `bridge*power.zig` | Power/battery info |
| `bridge*shell.zig` | Shell command execution |
| `bridge*shortcuts.zig` | Keyboard shortcuts |
| `bridge*system.zig` | System information |
| `bridge*touchbar.zig` | macOS Touch Bar |
| `bridge*tray.zig` | System tray |
| `bridge*types.zig` | Shared bridge types |
| `bridge*updater.zig` | App updates |
| `bridge*window.zig` | Window management |

### API Modules (`api**.zig`)

High-level APIs exposed to applications.

| Module | Description |
|--------|-------------|
| `api.zig` | Main API entry point |
| `api*crypto.zig` | Cryptographic operations |
| `api*database.zig` | Database operations |
| `api*filesystem.zig` | File system API |
| `api*http.zig` | HTTP client |
| `api*process.zig` | Process management |

### Platform Modules

Platform-specific implementations.

| Module | Description |
|--------|-------------|
| `android.zig` | Android platform support |
| `ios.zig` | iOS platform support |
| `macos.zig` | macOS platform support |
| `linux.zig` | Linux platform support |
| `windows.zig` | Windows platform support |

### Feature Modules

Individual feature implementations.

| Module | Description |
|--------|-------------|
| `audio.zig` | Audio playback and recording |
| `camera.zig` | Camera capture and barcode scanning |
| `notifications.zig` | Cross-platform notifications |
| `dialogs.zig` | Native dialog boxes |
| `i18n.zig` | Internationalization |
| `bluetooth.zig` | Bluetooth connectivity |
| `biometrics.zig` | Biometric authentication |
| `geolocation.zig` | Location services |
| `permissions.zig` | Permission management |
| `storage.zig` | Data persistence |
| `network.zig` | Network utilities |

### Plugin System

Plugin architecture and sandboxing.

| Module | Description |
|--------|-------------|
| `plugin.zig` | Unified plugin system |
| `plugin*security.zig` | Permission and sandbox management |
| `wasm.zig` | WebAssembly runtime |

### UI Components (`components/`)

Native UI component implementations.

| Component | Description |
|-----------|-------------|
| `button.zig` | Button component |
| `checkbox.zig` | Checkbox component |
| `color*picker.zig` | Color picker |
| `dropdown.zig` | Dropdown select |
| `label.zig` | Text label |
| `list*view.zig` | List view |
| `progress*bar.zig` | Progress indicator |
| `radio*button.zig` | Radio button |
| `slider.zig` | Slider control |
| `status*bar.zig` | Status bar |
| `switch.zig` | Toggle switch |
| `tab*view.zig` | Tab container |
| `text*input.zig` | Text input field |
| `toolbar.zig` | Toolbar |

### Core Infrastructure

| Module | Description |
|--------|-------------|
| `main.zig` | Main entry point and exports |
| `cli.zig` | Command-line interface |
| `config.zig` | Configuration management |
| `log.zig` | Logging system |
| `memory.zig` | Memory management |
| `profiler.zig` | Performance profiling |
| `crypto.zig` | Cryptographic utilities |
| `async.zig` | Async execution utilities |
| `hot_reload.zig` | Development hot reload |

## Import Patterns

### Importing from main.zig

```zig
const craft = @import("main.zig");
const Window = craft.Window;
const Notifications = craft.Notifications;
```

### Importing specific modules

```zig
const audio = @import("audio.zig");
const camera = @import("camera.zig");
const i18n = @import("i18n.zig");
```

### Importing platform-specific code

```zig
const builtin = @import("builtin");
const platform = switch (builtin.os.tag) {
    .macos => @import("macos.zig"),
    .linux => @import("linux.zig"),
    .windows => @import("windows.zig"),
    else => @compileError("Unsupported platform"),
};
```

## Build System

The `build.zig` file configures:

- Library compilation for all platforms
- Test execution
- Documentation generation
- Cross-compilation targets

## Testing

Tests are located in:

- `test/` - Standalone test files
- `src/tests/` - Integration tests
- Inline tests in source files (run with `zig test <file>`)

Run all tests:
```bash
zig build test
```

## TypeScript Integration

TypeScript type definitions are in:

- `types/craft-bridge.d.ts` - Bridge API types

These are manually maintained to match the Zig bridge implementations.
