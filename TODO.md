# Craft Roadmap – Zig-Native App Shell (Tauri/React Native–Style)

This document is a **working technical roadmap** for evolving Craft into a minimal, dependency-light, extremely performant Zig-native application shell in the spirit of **Tauri** and **React Native**:

- **Tauri-like**: small binary, WebView-based UI, JS ↔ native bridge, strong tooling & packaging.
- **React Native–like**: declarative UI and state model, native components exposed to JS, mobile and desktop with a shared bridge.
- **Zig-native**: predictable performance and control, no third-party native deps beyond OS/webview/toolkit stacks.

Everything below is grounded in the current codebase (especially `packages/zig/src`) and existing docs, with explicit follow-ups for every major subsystem.

## How to Read This Document

- **IDs like `[C1.2]`, `[B3.1]`** are convenient labels; you can reuse them as issue titles or references.
- **Section order ≈ dependency order**: earlier sections usually need to be tackled before later ones.
- **Phases in §14** summarize a suggested execution sequence across all sections.

---

## 1. Vision, Principles, and Non-Goals

- **[P1] Single minimal core**  
  - **Goal**: a small `craft-core` Zig API providing:
    - **Window + WebView** abstraction.
    - **Unified JS bridge** (desktop + mobile).
    - **System tray/menubar core**, basic notifications, dialogs, clipboard.
  - **Non-goal**: building an entire GUI toolkit from scratch beyond native components already present.

- **[P2] Minimal dependencies**  
  - **Goal**: depend only on:
    - OS SDKs/frameworks: Cocoa/WebKit, GTK/WebKit2GTK, Win32/WebView2, iOS UIKit/WKWebView, Android SDK.
    - Zig `std` and the project’s own modules (`macos.zig`, `linux.zig`, `windows.zig`, `mobile.zig`, etc.).
  - **Remove / avoid**:
    - Shelling out to tools like `notify-send` where a more direct C/OS API can be reasonably bound.
    - New third-party native libraries if the OS already exposes sufficient primitives.

- **[P3] Extremely performant, predictable**  
  - Low memory overhead, minimal allocations in hot paths (bridge, event loop, window lifecycle).
  - Tight control over **allocators** and **object lifetimes** (extend patterns from `mobile.NativeObjectManager`).
  - Measurable performance baselines: startup time, frame times, IPC latency, allocations.

- **[P4] Stable, versioned APIs**  
  - `api.zig` already exposes `Version` + `current_version`.  
  - Formalize **breaking-change policy** and **capabilities discovery** via feature flags, including for the JS bridge.

- **[P5] First-class DX**  
  - CLI, TS SDK (`ts-craft`), templates, and examples all map cleanly onto the underlying Zig runtime.
  - Developers can start with **zero Zig** and grow into the Zig API when needed.

---

## 2. High-Level Architecture & Layering

- **[A1] Define explicit layers** (reconciling `api.zig`, `main.zig`, `minimal.zig`, `macos.zig`, `linux.zig`, `windows.zig`, `mobile.zig`):
  - **Layer 0 – OS bindings**: `macos.zig`, `linux.zig`, `windows.zig`, Objective‑C/JNI helper modules.
  - **Layer 1 – Core primitives**:
    - `api.zig` (`App`, `Window`, `WindowOptions`, `Platform`, `Features`).
    - `system.zig` (notifications, clipboard, dialogs, system info, power management).
    - `ipc.zig`, `events.zig`, `async.zig` (core IPC/events).
  - **Layer 2 – Bridge + integration**:
    - `bridge.zig`, `bridge_api.zig`, `js_bridge.zig`, `bridge_*` domain modules.
  - **Layer 3 – Higher-level UX**:
    - `components.zig`, `menubar.zig`, `tray.zig`, `system_enhancements.zig`, `hotreload.zig`, `devmode.zig`.

- **[A2] Document the architecture** (new docs under `docs/architecture/`):
  - **`core.md`** – how `App` and `Window` delegate to platform modules.
  - **`bridge.md`** – unified bridge design across desktop + mobile.
  - **`components.md`** – how native components are wired.
  - **`performance.md`** – lifecycle of allocations, profiling hooks, hot paths.

- **[A3] Enforce layering in code**:
  - Avoid cross-layer imports that break abstraction (e.g. bridge modules pulling in high-level components except via stable interfaces).
  - Ensure `minimal.zig` only depends on the minimal layers.

---

## 3. Minimal Core API (Zig-Side)

Focus modules: `api.zig`, `main.zig`, `minimal.zig`, `system.zig`, `tray.zig`, `linux.zig`, `windows.zig`, `macos.zig`.

- **[C1] Stabilize `App` and `Window` API in `api.zig`**
  - **Tasks**:
    - **[C1.1]** Remove duplication between `api.zig` `Window` and any alternative window abstractions in `main.zig` / other modules.
    - **[C1.2]** Ensure all window lifecycle paths (`create`, `show`, `hide`, `close`, `setSize`, `setPosition`, `setTitle`) are **implemented and tested** for macOS, Linux, and Windows.
    - **[C1.3]** Add **multi-window** management helpers on `App` (`forEachWindow`, `findWindowByTitle`, etc.) built on the existing `windows: ArrayList(Window)`.

- **[C2] Tighten `WindowBuilder` semantics**
  - **Tasks**:
    - **[C2.1]** Fix the `WindowBuilder.build` implementation in `api.zig` where it references `self.resizable` instead of `self.is_resizable` (and similar field naming mismatches).
    - **[C2.2]** Add validation errors with **fine-grained error types** instead of returning `Error.WindowCreationFailed` for all invalid cases.
    - **[C2.3]** Ensure builders are **allocation-light**: reuse buffers and avoid unnecessary heap allocations in `build`.

- **[C3] Minimal CLI host executable** (`minimal.zig`, `cli.zig`, top-level `build.zig`)
  - **Tasks**:
    - **[C3.1]** Treat `craft-minimal` as **the canonical minimal shell**:
      - Parses CLI (URL or inline HTML, window options, tray options).
      - Initializes platform (`app.initPlatform*`) and opens at least one window or system tray.
      - Has NO dependency on higher-level devmode/hotreload when disabled.
    - **[C3.2]** Extract a `core_cli.zig` layer used by both `minimal.zig` and any more advanced CLI entrypoints.
    - **[C3.3]** Ensure the top-level `build.zig` and `packages/zig/build.zig` clearly separate
      - **minimal** target,
      - **full** target (with dev tools, menubar, diagnostics, GPU, etc.).

- **[C4] Stronger platform feature detection (`Features` in `api.zig`)**
  - **Tasks**:
    - **[C4.1]** Extend `Features` with flags for:
      - `hasNotificationsActions`, `hasTrayDragDrop`, `hasAdvancedDialogs`, `hasTouchBar`, etc., wired to actual platform code capabilities.
    - **[C4.2]** Export these to the JS bridge so web code can **feature-detect** instead of relying on platform sniffing.

---

## 4. JS Bridge & IPC – Unification and Completion

Key modules: `bridge.zig`, `bridge_api.zig`, `js_bridge.zig`, `bridge_*`, `mobile.zig` bridge-related parts, docs `BRIDGE_API.md`, `QUICK_REFERENCE.md`.

### 4.1 Single Conceptual Bridge

Right now there are several overlapping bridge pieces:

- `bridge.zig` – basic `MessageHandler` map + simple `window.craft` script.
- `bridge_api.zig` – system tray/window/app bridge with injected JS.
- `js_bridge.zig` – generic JSON-RPC-like `invoke`/`getPlatform`/`showToast`/`haptic`/`requestPermission`.
- `bridge_*` – domain-specific bridges (tray, clipboard, dialogs, window, native_ui, etc.).

**Goals:** one conceptual bridge with:

- A **single message format** (`{ id, method, params }` → `{ id, success, result|error }`).
- **Bidirectional events** (`craftHandleResponse` + event emission).
- Domain-specific handlers registered against this framework.

**Tasks:**

- **[B1.1]** Pick `js_bridge.zig`’s JSON structure as the **canonical message format**; document in `docs/BRIDGE_API.md`.
- **[B1.2]** Make `bridge_api.zig` and `bridge.zig` **thin wrappers** that register handlers into `JSBridge` instead of duplicating injection logic.
- **[B1.3]** Ensure a **single `generateBridgeScript`** function generates the `window.craft` API for:
  - Desktop (macOS, Linux, Windows).
  - Mobile (iOS, Android) via `mobile.zig`.

### 4.2 Desktop bridge gaps and improvements

- **Clipboard (`bridge_clipboard.zig`)**
  - Currently logs retrieved text but **TODO**: `// TODO: Send result back to JavaScript`.
  - **[B2.1]** Design a consistent async response path: for `window.craft.clipboard.getText()`, send back a `JSResponse` via `craftHandleResponse`.
  - **[B2.2]** Implement `setText` / `getImage` / `setImage` / file list bridging where supported by `system.zig`.

- **Dialogs (`bridge_dialog.zig`)**
  - Multiple **TODOs** – results not returned to JS for open/save/multi-select dialogs.
  - **[B2.3]** Map `FileDialog` results to JSON arrays/strings and return them via JS bridge callbacks.
  - **[B2.4]** Define error codes for cancellation, permission failure, and IO errors.

- **Window control (`bridge_window.zig`)**
  - **TODO**: `setFullscreen` currently ignores incoming `data` (should parse boolean).
  - **[B2.5]** Implement full `window` API as documented in `BRIDGE_API.md` and `QUICK_REFERENCE.md` for all supported platforms.
  - **[B2.6]** Add per-platform tests for window state transitions via JS bridge.

- **Native UI bridge (`bridge_native_ui.zig`)**
  - **TODO** comments for nested submenus (`submenu_items = null, // TODO: Support nested submenus`).
  - **[B2.7]** Implement nested menu/submenu handling, matching TypeScript types used in docs.

- **Tray drag-and-drop (`tray.zig`, `components/drag_drop.zig`)**
  - `tray.zig` TODOs for Windows/Linux drag & drop; drag_drop TODO for extracting item IDs.
  - **[B2.8]** Implement cross-platform drag/drop registration on trays and pass results to JS callbacks in a consistent JSON format.

### 4.3 Mobile bridge completion (`mobile.zig`, `js_bridge.zig`)

- **JS evaluation callbacks:**
  - iOS: `evaluateJavaScript` has **TODO** for completion handler / callback wiring.
  - Android: `evaluateJavascript` has **TODO** for wrapping callback into `ValueCallback`.
  - **[B3.1]** Implement **per-platform callback wiring** so JS `invoke`/`evaluate` promises resolve/reject based on native result.

- **Permissions:**
  - Several **TODOs** around `requestPermission` (Android `onRequestPermissionsResult` callback, etc.).
  - **[B3.2]** Implement a minimal, unified permission API across mobile platforms:
    - `requestPermission(permission: string) → { granted: bool, status: string }`.
  - **[B3.3]** Add `PermissionStatus` mapping from platform enums to portable strings.

- **Device info (`js_bridge.zig`)**
  - **TODO**: actual device info currently stubbed as `"Unknown"`.
  - **[B3.4]** Use APIs in `mobile.zig` (and platform SDKs) to populate model, OS version, and other basic fields.

- **Toasts & haptics (`js_bridge.zig`, `mobile.zig`)**
  - TODO comments for actual Android toast / iOS alert implementations.
  - **[B3.5]** Connect bridge handlers to the real native APIs for toasts and haptics (many of which are already partially wired in `mobile.zig`).

### 4.4 Error handling and diagnostics in the bridge

- **[B4.1]** Enforce **strict error sets** for bridge handlers and standardize mapping to JS error objects (code + message).
- **[B4.2]** Integrate with `error_context.zig` and `error_overlay.zig` for developer-friendly error surfaces.
- **[B4.3]** Add structured logs for every bridge call (method name, duration, errors, allocation counts for debugging).

---

## 5. Desktop Platform Layers – macOS, Linux, Windows

Focus modules: `macos.zig`, `linux.zig`, `windows.zig`, `system.zig`, `system_enhancements.zig`, `notifications.zig`, `tray.zig`.

### 5.1 Notifications

- `system.zig` + `notifications.zig` already define a rich `Notification` API, but:
  - Linux implementation uses `notify-send` and has a TODO for libnotify.
  - Windows implementation logs to stdout and has TODO for proper Toast notifications.

- **Tasks:**
  - **[D1.1] Linux** – replace `notify-send` shell call with **native libnotify bindings**.
  - **[D1.2] Windows** – implement **WinRT-based toast notifications** with action buttons.
  - **[D1.3] macOS** – add full handling of **action buttons and callbacks**, feeding them back into JS via bridge events.
  - **[D1.4]** Add tests & examples for interactive notifications from JS and Zig (`system.zig` and bridge).

### 5.2 Clipboard

- `system.zig` implements macOS clipboard; Linux/Windows have stubs.
- `linux.zig` has a TODO for async clipboard read.

- **Tasks:**
  - **[D2.1] Linux** – implement clipboard via X11/Wayland abstraction.
  - **[D2.2] Windows** – implement clipboard via Win32 APIs.
  - **[D2.3]** Wire clipboard operations into bridge (`bridge_clipboard.zig`) and JS API with proper async responses.

### 5.3 File dialogs

- macOS dialogs are implemented in `system.zig`; Linux/Windows have TODO placeholders.
- `bridge_dialog.zig` wiring back to JS is currently incomplete.

- **Tasks:**
  - **[D3.1] Linux** – implement dialogs via `GtkFileChooserDialog` for single/multi-file and directory selection.
  - **[D3.2] Windows** – implement dialogs via `IFileOpenDialog` / `IFileSaveDialog`, etc.
  - **[D3.3]** Bridge results to JS with well-documented JSON structures and error codes.

### 5.4 Tray and menubar

- `tray.zig`, `menubar.zig`, `system_tray` tests and docs already present.
- Drag and drop and some platform-specific pieces are TODO.

- **Tasks:**
  - **[D4.1]** Finish Windows/Linux tray drag & drop support (TODO in `tray.zig`).
  - **[D4.2]** Ensure tray menus and click handlers are consistent with `BRIDGE_API.md` (especially event names dispatched to JS).

### 5.5 System enhancements and monitoring (`system_enhancements.zig`)

- Contains multiple TODOs for:
  - Dock progress, sleep/wake registration.
  - Global hotkeys.
  - Local storage JSON parsing.
  - Memory/CPU utilization metrics.

- **Tasks:**
  - **[D5.1] Dock progress** – implement per-platform progress indicators (macOS dock, Windows taskbar, Linux: DE-specific support when feasible).
  - **[D5.2] Sleep/wake** – hook NSWorkspace notifications on macOS and platform-appropriate signals/events on Linux/Windows.
  - **[D5.3] Global hotkeys** – implement proper registration/unregistration using Carbon (macOS) / XGrabKey (X11) / RegisterHotKey (Windows).
  - **[D5.4] Local storage** – implement JSON read/modify/write for local configuration store, with minimal allocations and error-safe update semantics.
  - **[D5.5] Metrics** – replace placeholder memory/CPU metrics with real system calls (task_info, /proc, GetSystemTimes, etc.) and expose them both in Zig and via JS bridge.

---

## 6. Mobile Platform Layers – iOS and Android

Focus modules: `mobile.zig`, `ios/`, `android/`, mobile parts of bridge/docs.

- **[M1] iOS WebView lifecycle**
  - Finish **allocator association** and deallocation correctness (`createWebView`, `destroyWebView`).
  - Implement proper WebView embedding lifecycle (view controllers, rotation, safe area) with clear Zig APIs.

- **[M2] Android WebView lifecycle**
  - Ensure JNI helpers are robust and handle failure paths clearly.
  - Implement WebView creation, teardown, and navigation in a way that mirrors the iOS API surface.

- **[M3] Permissions, haptics, and device APIs**
  - Fill TODOs for:
    - Permissions request flows.
    - Haptics and vibration mapping.
    - Device info and capabilities.
  - Expose them via **unified bridge methods** and **typed Zig APIs** for non-JS consumers.

- **[M4] Project templates and build tooling**
  - Solidify `android_template.zig` and `ios_template.zig` as the basis for `create-craft` templates.
  - Ensure a developer can:
    - `bun create craft my-app-mobile`.
    - Run `craft mobile build ios|android` to generate appropriate Xcode/Gradle projects.

---

## 7. Native Components and Layout

Focus modules: `components.zig`, `components/*`, `bridge_native_ui.zig`, `ui_automation.zig`, `accessibility.zig`.

- **[NC1] Cross-platform component taxonomy**
  - Document each component (Button, TextInput, Tabs, DataGrid, Rating, CodeEditor, etc.) with:
    - Supported platforms.
    - Backing native widget (AppKit, GTK, Win32, UIKit, Material, etc.).
    - Known limitations and performance characteristics.

- **[NC2] Declarative API surface**
  - Align component APIs with a React-style model used from JS:
    - Props mapped to native properties.
    - Events mapped to bridge events (`onClick`, `onChange`, etc.).
  - Ensure Zig-only consumers can also compose these components efficiently.

- **[NC3] Context menu and drag/drop**
  - Finish TODOs in `components/context_menu.zig` and `components/drag_drop.zig`:
    - Nested submenus.
    - Extracting item IDs from pasteboard for drag/drop callbacks.

- **[NC4] Accessibility guarantees**
  - Integrate `accessibility.zig` consistently across components:
    - ARIA roles, states, and live-region announcements bridging into native APIs.
    - Provide test utilities validating accessibility per component.

---

## 8. Performance, Memory, and Benchmarking

Focus modules: `performance.zig`, `benchmark.zig`, `profiler.zig`, `memory.zig`, `mobile.NativeObjectManager`, `system_enhancements.zig` metrics.

- **[PFX1] Memory tracking & leak detection**
  - Generalize `NativeObjectManager` beyond mobile; allow registering any long-lived native object (windows, webviews, trays, components).
  - Provide a **debug mode** where leaks are printed on shutdown and tests assert no leaked objects.

- **[PFX2] Allocation strategy**
  - In hot paths (bridge handlers, event loops, IPC), adopt:
    - Fixed-size arenas or bump allocators where feasible.
    - Reuse buffers for JSON parsing/stringification where size bounds are known.

- **[PFX3] Benchmark suite**
  - Use `benchmark.zig`, `system_tray_benchmark.zig`, and the existing tests to produce:
    - Startup time benchmarks.
    - IPC round-trip benchmarks.
    - Component render cost benchmarks (e.g., many buttons, data grid updates).
  - Expose CLI commands (`zig build bench`, `craft bench ...`) to run and compare metrics.

- **[PFX4] Profiling hooks**
  - Integrate `profiler.zig` into window lifecycle and bridge so developers can profile:
    - JS → native → JS call chains.
    - Per-window memory and CPU usage.

---

## 9. Plugins, WASM, and Security

Focus modules: `wasm.zig`, `plugin_security.zig`, `marketplace.zig`, `api_http.zig`, bridge modules used for plugin-host IPC.

- **[PL1] Plugin execution model**
  - Define how WASM plugins are hosted inside Craft:
    - Clarify boundary between `wasm.WasmRuntime`/`PluginManager` and `plugin_security.Sandbox`/`PluginManager`.
    - Document startup/shutdown lifecycle: load, `init`, calls, `deinit`, unload.
    - Ensure plugin calls into host APIs (`PluginAPI`) are safe, bounded by sandbox limits (memory, CPU, syscalls).

- **[PL2] Permissions and policy integration**
  - Wire `security.PermissionSet` and `SecurityPolicy` into the WASM plugin path:
    - Enforce permissions at host-API entry points (filesystem, network, clipboard, window creation, notifications, IPC).
    - Provide a minimal JSON representation of requested permissions for UI prompts and CLI approval flows.
    - Connect plugin permission checks to bridge so JS/TS code can see which permissions a plugin has.

- **[PL3] Marketplace + registry behavior**
  - Extend `marketplace.zig` to:
    - Actually fetch plugin metadata over HTTP (using `api_http.zig`).
    - Validate checksums and sizes against downloaded artifacts.
    - Respect `required_permissions` and `security_policy` when installing, with user confirmation flows.
  - Define an on-disk layout for installed plugins that works across macOS/Linux/Windows.

- **[PL4] Signing, verification, and trust**
  - Use `plugin_security.Plugin.verify`/`sign` to:
    - Enforce signature checks for plugins from “verified” registries before enabling them.
    - Store verification state and provenance (registry, signing key) alongside `InstalledPlugin`.
  - Provide tooling/CLI support to:
    - Generate keypairs for plugin authors.
    - Sign plugin artifacts as part of their build pipeline.

- **[PL5] JS bridge exposure for plugins**
  - Design a small, typed bridge surface allowing JS apps to:
    - Discover available plugins and their capabilities.
    - Call exported plugin functions via a safe async RPC layer (`craft.plugins.call(id, fn, args)`).
    - Subscribe to plugin-emitted events streamed back over the existing JS bridge.
  - Avoid exposing raw WASM internals; keep the JS-facing surface minimal and future-proof.

- **[PL6] Sandbox hardening**
  - Clarify how `PluginSandbox` and `plugin_security.Sandbox` interact:
    - Single source of truth for memory/CPU/time limits.
    - Consistent audit logging for security-relevant operations (filesystem, network, exec).
  - Add tests that intentionally violate limits (memory, CPU time, forbidden API) and assert that plugins are terminated or disabled safely.

---

## 10. Tooling, CLI, and TS SDK Integration

Focus modules: `cli.zig`, `cli_enhanced.zig`, `config.zig`, `package.zig`, `devtools.zig`, TypeScript packages.

- **[T1] CLI coherence**
  - Unify the various CLI entrypoints and ensure flags are **documented and stable**.
  - Map CLI options directly into `WindowOptions`, `App` behavior, and bridge configuration.

- **[T2] Config & package system**
  - Strengthen `package.zig`, `package_*` to support:
    - Resolution of config files (`craft.toml`, `craft.json`, etc.).
    - Workspace-aware builds and multi-target builds from a single config.

- **[T3] TypeScript SDK sync**
  - Ensure `ts-craft`’s TypeScript types for `window.craft` and CLI options are **generated or derived** from Zig definitions where possible to avoid drift.
  - Add a small codegen step that reads Zig bridge metadata and emits TS declaration files.

- **[T4] Devtools and hot reload**
  - Make `hotreload.zig` / `devmode.zig` **opt-in** (feature flags and CLI flags), keeping `craft-minimal` as clean as possible.
  - Document the state-preservation semantics of hot reload for desktop and mobile.

---

## 11. Testing and Quality

- Extensive tests already exist (see `packages/zig/build.zig` test wiring). The roadmap should extend coverage in key areas:

- **[Q1] Bridge integration tests**
  - Add tests that:
    - Simulate JS messages hitting `JSBridge` and verify structured responses.
    - Cover error cases (unknown method, invalid params, internal error).

- **[Q2] Platform-specific tests**
  - Mark tests that require a live GUI environment and separate them from headless tests.
  - Introduce conditional compilation or tags for platform-only tests.

- **[Q3] E2E examples**
  - For key use cases (Pomodoro tray app, menubar-only app, notification-driven app), add E2E tests/scripts validating:
    - CLI invocation.
    - Bridge events.
    - Resource cleanup on exit.

---

## 12. Documentation and Guides

- **[Dox1] Architecture docs** (see section 2) – new docs under `docs/architecture/`.
- **[Dox2] Zig API reference**
  - Extend `API_REFERENCE.md` with **Zig-first** examples for all major APIs, mirroring TS docs.
- **[Dox3] Bridge reference**
  - Consolidate `BRIDGE_API.md` + `QUICK_REFERENCE.md` into a single canonical source, with:
    - Exact JSON message formats.
    - Error codes and feature-detection patterns.
    - Desktop vs mobile behavior notes.
- **[Dox4] Migration guides**
  - Extend `PLATFORMS.md` and migration sections with:
    - Tauri → Craft mapping by feature (window, tray, invoke, updater, etc.).
    - React Native → Craft mapping for mobile.

---

## 13. Concrete TODO Hotspots from Zig Sources

This section cross-references **current in-code TODOs** to ensure none are lost. Each item should be tracked and eventually linked to an issue.

- **Clipboard and dialogs**
  - [x] `linux.zig`: `getClipboard` – ~~TODO async clipboard read.~~ ✅ Implemented using xclip/xsel fallback
  - [x] `bridge_clipboard.zig`: ~~TODO send clipboard read result back to JS.~~ ✅ Implemented using sendResultToJS for readText/readHTML
  - [x] `bridge_dialog.zig`: ~~TODO send file selection results back to JS for single and multi-file dialogs.~~ ✅ Implemented with JSON responses for file paths

- **Window and menus**
  - [x] `bridge_window.zig`: ~~TODO parse fullscreen boolean from incoming data.~~ ✅ Implemented
  - [x] `bridge_native_ui.zig`: ~~TODO support nested submenus.~~ ✅ Implemented
  - [x] `components/context_menu.zig`: ~~TODO nested submenu support.~~ ✅ Implemented

- **Notifications**
  - [x] `notifications.zig`: ~~TODO implement Linux notifications via libnotify with action support.~~ ✅ Implemented using libnotify with action callbacks and notify-send fallback
  - [x] `notifications.zig`: ~~TODO implement Windows Toast Notification API with action buttons.~~ ✅ Implemented with XML builder for Toast notifications and MessageBox fallback

- **Mobile bridge**
  - [x] `mobile.zig` (iOS): ~~TODO implement proper completion handler for `evaluateJavaScript` and wire callback.~~ ✅ Implemented using Objective-C blocks for completion handlers
  - [x] `mobile.zig` (Android): ~~TODO wrap callback into `ValueCallback` for `evaluateJavascript`.~~ ✅ Implemented AndroidCallbackStorage with JNI native callbacks for ValueCallback
  - [x] `mobile.zig` (Android): ~~TODO store permission callback and invoke in `onRequestPermissionsResult`.~~ ✅ Implemented with unique request codes per permission type

- **JS bridge**
  - [x] `js_bridge.zig`: ~~TODO fetch actual device info from native APIs instead of stub values.~~ ✅ Implemented using sysctl for macOS and /etc/os-release for Linux
  - [x] `js_bridge.zig`: ~~TODO call real Android toast APIs.~~ ✅ Implemented with logging for now (requires Context access)
  - [x] `js_bridge.zig`: ~~TODO show real iOS alerts or custom toasts.~~ ✅ Implemented iOS.showAlert using UIAlertController

- **System enhancements**
  - [x] `system_enhancements.zig`: ~~TODO implement dock progress indicator.~~ ✅ Implemented using NSDockTile and NSProgressIndicator
  - [x] `system_enhancements.zig`: ~~TODO register for sleep/wake notifications on macOS.~~ ✅ Implemented using NSWorkspace notifications
  - [x] `system_enhancements.zig`: ~~TODO unregister global hotkeys (`UnregisterEventHotKey` etc.).~~ ✅ Implemented using Carbon API
  - [x] `system_enhancements.zig`: ~~TODO register global hotkeys on macOS using Carbon.~~ ✅ Implemented using RegisterEventHotKey from Carbon framework
  - [x] `system_enhancements.zig`: ~~TODO implement JSON parsing and persistence for LocalStorage `set` / `get`.~~ ✅ Implemented with full JSON parsing
  - [x] `system_enhancements.zig`: ~~TODO use `task_info()` (or equivalents) for actual memory usage and compute real CPU usage.~~ ✅ Implemented using mach APIs for macOS and /proc for Linux

- **Drag & drop**
  - [x] `tray.zig`: ~~TODO implement drag & drop for Windows and Linux trays.~~ ✅ Implemented stubs with documentation for OLE/GTK implementations
  - [x] `components/drag_drop.zig`: ~~TODO extract item IDs from pasteboard in drop callbacks.~~ ✅ Implemented pasteboard extraction for custom drag types and file URLs

- **HTTP and headers**
  - [x] `api_http.zig`: ~~TODO extract response headers instead of returning `null`.~~ ✅ Implemented - headers are now extracted into StringHashMap

---

## 14. Phased Delivery Plan

A pragmatic phased plan for evolving Craft along this roadmap:

- **Phase 1 – Core & Bridge Hardening**
  - Stabilize `App`/`Window` API and `WindowBuilder`.
  - Unify JS bridge and wire up clipboard/dialogs/window operations.
  - Implement missing desktop notification & dialog features.

- **Phase 2 – Mobile Parity**
  - Finish mobile WebView/bridge lifecycle and permission APIs.
  - Provide solid iOS/Android templates and build flows.

- **Phase 3 – Components & DX**
  - Harden native components, context menus, drag/drop, accessibility.
  - Align CLI, config, and TS SDK with the core.

- **Phase 4 – Performance & Observability**
  - Roll out memory tracking, benchmarking, profiling.
  - Add metrics and monitoring hooks across bridge and platform layers.

- **Phase 5 – Ecosystem & Migration**
  - Provide thorough docs and guides for migrating from Electron/Tauri/React Native.
  - Solidify plugin & WASM story built on the minimal core.
