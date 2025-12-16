# Craft Architecture

This document provides visual diagrams of Craft's architecture to help contributors understand the codebase structure and component relationships.

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Layer System](#layer-system)
3. [Platform Abstraction](#platform-abstraction)
4. [Bridge System](#bridge-system)
5. [Component Architecture](#component-architecture)
6. [Build System](#build-system)

---

## High-Level Architecture

Craft is a cross-platform application framework that enables building native desktop and mobile applications using web technologies.

```mermaid
graph TB
    subgraph "Developer Layer"
        TS[TypeScript SDK<br/>ts-craft]
        CLI[CLI<br/>create-craft]
        Examples[Examples]
    end

    subgraph "Craft Core (Zig)"
        API[api.zig<br/>Public API]
        Bridge[Bridge System<br/>JS ↔ Zig IPC]
        Components[Native Components<br/>35+ UI widgets]
        System[System Integration<br/>Notifications, Dialogs, etc.]
    end

    subgraph "Platform Layer"
        macOS[macos.zig<br/>Cocoa + WebKit]
        Linux[linux.zig<br/>GTK + WebKit2GTK]
        Windows[windows.zig<br/>Win32 + WebView2]
        iOS[mobile.zig<br/>UIKit + WKWebView]
        Android[mobile.zig<br/>Android SDK]
    end

    subgraph "OS/Runtime"
        OSX[macOS]
        LNX[Linux]
        WIN[Windows]
        IOS[iOS]
        AND[Android]
    end

    TS --> API
    CLI --> API
    Examples --> TS

    API --> Bridge
    API --> Components
    API --> System

    Bridge --> macOS
    Bridge --> Linux
    Bridge --> Windows
    Bridge --> iOS
    Bridge --> Android

    Components --> macOS
    Components --> Linux
    Components --> Windows

    System --> macOS
    System --> Linux
    System --> Windows
    System --> iOS
    System --> Android

    macOS --> OSX
    Linux --> LNX
    Windows --> WIN
    iOS --> IOS
    Android --> AND
```

---

## Layer System

Craft uses a layered architecture to maintain separation of concerns and enable cross-platform development.

```mermaid
graph TB
    subgraph "Layer 3: Higher-Level UX"
        L3A[components.zig]
        L3B[menubar.zig]
        L3C[tray.zig]
        L3D[hotreload.zig]
        L3E[devmode.zig]
    end

    subgraph "Layer 2: Bridge + Integration"
        L2A[bridge.zig]
        L2B[bridge_api.zig]
        L2C[js_bridge.zig]
        L2D[bridge_dialog.zig]
        L2E[bridge_clipboard.zig]
        L2F[bridge_window.zig]
    end

    subgraph "Layer 1: Core Primitives"
        L1A[api.zig<br/>App, Window, Platform]
        L1B[system.zig<br/>Notifications, Clipboard]
        L1C[ipc.zig]
        L1D[events.zig]
        L1E[async.zig]
    end

    subgraph "Layer 0: OS Bindings"
        L0A[macos.zig]
        L0B[linux.zig]
        L0C[windows.zig]
        L0D[mobile.zig]
        L0E[objc_helpers.zig]
    end

    L3A --> L2A
    L3B --> L2B
    L3C --> L2B
    L3D --> L1A
    L3E --> L2A

    L2A --> L1A
    L2B --> L1A
    L2C --> L1B
    L2D --> L1B
    L2E --> L1B
    L2F --> L1A

    L1A --> L0A
    L1A --> L0B
    L1A --> L0C
    L1A --> L0D
    L1B --> L0A
    L1B --> L0B
    L1B --> L0C
    L1C --> L0E
```

### Layer Descriptions

| Layer | Purpose | Key Modules |
|-------|---------|-------------|
| **Layer 0** | Direct OS API bindings | `macos.zig`, `linux.zig`, `windows.zig`, `mobile.zig` |
| **Layer 1** | Core abstractions and primitives | `api.zig`, `system.zig`, `ipc.zig`, `events.zig` |
| **Layer 2** | JavaScript bridge and integration | `bridge.zig`, `js_bridge.zig`, `bridge_*.zig` |
| **Layer 3** | Higher-level features and UX | `components.zig`, `menubar.zig`, `hotreload.zig` |

---

## Platform Abstraction

Each platform has dedicated implementation files that handle OS-specific details.

```mermaid
graph LR
    subgraph "Cross-Platform API"
        Window[Window API]
        WebView[WebView API]
        Notify[Notifications]
        Dialog[Dialogs]
        Clip[Clipboard]
        Tray[System Tray]
    end

    subgraph "macOS Implementation"
        M1[NSWindow]
        M2[WKWebView]
        M3[NSUserNotificationCenter]
        M4[NSOpenPanel/NSSavePanel]
        M5[NSPasteboard]
        M6[NSStatusItem]
    end

    subgraph "Linux Implementation"
        L1[GtkWindow]
        L2[WebKit2GTK]
        L3[libnotify]
        L4[GtkFileChooserDialog]
        L5[X11/Wayland Clipboard]
        L6[GtkStatusIcon/AppIndicator]
    end

    subgraph "Windows Implementation"
        W1[HWND/Win32]
        W2[WebView2]
        W3[Toast Notifications]
        W4[IFileDialog]
        W5[OLE Clipboard]
        W6[Shell_NotifyIcon]
    end

    Window --> M1
    Window --> L1
    Window --> W1

    WebView --> M2
    WebView --> L2
    WebView --> W2

    Notify --> M3
    Notify --> L3
    Notify --> W3

    Dialog --> M4
    Dialog --> L4
    Dialog --> W4

    Clip --> M5
    Clip --> L5
    Clip --> W5

    Tray --> M6
    Tray --> L6
    Tray --> W6
```

---

## Bridge System

The bridge enables bidirectional communication between JavaScript (WebView) and native Zig code.

```mermaid
sequenceDiagram
    participant JS as JavaScript<br/>(WebView)
    participant Bridge as Bridge<br/>(js_bridge.zig)
    participant Handler as Handler<br/>(bridge_*.zig)
    participant Native as Native API<br/>(system.zig)
    participant OS as OS API

    JS->>Bridge: window.craft.invoke("method", params)
    Bridge->>Bridge: Parse JSON message
    Bridge->>Handler: Route to handler
    Handler->>Native: Call native function
    Native->>OS: Execute OS call
    OS-->>Native: Result
    Native-->>Handler: Return value
    Handler-->>Bridge: Format response
    Bridge-->>JS: craftHandleResponse(id, result)
```

### Message Format

```json
{
  "id": "unique-request-id",
  "method": "clipboard.getText",
  "params": {}
}
```

### Response Format

```json
{
  "id": "unique-request-id",
  "success": true,
  "result": "clipboard contents"
}
```

### Bridge Modules

```mermaid
graph TB
    subgraph "Bridge Core"
        BC[bridge.zig<br/>Message routing]
        BA[bridge_api.zig<br/>API injection]
        JB[js_bridge.zig<br/>JSON-RPC handler]
    end

    subgraph "Domain Bridges"
        BW[bridge_window.zig]
        BD[bridge_dialog.zig]
        BCL[bridge_clipboard.zig]
        BT[bridge_tray.zig]
        BN[bridge_native_ui.zig]
        BFS[bridge_fs.zig]
        BNW[bridge_network.zig]
    end

    BC --> BW
    BC --> BD
    BC --> BCL
    BC --> BT
    BC --> BN
    BC --> BFS
    BC --> BNW

    BA --> BC
    JB --> BC
```

---

## Component Architecture

Native UI components are built on top of platform-specific widgets.

```mermaid
graph TB
    subgraph "Component System"
        CM[components.zig<br/>Component Manager]
    end

    subgraph "Input Components"
        BTN[Button]
        TXT[TextInput]
        CHK[Checkbox]
        RAD[RadioButton]
        SLD[Slider]
        CLR[ColorPicker]
        DTE[DatePicker]
        AUT[Autocomplete]
    end

    subgraph "Display Components"
        LBL[Label]
        IMG[ImageView]
        PRG[ProgressBar]
        SPN[Spinner]
        AVT[Avatar]
        BDG[Badge]
        TIP[Tooltip]
        TST[Toast]
    end

    subgraph "Layout Components"
        SCR[ScrollView]
        SPL[SplitView]
        ACC[Accordion]
        STP[Stepper]
        MOD[Modal]
        TAB[Tabs]
        DRP[Dropdown]
    end

    subgraph "Data Components"
        LST[ListView]
        TBL[Table]
        TRE[TreeView]
        DGR[DataGrid]
        CHT[Chart]
    end

    CM --> BTN
    CM --> TXT
    CM --> CHK
    CM --> SLD
    CM --> LBL
    CM --> PRG
    CM --> SCR
    CM --> MOD
    CM --> TAB
    CM --> LST
    CM --> TBL
    CM --> CHT
```

---

## Build System

Craft uses Zig's build system for native compilation and cross-compilation.

```mermaid
graph TB
    subgraph "Build Configuration"
        ROOT[build.zig<br/>Root config]
        PKG[packages/zig/build.zig<br/>Main build]
    end

    subgraph "Build Targets"
        FULL[craft<br/>Full build]
        MIN[craft-minimal<br/>Minimal build]
        EX[Examples]
        TEST[Tests]
    end

    subgraph "Platform Targets"
        MAC[macOS<br/>aarch64, x86_64]
        LIN[Linux<br/>x86_64, aarch64]
        WIN[Windows<br/>x86_64]
        IOS[iOS<br/>arm64, simulator]
        AND[Android<br/>arm64, x86_64]
    end

    subgraph "Build Modes"
        DBG[Debug]
        REL[ReleaseSafe]
        FAST[ReleaseFast]
        SMALL[ReleaseSmall]
    end

    ROOT --> PKG

    PKG --> FULL
    PKG --> MIN
    PKG --> EX
    PKG --> TEST

    FULL --> MAC
    FULL --> LIN
    FULL --> WIN
    MIN --> MAC
    MIN --> LIN
    MIN --> WIN
    MIN --> IOS
    MIN --> AND

    MAC --> DBG
    MAC --> REL
    MAC --> FAST
    MAC --> SMALL
```

### Build Commands

```bash
# Debug build
zig build

# Release build
zig build -Doptimize=ReleaseSafe

# Run minimal example
zig build run-minimal

# Run tests
zig build test

# Cross-compile for Linux
zig build -Dtarget=x86_64-linux-gnu

# Cross-compile for Windows
zig build -Dtarget=x86_64-windows
```

---

## Data Flow

```mermaid
flowchart LR
    subgraph "Web App"
        HTML[HTML/CSS/JS]
    end

    subgraph "WebView"
        WV[Platform WebView]
        JS[window.craft API]
    end

    subgraph "Craft Core"
        BR[Bridge]
        EV[Event System]
        ST[State]
    end

    subgraph "Native"
        OS[OS APIs]
        HW[Hardware]
    end

    HTML --> WV
    WV <--> JS
    JS <--> BR
    BR <--> EV
    EV <--> ST
    BR <--> OS
    OS <--> HW

    style HTML fill:#e1f5fe
    style WV fill:#fff3e0
    style JS fill:#fff3e0
    style BR fill:#e8f5e9
    style EV fill:#e8f5e9
    style ST fill:#e8f5e9
    style OS fill:#fce4ec
    style HW fill:#fce4ec
```

---

## Memory Management

Craft uses Zig's explicit allocator pattern for predictable memory management.

```mermaid
graph TB
    subgraph "Allocator Hierarchy"
        GPA[GeneralPurposeAllocator<br/>Default allocator]
        ARENA[ArenaAllocator<br/>Bulk allocations]
        FIXED[FixedBufferAllocator<br/>Stack allocations]
    end

    subgraph "Object Lifecycle"
        CREATE[create/init]
        USE[use]
        DEINIT[deinit/destroy]
    end

    subgraph "Native Objects"
        WIN[Windows]
        WV[WebViews]
        COMP[Components]
        TRAY[Tray Items]
    end

    GPA --> ARENA
    GPA --> FIXED

    CREATE --> USE
    USE --> DEINIT

    GPA --> WIN
    GPA --> WV
    ARENA --> COMP
    FIXED --> TRAY
```

---

## Plugin System

```mermaid
graph TB
    subgraph "Plugin Host"
        PM[PluginManager]
        SB[Sandbox]
        API[PluginAPI]
    end

    subgraph "Plugin"
        WASM[WASM Module]
        PERM[Permissions]
        META[Metadata]
    end

    subgraph "Permissions"
        FS[Filesystem]
        NET[Network]
        CLIP[Clipboard]
        NOTIFY[Notifications]
        WIN[Window]
    end

    PM --> SB
    PM --> API
    SB --> WASM
    WASM --> PERM
    WASM --> META

    PERM --> FS
    PERM --> NET
    PERM --> CLIP
    PERM --> NOTIFY
    PERM --> WIN
```

---

## Further Reading

- [TODO.md](../../TODO.md) - Full technical roadmap
- [BRIDGE_API.md](../BRIDGE_API.md) - Bridge API documentation
- [CONTRIBUTING.md](../../.github/CONTRIBUTING.md) - Contribution guidelines
- [API_REFERENCE.md](../API_REFERENCE.md) - API reference
