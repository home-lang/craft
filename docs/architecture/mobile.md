# Mobile Architecture

This document describes Craft's mobile platform architecture for iOS and Android.

## Overview

Craft provides a unified mobile API through `mobile.zig` that abstracts iOS and Android platform differences while exposing platform-specific features when needed.

## Platform Abstraction

```mermaid
graph TB
    subgraph "Unified API"
        APP[MobileApp]
        WV[MobileWebView]
        PERM[Permissions]
        HAP[Haptics]
        DEV[Device Info]
    end

    subgraph "iOS Implementation"
        UI[UIKit]
        WK[WKWebView]
        HF[UIFeedbackGenerator]
        PH[PHPhotoLibrary]
        CL[CLLocationManager]
    end

    subgraph "Android Implementation"
        AA[Android Activity]
        AW[Android WebView]
        VB[Vibrator]
        PM[PermissionManager]
        LM[LocationManager]
    end

    APP --> UI
    APP --> AA

    WV --> WK
    WV --> AW

    HAP --> HF
    HAP --> VB

    PERM --> PH
    PERM --> CL
    PERM --> PM
    PERM --> LM
```

## iOS Architecture

### Application Lifecycle

```mermaid
stateDiagram-v2
    [*] --> NotRunning
    NotRunning --> Inactive: Launch
    Inactive --> Active: Foreground
    Active --> Inactive: Interruption
    Inactive --> Background: Enter Background
    Background --> Inactive: Enter Foreground
    Background --> Suspended: No Activity
    Suspended --> NotRunning: Terminate
    Inactive --> NotRunning: Terminate
```

### WKWebView Integration

```mermaid
graph TB
    subgraph "iOS App"
        VC[UIViewController]
        WK[WKWebView]
        CFG[WKWebViewConfiguration]
        UC[WKUserContentController]
        MH[WKScriptMessageHandler]
    end

    subgraph "Zig Bridge"
        IOS[ios.zig]
        BR[bridge.zig]
        CB[Callbacks]
    end

    VC --> WK
    WK --> CFG
    CFG --> UC
    UC --> MH
    MH --> IOS
    IOS --> BR
    BR --> CB
```

### iOS-Specific Features

```mermaid
graph LR
    subgraph "iOS Features"
        TB[Touch Bar<br/>macOS Catalyst]
        FI[Face ID / Touch ID]
        AP[Apple Pay]
        SI[Sign in with Apple]
        PN[Push Notifications]
        HC[HealthKit]
        WC[WatchKit]
    end
```

## Android Architecture

### Activity Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Created: onCreate
    Created --> Started: onStart
    Started --> Resumed: onResume
    Resumed --> Paused: onPause
    Paused --> Stopped: onStop
    Stopped --> Destroyed: onDestroy
    Destroyed --> [*]

    Paused --> Resumed: onResume
    Stopped --> Started: onRestart
```

### WebView Integration

```mermaid
graph TB
    subgraph "Android App"
        ACT[Activity]
        WV[WebView]
        WS[WebSettings]
        WC[WebViewClient]
        WCC[WebChromeClient]
        JI[JavaScriptInterface]
    end

    subgraph "Zig Bridge"
        AND[android.zig]
        JNI[JNI Helpers]
        BR[bridge.zig]
    end

    ACT --> WV
    WV --> WS
    WV --> WC
    WV --> WCC
    WV --> JI
    JI --> AND
    AND --> JNI
    JNI --> BR
```

### Android-Specific Features

```mermaid
graph LR
    subgraph "Android Features"
        INT[Intents]
        SVC[Services]
        BR[BroadcastReceiver]
        CP[ContentProvider]
        WG[Widgets]
        NFC[NFC]
        BIO[Biometric]
    end
```

## Permission System

### iOS Permissions

```mermaid
graph TB
    subgraph "iOS Permission Flow"
        REQ[Request Permission]
        INFO[Info.plist Entry]
        PROMPT[System Prompt]
        AUTH[Authorization Status]
    end

    subgraph "Permission Types"
        CAM[Camera<br/>NSCameraUsageDescription]
        MIC[Microphone<br/>NSMicrophoneUsageDescription]
        LOC[Location<br/>NSLocationWhenInUseUsageDescription]
        PHO[Photos<br/>NSPhotoLibraryUsageDescription]
        CON[Contacts<br/>NSContactsUsageDescription]
        NOT[Notifications<br/>requestAuthorization]
    end

    REQ --> INFO
    INFO --> PROMPT
    PROMPT --> AUTH

    CAM --> REQ
    MIC --> REQ
    LOC --> REQ
    PHO --> REQ
    CON --> REQ
    NOT --> REQ
```

### Android Permissions

```mermaid
graph TB
    subgraph "Android Permission Flow"
        MAN[Manifest Declaration]
        CHK[Check Permission]
        REQ[Request Permission]
        RES[Handle Result]
    end

    subgraph "Permission Types"
        CAM[CAMERA]
        MIC[RECORD_AUDIO]
        LOC[ACCESS_FINE_LOCATION]
        STO[READ_EXTERNAL_STORAGE]
        CON[READ_CONTACTS]
        NOT[POST_NOTIFICATIONS]
    end

    MAN --> CHK
    CHK --> REQ
    REQ --> RES

    CAM --> MAN
    MIC --> MAN
    LOC --> MAN
    STO --> MAN
    CON --> MAN
    NOT --> MAN
```

## Unified Permission API

```zig
pub const Permission = enum {
    camera,
    microphone,
    location,
    location_always,
    photos,
    contacts,
    notifications,
    calendar,
    reminders,
    bluetooth,
};

pub const PermissionStatus = enum {
    not_determined,
    restricted,
    denied,
    authorized,
    limited,
};

pub fn requestPermission(permission: Permission) !PermissionStatus {
    // Platform-specific implementation
}
```

## Haptic Feedback

```mermaid
graph TB
    subgraph "Haptic Types"
        IMP[Impact<br/>light, medium, heavy]
        NOT[Notification<br/>success, warning, error]
        SEL[Selection]
    end

    subgraph "iOS"
        UIH[UIImpactFeedbackGenerator]
        UIN[UINotificationFeedbackGenerator]
        UIS[UISelectionFeedbackGenerator]
    end

    subgraph "Android"
        VIB[Vibrator]
        VE[VibrationEffect]
    end

    IMP --> UIH
    IMP --> VIB
    NOT --> UIN
    NOT --> VIB
    SEL --> UIS
    SEL --> VIB
```

## Bridge Protocol (Mobile)

### iOS Message Handler

```mermaid
sequenceDiagram
    participant JS as JavaScript
    participant WK as WKWebView
    participant MH as Message Handler
    participant ZIG as Zig Code

    JS->>WK: webkit.messageHandlers.craft.postMessage(msg)
    WK->>MH: userContentController:didReceiveScriptMessage:
    MH->>ZIG: handleMessage(payload)
    ZIG-->>MH: Response
    MH->>WK: evaluateJavaScript("craftHandleResponse(...)")
    WK-->>JS: Promise resolved
```

### Android JavaScript Interface

```mermaid
sequenceDiagram
    participant JS as JavaScript
    participant WV as WebView
    participant JI as @JavascriptInterface
    participant JNI as JNI
    participant ZIG as Zig Code

    JS->>WV: CraftBridge.invoke(method, params)
    WV->>JI: invoke(String, String)
    JI->>JNI: CallStaticVoidMethod
    JNI->>ZIG: handleMessage
    ZIG-->>JNI: Response
    JNI-->>JI: Return
    JI->>WV: webView.evaluateJavascript
    WV-->>JS: Callback executed
```

## Native Object Management

```mermaid
graph TB
    subgraph "NativeObjectManager"
        REG[Register Object]
        GET[Get Object]
        REM[Remove Object]
        CLN[Cleanup All]
    end

    subgraph "Tracked Objects"
        WV[WebViews]
        VC[ViewControllers]
        OBS[Observers]
        TMR[Timers]
    end

    REG --> WV
    REG --> VC
    REG --> OBS
    REG --> TMR

    GET --> WV
    GET --> VC

    REM --> WV
    REM --> VC
    REM --> OBS
    REM --> TMR

    CLN --> WV
    CLN --> VC
    CLN --> OBS
    CLN --> TMR
```

## Build Configuration

### iOS Targets

```mermaid
graph LR
    subgraph "iOS Build Targets"
        DEV[aarch64-ios<br/>Device]
        SIM[aarch64-ios-simulator<br/>M1 Simulator]
        SIMX[x86_64-ios-simulator<br/>Intel Simulator]
    end
```

### Android Targets

```mermaid
graph LR
    subgraph "Android Build Targets"
        ARM64[aarch64-linux-android<br/>arm64-v8a]
        ARM[armv7a-linux-androideabi<br/>armeabi-v7a]
        X64[x86_64-linux-android<br/>x86_64]
        X86[i686-linux-android<br/>x86]
    end
```

## Project Templates

### iOS Template Structure

```
MyApp/
├── MyApp.xcodeproj/
├── MyApp/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── ViewController.swift
│   ├── Info.plist
│   └── Assets.xcassets/
├── Frameworks/
│   └── libcraft.a
└── web/
    └── index.html
```

### Android Template Structure

```
MyApp/
├── app/
│   ├── build.gradle
│   ├── src/main/
│   │   ├── java/com/myapp/
│   │   │   └── MainActivity.java
│   │   ├── jniLibs/
│   │   │   ├── arm64-v8a/
│   │   │   └── x86_64/
│   │   ├── res/
│   │   └── AndroidManifest.xml
│   └── src/main/assets/
│       └── web/
│           └── index.html
├── build.gradle
└── settings.gradle
```

## Further Reading

- [mobile.zig](../../packages/zig/src/mobile.zig) - Mobile implementation
- [PLATFORM_SUPPORT.md](../../packages/zig/PLATFORM_SUPPORT.md) - Platform feature matrix
- [ios_template.zig](../../packages/zig/src/ios_template.zig) - iOS project template
- [android_template.zig](../../packages/zig/src/android_template.zig) - Android project template
