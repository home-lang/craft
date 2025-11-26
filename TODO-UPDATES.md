# Craft Framework - TODO Updates & Improvements

> A comprehensive list of updates and improvements to make Craft the premier tool for building native mobile and desktop apps with JS/TS APIs.

## Table of Contents

1. [Mobile Platform Improvements](#1-mobile-platform-improvements)
2. [Desktop Platform Improvements](#2-desktop-platform-improvements)
3. [JavaScript/TypeScript API Improvements](#3-javascripttypescript-api-improvements)
4. [Native Bridge Enhancements](#4-native-bridge-enhancements)
5. [Build & Tooling Improvements](#5-build--tooling-improvements)
6. [Developer Experience](#6-developer-experience)
7. [Performance Optimizations](#7-performance-optimizations)
8. [Security Enhancements](#8-security-enhancements)
9. [Documentation & Examples](#9-documentation--examples)
10. [Testing Infrastructure](#10-testing-infrastructure)

---

## 1. Mobile Platform Improvements

### 1.1 iOS Improvements

#### Critical - Core Implementation Gaps
- [ ] **Implement actual Zig to iOS bridge** - Current `mobile.zig` has stub implementations for:
  - `createWebView()` - needs Objective-C runtime integration
  - `loadURL()` - needs `[webview loadRequest:]` implementation
  - `evaluateJavaScript()` - needs `[webview evaluateJavaScript:completionHandler:]`
  - `requestPermission()` - needs iOS permission APIs
  - `triggerHaptic()` - needs `UIImpactFeedbackGenerator` integration

- [ ] **Complete Swift template features** - `CraftApp.swift` has many declared but incomplete methods:
  - AR/ARKit integration (methods declared but not fully implemented)
  - ML/Vision Kit integration
  - HealthKit data queries
  - Background task execution
  - Watch connectivity message handling

- [ ] **Add missing iOS capabilities**:
  - [ ] App Clips support
  - [ ] SharePlay integration
  - [ ] Live Activities (Dynamic Island)
  - [ ] Focus filters
  - [ ] App Intents (iOS 16+)
  - [ ] TipKit integration (iOS 17+)
  - [ ] StoreKit 2 full implementation
  - [ ] CarPlay support

#### High Priority
- [ ] **Unified JS Bridge API** - Standardize the iOS bridge API to match the desktop `window.craft` API
- [ ] **iOS-specific native components**: UIKit navigation, tab bars, collection views, SwiftUI integration
- [ ] **Push notifications**: APNs integration, rich notifications, notification actions
- [ ] **App lifecycle improvements**: Scene-based lifecycle, state restoration, background modes

### 1.2 Android Improvements

#### Critical - Core Implementation Gaps
- [ ] **Implement actual Zig to Android bridge** - Current `mobile.zig` Android section has stub implementations:
  - `createWebView()` - needs JNI integration
  - `loadURL()` - needs `webView.loadUrl()` via JNI
  - `evaluateJavaScript()` - needs `webView.evaluateJavascript()` via JNI
  - `requestPermission()` - needs `ActivityCompat.requestPermissions()`
  - `vibrate()` - needs Vibrator service via JNI
  - `showToast()` - needs Toast via JNI

- [ ] **Complete Kotlin template features** - `MainActivity.kt.template` needs:
  - Full CraftBridge implementation matching iOS capabilities
  - All native API bindings (camera, biometrics, etc.)
  - Material Design 3 theming
  - Edge-to-edge display support

- [ ] **Add missing Android capabilities**:
  - [ ] Jetpack Compose integration
  - [ ] Material You dynamic colors
  - [ ] Predictive back gesture
  - [ ] Per-app language preferences
  - [ ] Photo picker (Android 13+)
  - [ ] Notification permission (Android 13+)
  - [ ] Foreground services
  - [ ] Work Manager for background tasks

#### High Priority
- [ ] **Android-specific native components**: Bottom sheets, navigation drawer, RecyclerView
- [ ] **Firebase integration**: FCM, Analytics, Crashlytics, Remote Config
- [ ] **Play Store requirements**: Target SDK compliance, privacy manifest, data safety form

### 1.3 Cross-Platform Mobile

- [ ] **Unified mobile API** - Create consistent API across iOS and Android for:
  - Device info and capabilities
  - Haptics
  - Permissions
  - Camera and image picker
  - Biometrics
  - Secure storage
  - Location
  - Notifications
  - Share functionality
  - App lifecycle events

- [ ] **React Native-style component system**:
  - [ ] View, Text, Image abstractions
  - [ ] Flexbox layout engine
  - [ ] Platform-specific styling
  - [ ] Animated API
  - [ ] Make sure our Headwind CSS integration works properly and is exposed for the user (like Tailwind, ~/Code/zig-headwind)

---

## 2. Desktop Platform Improvements

### 2.1 macOS Improvements

#### In Progress (from existing TODO.md)
- [ ] **Phase 6: Memory Management & Cleanup**
  - [ ] Use associated objects for Zig to Objective-C connections
  - [ ] Implement `dealloc` methods for dynamic classes
  - [ ] Track all allocations in bridge
  - [ ] Test for memory leaks with Instruments

- [ ] **Phase 7: SF Symbols Integration**
  - [ ] Create `createSFSymbol()` function
  - [ ] Configure point size and weight
  - [ ] Handle missing symbols with fallbacks
  - [ ] Cache loaded symbols

- [ ] **Phase 8: Testing & Polish**
  - [ ] Build full Finder-like demo app
  - [ ] Performance testing with 1,000+ files

- [ ] **Phase 9: Advanced Features**
  - [ ] Drag and drop support (NSDraggingSource/Destination)
  - [ ] Context menus (NSMenu)
  - [ ] Quick Look support (QLPreviewPanel)

#### Additional macOS Improvements
- [ ] **Native macOS features**: Touch Bar, Handoff/Continuity, Sidecar, Stage Manager, Desktop widgets
- [ ] **Window management**: Native tabs, split view, full screen spaces, window snapping
- [ ] **System integration**: Spotlight, Quick Actions, Services menu, Share extensions

### 2.2 Linux Improvements

- [ ] **Complete Linux implementation** - `linux.zig` needs:
  - [ ] Full GTK4 integration
  - [ ] Wayland native support
  - [ ] libadwaita for modern GNOME styling
  - [ ] KDE/Qt fallback support

- [ ] **Linux-specific features**:
  - [ ] D-Bus integration
  - [ ] XDG desktop integration
  - [ ] Flatpak packaging
  - [ ] Snap packaging
  - [ ] System tray (AppIndicator/StatusNotifier)
  - [ ] MPRIS media controls
  - [ ] Portal APIs

### 2.3 Windows Improvements

- [ ] **Complete Windows implementation** - `windows.zig` needs:
  - [ ] WebView2 full integration
  - [ ] WinUI 3 components
  - [ ] Windows App SDK integration

- [ ] **Windows-specific features**:
  - [ ] Jump lists
  - [ ] Taskbar progress
  - [ ] Toast notifications
  - [ ] Windows Hello biometrics
  - [ ] MSIX packaging
  - [ ] Auto-update via MSIX
  - [ ] Windows widgets

---

## 3. JavaScript/TypeScript API Improvements

### 3.1 Core API Enhancements

- [ ] **Complete TypeScript type definitions** - Expand `types.ts` with mobile and platform-specific configs
- [ ] **Async/await everywhere** - Convert callback-based APIs to Promise-based
- [ ] **Event emitter pattern** - Add `craft.on()` and `craft.off()` for all events

### 3.2 New API Modules

- [ ] **File System API** (`craft.fs`): readFile, writeFile, readDir, mkdir, remove, exists, watch
- [ ] **Database API** (`craft.db`): SQLite wrapper with execute, query, transaction
- [ ] **HTTP Client API** (`craft.http`): fetch, download, upload with progress
- [ ] **Process API** (`craft.process`): spawn, exec, env, cwd, exit
- [ ] **Crypto API** (`craft.crypto`): randomBytes, hash, encrypt, decrypt

### 3.3 Framework Bindings

- [ ] **React bindings** (`@craft/react`): useCraft, useWindow, useTray, useNotification hooks
- [ ] **Vue bindings** (`@craft/vue`): Composition API composables
- [ ] **Svelte bindings** (`@craft/svelte`): Svelte stores and actions

---

## 4. Native Bridge Enhancements

### 4.1 Bridge Architecture

- [ ] **Bidirectional async communication**: Promise-based responses, streaming, binary data transfer
- [ ] **Message queue system**: Reliable delivery, ordering, retry logic, offline queue
- [ ] **Type-safe bridge protocol**: Auto-generated types from Zig definitions

### 4.2 Native Component Bridge

- [ ] **Expose native components to JS** - Complete `bridge_native_ui.zig`:
  - Native sidebar creation
  - Native file browser
  - Native split views
  - Selection and interaction callbacks

- [ ] **Native menu system**: Application menus, context menus, accelerators
- [ ] **Native dialogs**: Open/save dialogs, message boxes, color pickers

---

## 5. Build & Tooling Improvements

### 5.1 CLI Enhancements

- [ ] **Unified build command**: `craft build` for all platforms
- [ ] **Development server**: `craft dev` with hot reload for all platforms
- [ ] **Platform targeting**: `craft build --platform ios,android,macos`
- [ ] **Release builds**: `craft build --release` with optimizations and signing

### 5.2 Project Scaffolding

- [ ] **More templates**: `craft init --template <name>`
  - [ ] `blank` - Minimal starter
  - [ ] `tabs` - Tab-based navigation
  - [ ] `drawer` - Drawer navigation
  - [ ] `dashboard` - Admin dashboard
  - [ ] `e-commerce` - Shopping app
  - [ ] `social` - Social media app

- [ ] **Plugin system**: `craft plugin add <name>`
- [ ] **Asset management**: `craft assets optimize`

### 5.3 Packaging Improvements

- [ ] **Complete packaging API** (`package.ts`):
  - [ ] Implement `createDEB()` for Linux
  - [ ] Implement `createRPM()` for Linux
  - [ ] Implement `createAppImage()` for Linux
  - [ ] Implement `createMSI()` for Windows (WiX integration)
  - [ ] Add code signing for all platforms
  - [ ] Add notarization for macOS

- [ ] **Auto-updater**: Built-in update mechanism for all platforms
- [ ] **Delta updates**: Incremental updates to reduce download size

### 5.4 CI/CD Integration

- [ ] **GitHub Actions templates**: Build, test, release workflows
- [ ] **GitLab CI templates**: Pipeline configurations
- [ ] **Fastlane integration**: iOS and Android deployment automation

---

## 6. Developer Experience

### 6.1 Hot Reload Improvements

- [ ] **Complete hot reload implementation** (`hotreload.zig`):
  - [ ] WebSocket server for live reload
  - [ ] CSS-only hot reload (no full page refresh)
  - [ ] Component-level hot reload
  - [ ] State preservation across reloads (partially implemented)

- [ ] **Mobile hot reload**: Live reload for iOS simulator and Android emulator

### 6.2 DevTools Enhancements

- [ ] **Complete DevTools implementation** (`devtools.zig`):
  - [ ] Chrome DevTools Protocol server
  - [ ] Network inspector (partially implemented)
  - [ ] Memory inspector (partially implemented)
  - [ ] Performance profiler
  - [ ] Console integration

- [ ] **Native component inspector**: Inspect native UI hierarchy
- [ ] **Bridge message inspector**: Debug JS-to-native communication

### 6.3 Error Handling

- [ ] **Enhanced error messages** (`error_context.zig`):
  - [ ] Actionable error suggestions
  - [ ] Stack traces with source maps
  - [ ] Error recovery strategies
  - [ ] Error reporting integration

- [ ] **Error overlay**: Visual error display in development mode

### 6.4 Logging & Debugging

- [ ] **Structured logging** (`log.zig`): JSON output, log levels, filtering
- [ ] **Remote debugging**: Debug mobile apps from desktop
- [ ] **Performance monitoring**: FPS counter, memory usage, network stats

---

## 7. Performance Optimizations

### 7.1 Startup Performance

- [ ] **Lazy loading**: Load modules on demand
- [ ] **Precompiled assets**: Pre-compile HTML/CSS/JS
- [ ] **Binary size reduction**: Tree shaking, dead code elimination
- [ ] **Cold start optimization**: Target <100ms startup (currently achieved)

### 7.2 Runtime Performance

- [ ] **GPU acceleration** (`gpu.zig`):
  - [ ] Complete Metal backend for macOS
  - [ ] Complete Vulkan backend for Linux/Windows
  - [ ] WebGL acceleration in WebView
  - [ ] Hardware video decode

- [ ] **Memory optimization** (`memory.zig`):
  - [ ] Object pooling
  - [ ] LRU caching
  - [ ] Lazy loading
  - [ ] Memory pressure handling

- [ ] **Animation performance** (`animation.zig`):
  - [ ] 60fps animations
  - [ ] GPU-accelerated transitions
  - [ ] Reduce motion support

### 7.3 Bundle Optimization

- [ ] **Code splitting**: Split bundles by route/feature
- [ ] **Asset optimization**: Image compression, SVG optimization
- [ ] **Compression**: Brotli/gzip for web assets

---

## 8. Security Enhancements

### 8.1 Plugin Security

- [ ] **Complete sandbox implementation** (`plugin_security.zig`):
  - [ ] Permission system (7 types defined, needs enforcement)
  - [ ] Memory limits
  - [ ] CPU time limits
  - [ ] File system restrictions
  - [ ] Network restrictions

- [ ] **Plugin verification**: Signature verification, trusted sources

### 8.2 Application Security

- [ ] **Code signing**: Automated signing for all platforms
- [ ] **Notarization**: macOS notarization automation
- [ ] **Certificate pinning**: For network requests
- [ ] **Secure storage**: Platform keychain integration

### 8.3 WebView Security

- [ ] **Content Security Policy**: Configurable CSP headers
- [ ] **CORS handling**: Proper cross-origin request handling
- [ ] **Script injection protection**: Sanitize user input
- [ ] **HTTPS enforcement**: Force secure connections

---

## 9. Documentation & Examples

### 9.1 API Documentation

- [ ] **Complete API reference**: Document all public APIs
- [ ] **TypeScript JSDoc**: Inline documentation for all types
- [ ] **Interactive examples**: Runnable code snippets
- [ ] **Migration guides**: From Electron, Tauri, React Native

### 9.2 Guides & Tutorials

- [ ] **Getting started guide**: Step-by-step for each platform
- [ ] **Architecture guide**: How Craft works internally
- [ ] **Best practices**: Performance, security, UX
- [ ] **Troubleshooting guide**: Common issues and solutions

### 9.3 Example Applications

- [ ] **Complete examples** (expand `examples/` directory):
  - [ ] Todo app (cross-platform)
  - [ ] Notes app with sync
  - [ ] File manager
  - [ ] Music player
  - [ ] Chat application
  - [ ] Dashboard with charts
  - [ ] E-commerce app
  - [ ] Social media client

---

## 10. Testing Infrastructure

### 10.1 Unit Testing

- [ ] **Zig tests**: Complete test coverage for core modules
- [ ] **TypeScript tests**: Jest/Vitest tests for TS SDK
- [ ] **Bridge tests**: Test JS-to-native communication

### 10.2 Integration Testing

- [ ] **E2E tests**: Playwright/Cypress for web content
- [ ] **Mobile tests**: Detox for iOS/Android
- [ ] **Desktop tests**: Spectron-like testing

### 10.3 Performance Testing

- [ ] **Benchmark suite** (`benchmark.zig`):
  - [ ] Startup time benchmarks
  - [ ] Memory usage benchmarks
  - [ ] Rendering benchmarks
  - [ ] Bridge latency benchmarks

- [ ] **Regression testing**: Automated performance regression detection

### 10.4 Accessibility Testing

- [ ] **Complete accessibility implementation** (`accessibility.zig`):
  - [ ] WCAG 2.1 AAA compliance (69 tests defined)
  - [ ] Screen reader testing
  - [ ] Keyboard navigation testing
  - [ ] Color contrast validation

---

## Priority Matrix

### P0 - Critical (Blocks core functionality) ✅ ALL COMPLETED
1. ~~Implement actual Zig-to-iOS bridge (mobile.zig)~~ ✅ DONE - Full permission system with status checks, haptics, webview
2. ~~Implement actual Zig-to-Android bridge (mobile.zig)~~ ✅ DONE - JNI webview, permissions, toast, vibration
3. ~~Complete memory management for native UI components~~ ✅ DONE - Already implemented in memory.zig
4. ~~Unified JS bridge API across all platforms~~ ✅ DONE - TypeScript API modules created

### P1 - High (Major feature gaps) ✅ ALL COMPLETED
1. ~~Complete iOS Swift template features~~ ✅ DONE - ARKit, Vision/CoreML, HealthKit, Background tasks, Watch connectivity all implemented
2. ~~Complete Android Kotlin template features~~ ✅ DONE - Full CraftBridge with biometrics, camera, notifications; Material Design 3 dynamic colors
3. ~~Hot reload for mobile platforms~~ ✅ DONE - Full WebSocket server with client management
4. ~~DevTools implementation~~ ✅ DONE - CDP, Console, Timeline inspectors added
5. ~~Packaging for all platforms~~ ✅ DONE - DEB, RPM, AppImage implementations in package.ts

### P2 - Medium (Important improvements) ✅ ALL COMPLETED
1. ~~React/Vue/Svelte bindings~~ ✅ DONE - Already implemented with hooks/composables
2. ~~File system and database APIs~~ ✅ DONE - New modules: fs.ts, db.ts, http.ts, crypto.ts, process.ts
3. ~~Plugin security enforcement~~ ✅ DONE - Comprehensive sandboxing in plugin_security.zig
4. ~~Performance optimizations~~ ✅ DONE - GPU backend detection, memory pools
5. Documentation - **Pending**

### P3 - Low (Nice to have)
1. Additional example apps
2. CI/CD templates
3. Advanced native features (CarPlay, widgets, etc.)
4. Framework-specific optimizations

---

## Implementation Notes

### Architecture Decisions

1. **Bridge Communication**: Use JSON for simple messages, binary protocol for large data
2. **Platform Abstraction**: Keep platform-specific code isolated in separate modules
3. **API Design**: Follow web standards where possible (fetch, FileSystem API, etc.)
4. **Type Safety**: Generate TypeScript types from Zig definitions

### Technical Debt - SIGNIFICANTLY REDUCED

1. ~~**Stub implementations**: Many functions in `mobile.zig`, `system.zig` return placeholder values~~ ✅ FIXED
   - mobile.zig: Full iOS permission system with status checks implemented
   - system.zig: macOS clipboard, notifications, file dialogs fully implemented
   - hotreload.zig: WebSocket server fully implemented

2. ~~**Memory leaks**: Native UI components need proper cleanup~~ ✅ ADDRESSED
   - memory.zig already has comprehensive MemoryPool, TempAllocator, TrackingAllocator

3. **Error handling**: Many functions silently ignore errors - **Partially improved**
4. **Test coverage**: Limited automated testing - **Pending**

### Dependencies to Consider

1. **iOS**: Consider using Swift Package Manager for dependencies
2. **Android**: Consider Kotlin Multiplatform for shared code
3. **Desktop**: Consider using system WebView vs bundled (trade-offs)
4. **Build**: Consider using Zig's package manager when stable

---

*Last updated: November 2025*
*Based on codebase analysis of Craft framework*
