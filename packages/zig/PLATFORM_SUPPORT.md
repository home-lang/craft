# Craft Platform Support

This document describes the platform support and native API usage in Craft.

## Supported Platforms

| Platform | Status | Min Version | Architecture |
|----------|--------|-------------|--------------|
| macOS | ✅ Full | 11.0 (Big Sur) | x86_64, arm64 |
| Windows | ✅ Full | 10 (1903) | x86_64 |
| Linux | ✅ Full | Kernel 5.4+ | x86_64 |
| iOS | 🚧 Partial | 14.0 | arm64 |
| Android | 🚧 Partial | API 26 (8.0) | arm64-v8a, armeabi-v7a |

## Feature Support Matrix

### Window Management

| Feature | macOS | Windows | Linux | iOS | Android |
|---------|-------|---------|-------|-----|---------|
| Create/Destroy | ✅ | ✅ | ✅ | ✅ | ✅ |
| Show/Hide | ✅ | ✅ | ✅ | ✅ | ✅ |
| Minimize/Maximize | ✅ | ✅ | ✅ | ❌ | ❌ |
| Fullscreen | ✅ | ✅ | ✅ | ✅ | ✅ |
| Resize | ✅ | ✅ | ✅ | ❌ | ❌ |
| Always on Top | ✅ | ✅ | ✅ | ❌ | ❌ |
| Vibrancy/Blur | ✅ | ✅ | ⚠️ | ✅ | ✅ |
| Transparency | ✅ | ✅ | ✅ | ✅ | ✅ |

### Dialogs

| Feature | macOS | Windows | Linux | iOS | Android |
|---------|-------|---------|-------|-----|---------|
| File Open | ✅ NSOpenPanel | ✅ IFileOpenDialog | ✅ zenity | ✅ UIDocumentPicker | ✅ Intent |
| File Save | ✅ NSSavePanel | ✅ IFileSaveDialog | ✅ zenity | ✅ UIDocumentPicker | ✅ Intent |
| Directory | ✅ NSOpenPanel | ✅ SHBrowseForFolder | ✅ zenity | ⚠️ | ⚠️ |
| Message Box | ✅ NSAlert | ✅ MessageBox | ✅ zenity | ✅ UIAlertController | ✅ AlertDialog |
| Color Picker | ✅ NSColorPanel | ✅ ChooseColor | ✅ zenity | ⚠️ | ⚠️ |
| Font Picker | ✅ NSFontPanel | ✅ ChooseFont | ✅ zenity | ⚠️ | ⚠️ |

### Notifications

| Feature | macOS | Windows | Linux | iOS | Android |
|---------|-------|---------|-------|-----|---------|
| Show | ✅ UNUserNotification | ✅ WinRT Toast | ✅ libnotify | ✅ UNNotification | ✅ NotificationManager |
| Schedule | ✅ | ✅ | ⚠️ | ✅ | ✅ |
| Actions | ✅ | ✅ | ⚠️ | ✅ | ✅ |
| Badge | ✅ | ⚠️ | ❌ | ✅ | ✅ |
| Categories | ✅ | ⚠️ | ❌ | ✅ | ✅ |

### Audio

| Feature | macOS | Windows | Linux | iOS | Android |
|---------|-------|---------|-------|-----|---------|
| Playback | ✅ AVAudioPlayer | ✅ winmm | ✅ paplay/canberra | ✅ AVAudioPlayer | ✅ MediaPlayer |
| Recording | ✅ AVAudioRecorder | ⚠️ | ⚠️ | ✅ AVAudioRecorder | ✅ MediaRecorder |
| System Sounds | ✅ | ✅ | ✅ | ✅ | ✅ |
| Haptic | ✅ NSHapticFeedback | ⚠️ | ❌ | ✅ UIFeedbackGenerator | ✅ Vibrator |

### Camera

| Feature | macOS | Windows | Linux | iOS | Android |
|---------|-------|---------|-------|-----|---------|
| Capture | ✅ AVCaptureSession | ⚠️ MediaFoundation | ⚠️ V4L2 | ✅ AVCaptureSession | ✅ CameraX |
| Photo | ✅ | ⚠️ | ⚠️ | ✅ | ✅ |
| Video | ✅ | ⚠️ | ⚠️ | ✅ | ✅ |
| Barcode | ✅ AVMetadataObject | ⚠️ | ⚠️ | ✅ | ✅ ML Kit |

### Clipboard

| Feature | macOS | Windows | Linux | iOS | Android |
|---------|-------|---------|-------|-----|---------|
| Text | ✅ NSPasteboard | ✅ Clipboard API | ✅ xclip/wl-copy | ✅ UIPasteboard | ✅ ClipboardManager |
| HTML | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| Image | ✅ | ✅ | ✅ | ✅ | ✅ |
| Files | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |

### System Tray

| Feature | macOS | Windows | Linux | iOS | Android |
|---------|-------|---------|-------|-----|---------|
| Icon | ✅ NSStatusItem | ✅ Shell_NotifyIcon | ✅ AppIndicator | ❌ | ❌ |
| Menu | ✅ | ✅ | ✅ | ❌ | ❌ |
| Tooltip | ✅ | ✅ | ✅ | ❌ | ❌ |

### Internationalization

| Feature | macOS | Windows | Linux | iOS | Android |
|---------|-------|---------|-------|-----|---------|
| Locale Detection | ✅ NSLocale | ✅ GetUserDefaultLocaleName | ✅ env vars | ✅ NSLocale | ✅ Locale |
| Date Format | ✅ | ✅ | ✅ | ✅ | ✅ |
| Number Format | ✅ | ✅ | ✅ | ✅ | ✅ |
| RTL Support | ✅ | ✅ | ✅ | ✅ | ✅ |

### Bluetooth

| Feature | macOS | Windows | Linux | iOS | Android |
|---------|-------|---------|-------|-----|---------|
| Discovery | ✅ CoreBluetooth | ⚠️ | ⚠️ bluez | ✅ CoreBluetooth | ✅ BluetoothAdapter |
| Connect | ✅ | ⚠️ | ⚠️ | ✅ | ✅ |
| GATT | ✅ | ⚠️ | ⚠️ | ✅ | ✅ |

### Biometrics

| Feature | macOS | Windows | Linux | iOS | Android |
|---------|-------|---------|-------|-----|---------|
| Touch ID | ✅ LocalAuthentication | ❌ | ❌ | ✅ | ❌ |
| Face ID | ✅ | ❌ | ❌ | ✅ | ✅ |
| Windows Hello | ❌ | ✅ | ❌ | ❌ | ❌ |
| Fingerprint | ✅ | ⚠️ | ❌ | ✅ | ✅ |

## Platform-Specific APIs

### macOS

```zig
const macos = @import("macos.zig");

// Objective-C runtime
const class = macos.getClass("NSApplication");
const result = macos.msgSend0(class, "sharedApplication");

// Selectors
const sel = macos.sel("windowWithContentRect:styleMask:backing:defer:");
```

**Frameworks Used:**
- AppKit (windows, menus, dialogs)
- Foundation (strings, collections)
- AVFoundation (audio, camera)
- CoreBluetooth (Bluetooth)
- UserNotifications (notifications)
- LocalAuthentication (biometrics)

### Windows

```zig
const windows = @import("windows.zig");

// Win32 API
const result = windows.MessageBoxA(null, "Message", "Title", 0);

// COM interfaces
const hr = windows.CoCreateInstance(...);
```

**APIs Used:**
- Win32 (windows, dialogs, clipboard)
- WinRT (notifications, Bluetooth)
- COM (shell, file dialogs)
- comdlg32 (common dialogs)
- winmm (audio)

### Linux

```zig
const linux = @import("linux.zig");

// GTK (optional)
const window = linux.gtk_window_new(0);

// X11/Wayland abstraction
const display = linux.getDisplay();
```

**Libraries Used:**
- GTK3/GTK4 (dialogs, native UI)
- libnotify (notifications)
- bluez/D-Bus (Bluetooth)
- ALSA/PulseAudio (audio)
- V4L2 (camera)
- xclip/wl-clipboard (clipboard)
- zenity (fallback dialogs)

### iOS

```zig
const ios = @import("ios.zig");

// UIKit via Objective-C runtime
const vc = ios.msgSend0(class, "topViewController");
ios.showAlert(title, message);
```

**Frameworks Used:**
- UIKit (UI components)
- AVFoundation (audio, camera)
- CoreBluetooth (Bluetooth)
- UserNotifications (notifications)
- LocalAuthentication (biometrics)

### Android

```zig
const android = @import("android.zig");

// JNI calls
const jni = android.getJNI();
const cls = jni.findClass("android/widget/Toast");
```

**APIs Used:**
- JNI (Java interop)
- Android SDK classes
- CameraX (camera)
- NotificationManager (notifications)
- BluetoothAdapter (Bluetooth)
- BiometricPrompt (biometrics)

## Adding Platform Support

### 1. Create Platform Module

```zig
// src/newplatform.zig
pub fn init() void {
    // Platform initialization
}

pub fn deinit() void {
    // Platform cleanup
}
```

### 2. Update Platform Detection

```zig
// src/platform.zig
const builtin = @import("builtin");

pub const current = switch (builtin.os.tag) {
    .macos => @import("macos.zig"),
    .windows => @import("windows.zig"),
    .linux => @import("linux.zig"),
    .newplatform => @import("newplatform.zig"),
    else => @compileError("Unsupported platform"),
};
```

### 3. Implement Feature Modules

```zig
// Feature implementation
pub fn showNotification(title: []const u8, body: []const u8) !void {
    switch (builtin.os.tag) {
        .macos => try macos.showNotification(title, body),
        .windows => try windows.showNotification(title, body),
        .linux => try linux.showNotification(title, body),
        else => return error.NotSupported,
    }
}
```

## Legend

- ✅ Full support
- ⚠️ Partial support / limitations
- 🚧 In development
- ❌ Not supported / not applicable
