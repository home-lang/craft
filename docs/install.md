# Installation

Install the native Craft CLI through Pantry and add its TypeScript SDK to your
application with Bun. Building from source also requires the repository's pinned
toolchain and first-party dependencies.

## TypeScript SDK (Recommended)

The easiest way to use Craft is through the TypeScript SDK:

### Bun (Recommended)

```bash
bun add craft-native
```

## Quick Start with create-craft

Scaffold a new project:

```bash
# Create a new app
bun create craft my-app

# Navigate to the project
cd my-app

# Start development
bun run dev
```

### Available Templates

Choose from multiple templates:

```bash
# Minimal - simplest possible app
bun create craft my-app --template minimal

# Full-featured - modern styled app with examples
bun create craft my-app --template full-featured

# Todo app - interactive todo list example
bun create craft my-app --template todo-app
```

## Global Installation

Install globally for CLI usage:

```bash
pantry install craft
```

Then use the CLI:

```bash
craft http://localhost:3000 --title "My App"
```

## Platform Dependencies

### macOS

The desktop CLI uses macOS's built-in WKWebView and system frameworks. Building
iOS applications also requires Xcode and the appropriate Apple SDKs. Mobile
`renderer: 'native'` uses JavaScriptCore and UIKit without WKWebView; see the
[Native STX guide](guides/native-stx.md) for mobile requirements and configuration.

### Linux

Install WebKit2GTK:

```bash
# Debian/Ubuntu
sudo apt-get install -y libgtk-3-dev libwebkit2gtk-4.1-dev

# Fedora
sudo dnf install gtk3-devel webkit2gtk4.0-devel

# Arch Linux
sudo pacman -S webkit2gtk gtk3
```

### Windows

Install WebView2 Runtime (included in Windows 11, may need installation on Windows 10):

```powershell
# Using winget
winget install Microsoft.EdgeWebView2Runtime

# Or download from Microsoft
# https://developer.microsoft.com/en-us/microsoft-edge/webview2/
```

## Building from Source

For advanced use cases, you can build Craft from source:

### Prerequisites

- Bun and Git
- The exact Pantry-managed Zig version pinned in `pantry.lock`
- The three first-party Zig sibling checkouts at their pinned revisions; follow
  [the source setup instructions](../AGENTS.md#environment) before building

### Build Steps

```bash
# Clone the repository
git clone https://github.com/craft-native/craft.git
cd craft

# Install pantry dependencies and use Craft's pantry-aware runner
pantry install
bun install --frozen-lockfile

# Build
bun run build:core

# Run craft CLI
./packages/zig/zig-out/bin/craft http://localhost:3000
```

### Build Options

```bash
# Run these from the repository root. The runner verifies the pinned compiler.
bun run build:debug

# Release build (optimized)
bun scripts/zig.ts --core --versioned build -Doptimize=ReleaseFast

# Windows cross-build, as exercised by the Linux core CI job
bun scripts/zig.ts --core --versioned build -Doptimize=ReleaseSafe -Dtarget=x86_64-windows
```

Cross-compilation still needs the target's libraries and SDKs. Normal release
archives build on a native runner for each platform; one host does not verify
all release targets. Run the separate core, SDK and platform checks described
in the [Quick Start](QUICK_START.md#work-on-craft-itself).

## Verification

Verify your installation:

```bash
# Check version
craft --version

# Run a simple test
craft http://localhost:3000 --title "Test"
```

## IDE Setup

### VS Code

Install recommended extensions:

- **Zig Language Server**: For Zig development
- **TypeScript**: For TypeScript SDK development

```json
// .vscode/settings.json
{
  "typescript.tsdk": "node_modules/typescript/lib"
}
```

### WebStorm/IntelliJ

TypeScript support works out of the box. For Zig:

1. Install the Zig plugin
2. Configure the Zig toolchain path

## Project Structure

A typical Craft project:

```
my-craft-app/
├── src/
│   ├── main.ts          # Application entry point
│   ├── index.html       # Main HTML file
│   └── styles.css       # Styles
├── assets/
│   └── icon.png         # App icon
├── package.json
├── tsconfig.json
└── craft.config.ts      # Craft configuration
```

## Troubleshooting

### Linux: WebKit2GTK not found

```bash
# Check if installed
pkg-config --libs webkit2gtk-4.1

# If not found, install development packages
sudo apt-get install libwebkit2gtk-4.1-dev
```

### Windows: WebView2 not available

Download and install WebView2 Runtime from Microsoft:
<https://developer.microsoft.com/en-us/microsoft-edge/webview2/>

Craft initializes the Windows UI thread as a single-threaded COM apartment
before it creates the WebView2 environment and keeps that apartment alive until
the WebView2 controllers are released. If a shipped binary reports
`CO_E_NOTINITIALIZED` (`0x800401f0`) while creating its environment, update the
Craft runtime; that error means the binary predates the COM initialization
guard, not that the WebView2 runtime is missing.

### macOS: Permission issues

If you see permission errors when running:

```bash
# Allow in System Preferences > Security & Privacy
# Or run
xattr -cr /path/to/craft
```

### Build fails on Zig version

Ensure you are using Craft's Pantry-managed stable Zig toolchain:

```bash
eval "$(pantry env)" && zig version
# Should output Pantry's installed stable Zig version
```

## Next Steps

- [Usage](/usage) - Learn how to use Craft
- [Configuration](/config) - Configure your application
- [Window Management](/features/window-management) - Control window behavior
