# iOS Integration Guide

This guide explains how to integrate Craft into an iOS project.

## Quick Start

### 1. Build the iOS Library

```bash
# Build for iOS device (arm64)
zig build build-ios

# Build for iOS simulator (arm64 + x86_64)
zig build build-ios-simulator

# Build for both
zig build build-ios-all
```

The output libraries will be in `zig-out/lib/`:
- `libcraft-ios.a` - iOS device library
- `libcraft-ios-simulator-arm64.a` - iOS Simulator (Apple Silicon)
- `libcraft-ios-simulator-x64.a` - iOS Simulator (Intel)

### 2. Xcode Project Setup

1. Create a new iOS project in Xcode (or use existing)
2. Add the Craft library:
   - Drag `libcraft-ios.a` to your project
   - Add to "Link Binary With Libraries" in Build Phases
3. Add required frameworks:
   - UIKit
   - WebKit
   - Foundation

### 3. Integration Code

#### Option A: Objective-C AppDelegate (main.m)

```objc
// main.m
#import <UIKit/UIKit.h>

// Craft iOS exports
extern int craft_ios_init(void);
extern void craft_ios_set_html(const char* html, size_t len);
extern int craft_ios_run(void);
extern void craft_ios_deinit(void);

@interface CraftAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation CraftAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // Initialize Craft
    craft_ios_init();

    // Set your HTML content
    const char* html = "<html><body><h1>Hello from Craft!</h1></body></html>";
    craft_ios_set_html(html, strlen(html));

    // Run the app (this creates the window and webview)
    craft_ios_run();

    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application {
    craft_ios_deinit();
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([CraftAppDelegate class]));
    }
}
```

#### Option B: Swift Integration

```swift
// CraftBridge.swift - Bridge to Craft C functions
import Foundation

@_silgen_name("craft_ios_init")
func craft_ios_init() -> Int32

@_silgen_name("craft_ios_set_html")
func craft_ios_set_html(_ html: UnsafePointer<CChar>, _ len: Int)

@_silgen_name("craft_ios_run")
func craft_ios_run() -> Int32

@_silgen_name("craft_ios_deinit")
func craft_ios_deinit()

@_silgen_name("craft_ios_haptic")
func craft_ios_haptic(_ type: Int32)

@_silgen_name("craft_ios_show_alert")
func craft_ios_show_alert(_ message: UnsafePointer<CChar>, _ len: Int)

// Swift-friendly wrapper
class Craft {
    static func initialize() {
        _ = craft_ios_init()
    }

    static func setHTML(_ html: String) {
        html.withCString { ptr in
            craft_ios_set_html(ptr, html.utf8.count)
        }
    }

    static func run() {
        _ = craft_ios_run()
    }

    static func cleanup() {
        craft_ios_deinit()
    }

    static func haptic(_ type: HapticType) {
        craft_ios_haptic(type.rawValue)
    }

    enum HapticType: Int32 {
        case light = 0
        case medium = 1
        case heavy = 2
        case success = 3
        case warning = 4
        case error = 5
    }
}
```

### 4. Embedding Your Web App

Your web app HTML can call native functions via the Craft JavaScript bridge:

```javascript
// Check if running in Craft
if (window.craft) {
    // Get platform info
    const platform = await craft.invoke('getPlatform');
    // { os: 'ios', version: '17.0', device: 'iPhone', native: true }

    // Show native alert
    await craft.invoke('showAlert', {
        title: 'Hello',
        message: 'This is a native alert!'
    });

    // Trigger haptic feedback
    await craft.invoke('haptic', { type: 'success' });

    // Copy to clipboard
    await craft.invoke('setClipboard', { text: 'Hello!' });

    // Get safe area insets
    const insets = await craft.invoke('getSafeArea');
    // { top: 47, bottom: 34, left: 0, right: 0 }

    // Open URL in Safari
    await craft.invoke('openURL', { url: 'https://example.com' });

    // Share content
    await craft.invoke('share', { text: 'Check this out!' });
}
```

### 5. Build Settings

In your Xcode project's Build Settings:

```
Other Linker Flags: -lcraft-ios
Library Search Paths: $(PROJECT_DIR)/path/to/zig-out/lib
```

### 6. Info.plist

Add required keys for features you use:

```xml
<!-- For camera access -->
<key>NSCameraUsageDescription</key>
<string>This app needs camera access</string>

<!-- For microphone -->
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access</string>

<!-- For photo library -->
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access</string>
```

## Architecture

```
Your Web App (HTML/CSS/JS)
         │
         ▼
┌────────────────────────┐
│    Craft JS Bridge     │
│  window.craft.invoke() │
└────────────────────────┘
         │
         ▼
┌────────────────────────┐
│   Craft iOS Library    │
│  (libcraft-ios.a)      │
│  - WKWebView           │
│  - UIApplicationDelegate│
│  - Native APIs         │
└────────────────────────┘
         │
         ▼
┌────────────────────────┐
│    iOS Frameworks      │
│  UIKit, WebKit, etc.   │
└────────────────────────┘
```

## Available JavaScript Bridge Methods

| Method | Parameters | Description |
|--------|------------|-------------|
| `getPlatform` | none | Get platform info (os, version, device) |
| `showAlert` | `{title, message, buttons}` | Show native alert dialog |
| `haptic` | `{type}` | Trigger haptic feedback |
| `setClipboard` | `{text}` | Copy text to clipboard |
| `getClipboard` | none | Get clipboard contents |
| `getSafeArea` | none | Get safe area insets |
| `getNetworkStatus` | none | Check network connectivity |
| `openURL` | `{url}` | Open URL in Safari |
| `share` | `{text}` | Show share sheet |

## Custom Native Handlers

You can register custom handlers in Zig:

```zig
const ios = @import("craft").ios;

fn handleMyCustomMethod(params: []const u8, bridge: *ios.JSBridge, callback_id: []const u8) void {
    // Process params and respond
    bridge.sendResponse(callback_id, "{ \"result\": \"success\" }") catch {};
}

pub fn main() !void {
    var app = ios.CraftAppDelegate.init(allocator, config);
    try app.registerJSHandler("myCustomMethod", handleMyCustomMethod);
    try app.run();
}
```

Then call from JavaScript:
```javascript
const result = await craft.invoke('myCustomMethod', { foo: 'bar' });
```

## Troubleshooting

### Library not found
- Verify the library path in "Library Search Paths"
- Ensure you built for the correct architecture (device vs simulator)

### Undefined symbols
- Add all required frameworks (UIKit, WebKit, Foundation)
- Link libc in your build settings

### JavaScript bridge not working
- Ensure your HTML is loaded correctly
- Check Safari Web Inspector for console errors
- Verify the craft.invoke() promise is being awaited

## Example Project

See the `examples/web_to_native/` directory for a complete example:
- `main.zig` - Zig entry point with platform detection
- `app.html` - Sample web app with native feature buttons
