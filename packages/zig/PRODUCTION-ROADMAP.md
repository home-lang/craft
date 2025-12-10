# Craft Framework - Production Roadmap

## Goal: Web App → Desktop + iOS Mobile

This roadmap outlines the steps to make Craft production-ready for converting web applications into native desktop and iOS mobile apps.

---

## Current State Assessment

| Platform | Readiness | Effort Needed |
|----------|-----------|---------------|
| **macOS Desktop** | 95% | Minor fixes |
| **Linux Desktop** | 70% | Feature parity |
| **Windows Desktop** | 70% | Feature parity |
| **iOS Mobile** | 20% | Significant |
| **Android Mobile** | 5% | Major |

---

## Phase 1: Desktop Stabilization (Week 1)

### 1.1 Fix WindowBuilder API Inconsistencies
- [ ] Standardize field names (`resizable` vs `is_resizable`)
- [ ] Ensure all options work correctly

### 1.2 Verify Core Functionality
- [ ] Window creation and lifecycle
- [ ] JavaScript bridge communication
- [ ] Native dialogs (file open/save, alerts)
- [ ] Menu bar integration
- [ ] System tray

### 1.3 Test Desktop Platforms
- [ ] macOS: Full test on Apple Silicon + Intel
- [ ] Linux: Test on Ubuntu 22.04+
- [ ] Windows: Test on Windows 10/11

---

## Phase 2: iOS Core Implementation (Weeks 2-4)

### 2.1 iOS App Structure
- [ ] Implement `CraftAppDelegate` (UIApplicationDelegate)
- [ ] Implement `CraftViewController` (UIViewController)
- [ ] Handle app lifecycle (foreground/background/terminate)
- [ ] Status bar configuration
- [ ] Screen orientation handling

### 2.2 WKWebView Integration
- [ ] Create and configure WKWebView
- [ ] Load HTML content (bundled or URL)
- [ ] Handle navigation events
- [ ] Configure preferences (JavaScript, media playback)

### 2.3 JavaScript Bridge (iOS)
- [ ] Implement `WKScriptMessageHandler` for JS→Native
- [ ] Implement `evaluateJavaScript` for Native→JS
- [ ] Bridge native APIs:
  - Clipboard
  - Haptic feedback
  - Device info
  - Safe area insets
  - Keyboard handling

### 2.4 iOS Build System
- [ ] Create Xcode project template
- [ ] Configure Info.plist
- [ ] Add required capabilities
- [ ] Set up code signing (development)
- [ ] Create build scripts for CI

---

## Phase 3: iOS Native Features (Weeks 5-6)

### 3.1 Permissions
- [ ] Camera access
- [ ] Microphone access
- [ ] Photo library
- [ ] Location (if needed)
- [ ] Notifications

### 3.2 Native Dialogs
- [ ] Alert dialogs
- [ ] Action sheets
- [ ] Share sheet
- [ ] Document picker

### 3.3 Device Features
- [ ] Safe area handling
- [ ] Dark mode detection
- [ ] Device orientation
- [ ] Keyboard avoidance

---

## Phase 4: Production Polish (Week 7)

### 4.1 App Store Preparation
- [ ] App icon generation (all sizes)
- [ ] Launch screen/storyboard
- [ ] Privacy descriptions (Info.plist)
- [ ] App Store screenshots

### 4.2 Performance
- [ ] Optimize WebView loading
- [ ] Memory management
- [ ] Background task handling

### 4.3 Testing
- [ ] Unit tests for native bridge
- [ ] UI tests for critical flows
- [ ] Device testing matrix (iPhone SE → iPhone 15 Pro Max)

---

## Architecture: How It Works

```
┌─────────────────────────────────────────────────────┐
│                    Your Web App                      │
│              (HTML + CSS + JavaScript)               │
└─────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│                   Craft Framework                    │
│  ┌─────────────────────────────────────────────────┐│
│  │              JavaScript Bridge                  ││
│  │   window.craft.invoke('methodName', args)       ││
│  └─────────────────────────────────────────────────┘│
│                          │                          │
│     ┌────────────────────┼────────────────────┐     │
│     ▼                    ▼                    ▼     │
│  ┌──────┐           ┌─────────┐          ┌──────┐  │
│  │macOS │           │   iOS   │          │Linux │  │
│  │Window│           │ UIKit + │          │GTK4 +│  │
│  │+WebKit           │WKWebView│          │WebKit│  │
│  └──────┘           └─────────┘          └──────┘  │
└─────────────────────────────────────────────────────┘
```

---

## API for Web App Developers

### JavaScript Side (Your Web App)

```javascript
// Check if running in Craft
if (window.craft) {
    // Get platform info
    const platform = await craft.invoke('getPlatform');
    // → { os: 'ios', version: '17.0', device: 'iPhone' }

    // Show native dialog
    await craft.invoke('showAlert', {
        title: 'Hello',
        message: 'Welcome to the app!',
        buttons: ['OK']
    });

    // Copy to clipboard
    await craft.invoke('setClipboard', { text: 'Hello' });

    // Get safe area insets (iOS)
    const insets = await craft.invoke('getSafeArea');
    // → { top: 47, bottom: 34, left: 0, right: 0 }

    // Trigger haptic feedback (iOS)
    await craft.invoke('haptic', { type: 'success' });
}
```

### Native Side (Craft Framework)

```zig
// Desktop (macOS)
var app = try craft.App.init(allocator);
const window = try app.createWindow(.{
    .title = "My App",
    .width = 1200,
    .height = 800,
    .html = @embedFile("dist/index.html"),
});
try app.run();

// Mobile (iOS) - coming soon
var app = try craft.MobileApp.init(allocator, .{
    .orientation = .all,
    .status_bar_style = .light,
});
try app.loadHTML(@embedFile("dist/index.html"));
try app.run();
```

---

## File Structure for Production App

```
my-app/
├── src/
│   ├── main.zig           # Desktop entry point
│   └── ios_main.zig       # iOS entry point (generated)
├── web/                   # Your web app
│   ├── index.html
│   ├── app.js
│   └── style.css
├── dist/                  # Built web assets
│   └── index.html
├── ios/                   # iOS project (generated)
│   ├── MyApp.xcodeproj
│   ├── MyApp/
│   │   ├── Info.plist
│   │   ├── Assets.xcassets
│   │   └── LaunchScreen.storyboard
│   └── Podfile (optional)
├── build.zig
└── craft.toml             # Configuration
```

---

## Configuration: craft.toml

```toml
[app]
name = "My App"
bundle_id = "com.example.myapp"
version = "1.0.0"

[desktop]
width = 1200
height = 800
resizable = true
frameless = false

[ios]
min_version = "15.0"
orientation = "all"  # portrait, landscape, all
status_bar = "dark"  # dark, light, hidden
capabilities = ["camera", "microphone"]

[build]
web_dir = "dist"
entry = "index.html"
```

---

## Next Steps

1. **Start with desktop** - verify it works for your web app
2. **Test JavaScript bridge** - ensure your web app can call native APIs
3. **Build iOS implementation** - follow Phase 2-3 above
4. **Test on real devices** - iPhone simulator + physical device

---

## Timeline Estimate

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Desktop Polish | 1 week | Production-ready macOS app |
| iOS Core | 3 weeks | Working iOS app with WebView |
| iOS Features | 2 weeks | Full native integration |
| App Store Ready | 1 week | Submission-ready package |
| **Total** | **7 weeks** | Desktop + iOS apps |

---

## Questions to Answer

Before proceeding, please clarify:

1. **What framework is your web app built with?** (React, Vue, vanilla JS, etc.)
2. **What native features do you need?** (Camera, notifications, file access, etc.)
3. **What's your target iOS version?** (iOS 15+, iOS 16+, etc.)
4. **Do you need Android support too?** (Adds 4-6 weeks)
5. **Any specific UI requirements?** (Custom title bar, transparent background, etc.)

---

*Document created: 2025-12-10*
