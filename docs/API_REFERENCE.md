# Craft API Reference

## Table of Contents

1. [Core API](#core-api)
2. [Window Management](#window-management)
3. [WebView Integration](#webview-integration)
4. [JavaScript Bridge](#javascript-bridge)
5. [Native Dialogs](#native-dialogs)
6. [Clipboard](#clipboard)
7. [Configuration](#configuration)
8. [Logging](#logging)
9. [CLI Options](#cli-options)

---

## Core API

### App

The main application struct that manages windows and the event loop.

```zig
const craft = @import("craft");

var app = craft.App.init(allocator);
defer app.deinit();
```

#### Methods

##### `init(allocator: std.mem.Allocator) App`
Create a new application instance.

##### `deinit(self: *App) void`
Clean up and free all resources.

##### `createWindow(title, width, height, html) !*Window`
Create a window with HTML content.

**Parameters:**
- `title: []const u8` - Window title
- `width: u32` - Window width in pixels
- `height: u32` - Window height in pixels
- `html: []const u8` - HTML content to display

**Returns:** Pointer to the created window

**Example:**
```zig
const window = try app.createWindow("My App", 800, 600, "<h1>Hello!</h1>");
```

##### `createWindowWithURL(title, width, height, url, style) !*Window`
Create a window that loads a URL directly (no iframe).

**Parameters:**
- `title: []const u8` - Window title
- `width: u32` - Window width in pixels
- `height: u32` - Window height in pixels
- `url: []const u8` - URL to load
- `style: WindowStyle` - Window style options

**Returns:** Pointer to the created window

**Example:**
```zig
const window = try app.createWindowWithURL(
    "My App",
    1200,
    800,
    "http://localhost:3000",
    .{
        .frameless = true,
        .transparent = false,
        .always_on_top = false,
        .resizable = true,
    },
);
```

##### `run() !void`
Start the application event loop. This blocks until all windows are closed.

**Example:**
```zig
try app.run();
```

---

## Window Management

### WindowStyle

Configure window appearance and behavior.

```zig
pub const WindowStyle = struct {
    frameless: bool = false,        // Remove title bar and borders
    transparent: bool = false,       // Make window background transparent
    always_on_top: bool = false,    // Keep window above others
    resizable: bool = true,         // Allow window resizing
    closable: bool = true,          // Show close button
    miniaturizable: bool = true,    // Show minimize button
};
```

**Example:**
```zig
// Frameless, transparent overlay
const style = WindowStyle{
    .frameless = true,
    .transparent = true,
    .always_on_top = true,
    .resizable = false,
};
```

---

## WebView Integration

### DevTools

WebKit Developer Tools are enabled by default. Users can access them by:
1. Right-clicking anywhere in the window
2. Selecting "Inspect Element"

To disable DevTools:
```bash
craft --url http://localhost:3000 --no-devtools
```

Or in configuration:
```toml
[webview]
dev_tools = false
```

---

## JavaScript Bridge

### Web to Zig Communication

The `window.craft` API is automatically injected into every page.

#### Available Methods

##### `craft.send(name, data)`
Send a message to Zig.

**Parameters:**
- `name: string` - Handler name
- `data: any` - Data to send (will be JSON serialized)

**Returns:** `Promise<any>` - Response from Zig handler

**Example:**
```javascript
const result = await window.craft.send('myHandler', { foo: 'bar' });
console.log('Response from Zig:', result);
```

##### `craft.notify(message)`
Show a notification (convenience wrapper).

**Example:**
```javascript
await window.craft.notify('Hello from JavaScript!');
```

##### `craft.readFile(path)`
Read a file from the filesystem.

**Example:**
```javascript
const content = await window.craft.readFile('/path/to/file.txt');
```

##### `craft.writeFile(path, content)`
Write a file to the filesystem.

**Example:**
```javascript
await window.craft.writeFile('/path/to/file.txt', 'Hello, World!');
```

##### `craft.getClipboard()`
Get clipboard contents.

**Example:**
```javascript
const text = await window.craft.getClipboard();
```

##### `craft.setClipboard(text)`
Set clipboard contents.

**Example:**
```javascript
await window.craft.setClipboard('Copied text!');
```

##### `craft.openDialog(options)`
Open a native file dialog.

**Example:**
```javascript
const path = await window.craft.openDialog({
    title: 'Select a file',
    multiple: false
});
```

#### Events

##### `craft:ready`
Fired when the Craft API is ready.

**Example:**
```javascript
window.addEventListener('craft:ready', () => {
    console.log('Craft is ready!');
    console.log('Platform:', window.craft.platform);
    console.log('Version:', window.craft.version);
});
```

### Zig to Web Communication

Evaluate JavaScript from Zig (coming soon).

---

## Native Dialogs

### macOS

Native file dialogs using Cocoa APIs.

#### Open Dialog

```zig
const macos = @import("macos.zig");

const path = try macos.showOpenDialog("Select a file", false);
if (path) |p| {
    std.debug.print("Selected: {s}\n", .{p});
}
```

**Parameters:**
- `title: []const u8` - Dialog title
- `allow_multiple: bool` - Allow multiple file selection

**Returns:** `?[]const u8` - Selected file path or null if canceled

#### Save Dialog

```zig
const path = try macos.showSaveDialog("Save file", "document.txt");
if (path) |p| {
    std.debug.print("Save to: {s}\n", .{p});
}
```

**Parameters:**
- `title: []const u8` - Dialog title
- `default_name: ?[]const u8` - Default file name

**Returns:** `?[]const u8` - Selected file path or null if canceled

---

## Clipboard

### Set Clipboard

```zig
const macos = @import("macos.zig");

try macos.setClipboard("Hello, clipboard!");
```

### Get Clipboard

```zig
const text = try macos.getClipboard(allocator);
defer allocator.free(text);
std.debug.print("Clipboard: {s}\n", .{text});
```

---

## Configuration

### Loading Configuration

```zig
const config_mod = @import("config.zig");

const config = try config_mod.Config.loadFromFile(allocator, "craft.toml");
```

### Configuration Format

```toml
[window]
title = "My App"
width = 1200
height = 800
resizable = true
frameless = false
transparent = false
always_on_top = false

[webview]
dev_tools = true
user_agent = "MyApp/1.0"
```

### Saving Configuration

```zig
const config = config_mod.Config{
    .window = .{
        .title = "My App",
        .width = 1200,
        .height = 800,
    },
};

try config.saveToFile("craft.toml");
```

---

## Logging

### Log Levels

```zig
const log = @import("log.zig");

log.debug("Debug message: {}", .{value});
log.info("Info message: {s}", .{str});
log.warn("Warning message");
log.err("Error message");
```

### Set Log Level

```zig
log.setLevel(.Debug);  // Show all messages
log.setLevel(.Info);   // Show Info, Warning, Error
log.setLevel(.Warning); // Show Warning, Error only
log.setLevel(.Error);  // Show Error only
```

### Output Format

```
[HH:MM:SS] LEVEL Message
[22:45:31] INFO Application started
[22:45:32] WARN Configuration file not found
[22:45:33] ERROR Failed to load resource
```

---

## CLI Options

### Usage

```bash
craft [OPTIONS] [URL]
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-u, --url <URL>` | Load URL in window | - |
| `--html <HTML>` | Load HTML content | - |
| `-t, --title <TITLE>` | Window title | "Craft App" |
| `-w, --width <WIDTH>` | Window width | 1200 |
| `--height <HEIGHT>` | Window height | 800 |
| `--frameless` | Frameless window | false |
| `--transparent` | Transparent window | false |
| `--always-on-top` | Always on top | false |
| `--no-resize` | Disable resizing | false |
| `--no-devtools` | Disable DevTools | false |
| `-h, --help` | Show help | - |
| `-v, --version` | Show version | - |

### Examples

```bash
# Load URL
craft http://localhost:3000

# Custom size and title
craft --url http://example.com --width 800 --height 600 --title "My App"

# Frameless window
craft http://localhost:3000 --frameless

# Transparent overlay
craft http://localhost:3000 --transparent --always-on-top --frameless

# Load HTML
craft --html "<h1>Hello, World!</h1>"

# Multiple options
craft --url http://localhost:3000 \
     --title "Dev Server" \
     --width 1600 \
     --height 900 \
     --frameless
```

---

## Build Modes

Craft supports all standard Zig build modes:

```bash
# Debug mode (default) - fast compilation, debug info
zig build

# ReleaseSafe - optimized with safety checks
zig build -Doptimize=ReleaseSafe

# ReleaseFast - maximum performance, no safety
zig build -Doptimize=ReleaseFast

# ReleaseSmall - smallest binary size
zig build -Doptimize=ReleaseSmall
```

### Binary Size Comparison

| Mode | Binary Size | Safety | Performance |
|------|-------------|--------|-------------|
| Debug | ~1.5MB | ✅ Full | Medium |
| ReleaseSafe | ~1.3MB | ✅ Full | High |
| ReleaseFast | ~1.2MB | ❌ None | Maximum |
| ReleaseSmall | ~1.0MB | ❌ None | Medium |

---

## Platform Support

| Feature | macOS | Linux | Windows |
|---------|-------|-------|---------|
| Window Creation | ✅ | 🚧 | 🚧 |
| WebView | ✅ | 🚧 | 🚧 |
| DevTools | ✅ | 🚧 | 🚧 |
| Dialogs | ✅ | ❌ | ❌ |
| Clipboard | ✅ | ❌ | ❌ |
| Menu Bar | 🚧 | ❌ | ❌ |
| System Tray | ❌ | ❌ | ❌ |

Legend:
- ✅ Implemented and working
- 🚧 API ready, implementation pending
- ❌ Not yet implemented

---

## Error Handling

All fallible operations return Zig error unions:

```zig
const window = app.createWindow("Title", 800, 600, html) catch |err| {
    std.debug.print("Failed to create window: {}\n", .{err});
    return;
};
```

Common errors:
- `error.UnsupportedPlatform` - Feature not available on this OS
- `error.NoWindows` - No windows created before `run()`
- `error.HandlerNotFound` - JavaScript bridge handler not registered
- `error.NoClipboardContent` - Clipboard is empty

---

**For more examples, see the `examples/` directory.**
