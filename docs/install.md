# Installation

Craft can be installed with Bun or built from source for advanced use cases.

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
bun add -g craft-native
```

Then use the CLI:

```bash
craft http://localhost:3000 --title "My App"
```

## Platform Dependencies

### macOS

No additional dependencies required. Craft uses the built-in WKWebView.

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

- Pantry-managed stable Zig toolchain
- Git

### Build Steps

```bash
# Clone the repository
git clone https://github.com/home-lang/craft.git
cd craft

# Install pantry dependencies and use Craft's pantry-aware runner
pantry install

# Build
bun run build:core

# Run craft CLI
./packages/zig/zig-out/bin/craft http://localhost:3000
```

### Build Options

```bash
# Debug build (faster compilation)
eval "$(pantry env)"
cd packages/zig
zig build

# Release build (optimized)
eval "$(pantry env)"
cd packages/zig
zig build -Doptimize=ReleaseFast

# Cross-compile for different platforms
eval "$(pantry env)"
cd packages/zig
zig build -Dtarget=x86_64-linux
zig build -Dtarget=x86_64-windows
zig build -Dtarget=aarch64-macos
eval "$(pantry env)"
cd packages/zig
zig build -Dtarget=x86_64-windows
eval "$(pantry env)"
cd packages/zig
zig build -Dtarget=aarch64-macos
```

## Verification

Verify your installation:

```bash
# Check version
craft --version

# Run a simple test
echo '<h1>Hello Craft!</h1>' | craft --title "Test"
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
