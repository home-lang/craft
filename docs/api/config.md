# Configuration

Configure your Craft application using `craft.config.ts`.

## Basic Configuration

```typescript
// craft.config.ts
import type { CraftAppConfig } from '@stacksjs/ts-craft'

const config: CraftAppConfig = {
  name: 'My App',
  version: '1.0.0',
  identifier: 'com.mycompany.myapp',

  window: {
    title: 'My App',
    width: 1200,
    height: 800
  },

  entry: './index.html'
}

export default config
```

## Full Configuration Reference

```typescript
interface CraftAppConfig {
  // Required
  name: string              // Application name
  version: string           // Semantic version (e.g., "1.0.0")
  identifier: string        // Unique identifier (e.g., "com.company.app")

  // Entry point
  entry: string             // Path to HTML entry (default: "./index.html")

  // Window configuration
  window?: WindowConfig

  // Platform-specific configuration
  macos?: MacOSConfig
  windows?: WindowsConfig
  linux?: LinuxConfig
  ios?: IOSConfig
  android?: AndroidConfig
}
```

## Window Configuration

```typescript
interface WindowConfig {
  title?: string            // Window title (default: app name)
  width?: number            // Initial width in pixels (default: 800)
  height?: number           // Initial height in pixels (default: 600)
  minWidth?: number         // Minimum width
  minHeight?: number        // Minimum height
  maxWidth?: number         // Maximum width
  maxHeight?: number        // Maximum height
  resizable?: boolean       // Allow resizing (default: true)
  center?: boolean          // Center on screen (default: true)
  fullscreen?: boolean      // Start in fullscreen
  alwaysOnTop?: boolean     // Keep window on top
  frameless?: boolean       // Remove window frame
  transparent?: boolean     // Transparent background
  vibrancy?: string         // macOS vibrancy effect
}
```

### Example

```typescript
window: {
  title: 'My App',
  width: 1280,
  height: 800,
  minWidth: 800,
  minHeight: 600,
  resizable: true,
  center: true,
  // macOS-specific
  vibrancy: 'sidebar'
}
```

## macOS Configuration

```typescript
interface MacOSConfig {
  bundleId: string          // Bundle identifier
  appName: string           // Display name
  version: string           // CFBundleShortVersionString
  buildNumber: string       // CFBundleVersion
  minimumSystemVersion?: string  // Minimum macOS (default: "12.0")
  category?: string         // App Store category
  copyright?: string        // Copyright notice

  // Code signing
  identity?: string         // Signing identity
  teamId?: string           // Apple Team ID

  // Features
  sandbox?: boolean         // Enable sandbox (default: true)
  hardened?: boolean        // Hardened runtime (default: true)

  // Entitlements
  entitlements?: {
    'com.apple.security.network.client'?: boolean
    'com.apple.security.network.server'?: boolean
    'com.apple.security.files.user-selected.read-only'?: boolean
    'com.apple.security.files.user-selected.read-write'?: boolean
    'com.apple.security.files.downloads.read-only'?: boolean
    'com.apple.security.files.downloads.read-write'?: boolean
    'com.apple.security.device.camera'?: boolean
    'com.apple.security.device.microphone'?: boolean
    'com.apple.security.personal-information.location'?: boolean
    // ... more entitlements
  }

  // Info.plist additions
  infoPlist?: Record<string, any>

  // URL schemes
  urlSchemes?: string[]

  // File associations
  fileAssociations?: FileAssociation[]
}
```

### Example

```typescript
macos: {
  bundleId: 'com.mycompany.myapp',
  appName: 'My App',
  version: '1.0.0',
  buildNumber: '1',
  minimumSystemVersion: '12.0',
  category: 'public.app-category.productivity',
  copyright: '© 2024 My Company',

  sandbox: true,
  hardened: true,

  entitlements: {
    'com.apple.security.network.client': true,
    'com.apple.security.files.user-selected.read-write': true
  },

  infoPlist: {
    NSCameraUsageDescription: 'This app uses the camera for video calls',
    NSMicrophoneUsageDescription: 'This app uses the microphone for voice chat'
  },

  urlSchemes: ['myapp'],

  fileAssociations: [
    {
      ext: 'myapp',
      name: 'My App Document',
      role: 'Editor',
      icon: 'Document.icns'
    }
  ]
}
```

## Windows Configuration

```typescript
interface WindowsConfig {
  appId: string             // Application ID
  publisher: string         // Publisher name (for signing)
  displayName: string       // Display name
  version: string           // Version (must be 4 parts: 1.0.0.0)
  minWindowsVersion?: string // Minimum Windows version

  // Capabilities
  capabilities?: string[]   // UWP capabilities

  // Shortcuts
  createDesktopShortcut?: boolean
  createStartMenuShortcut?: boolean

  // File associations
  fileAssociations?: FileAssociation[]

  // URL protocol
  protocols?: string[]
}
```

### Example

```typescript
windows: {
  appId: 'MyApp',
  publisher: 'CN=My Company',
  displayName: 'My App',
  version: '1.0.0.0',
  minWindowsVersion: '10.0.17763.0',

  capabilities: [
    'internetClient',
    'videosLibrary',
    'musicLibrary'
  ],

  createDesktopShortcut: true,
  createStartMenuShortcut: true,

  protocols: ['myapp'],

  fileAssociations: [
    {
      ext: '.myapp',
      name: 'My App Document',
      icon: 'document.ico'
    }
  ]
}
```

## Linux Configuration

```typescript
interface LinuxConfig {
  name: string              // Application name
  category?: string         // Desktop category
  icon?: string             // Path to icon
  mimeTypes?: string[]      // MIME types to handle

  // Desktop file
  desktopFile?: {
    Name: string
    Comment?: string
    Keywords?: string
    StartupNotify?: boolean
    Terminal?: boolean
  }
}
```

### Example

```typescript
linux: {
  name: 'myapp',
  category: 'Utility',
  icon: 'assets/icon.png',
  mimeTypes: ['application/x-myapp'],

  desktopFile: {
    Name: 'My App',
    Comment: 'A cross-platform application',
    Keywords: 'app;utility;',
    StartupNotify: true
  }
}
```

## iOS Configuration

```typescript
interface IOSConfig {
  bundleId: string          // Bundle identifier
  appName: string           // Display name
  version: string           // CFBundleShortVersionString
  buildNumber: string       // CFBundleVersion
  minimumVersion?: string   // Minimum iOS version (default: "15.0")

  // Team & signing
  teamId?: string           // Apple Team ID
  provisioningProfile?: string

  // Capabilities
  capabilities?: string[]

  // Permissions (Info.plist)
  permissions?: {
    camera?: string         // NSCameraUsageDescription
    microphone?: string     // NSMicrophoneUsageDescription
    photoLibrary?: string   // NSPhotoLibraryUsageDescription
    location?: string       // NSLocationWhenInUseUsageDescription
    contacts?: string       // NSContactsUsageDescription
    calendar?: string       // NSCalendarsUsageDescription
    faceId?: string         // NSFaceIDUsageDescription
    // ... more permissions
  }

  // URL schemes
  urlSchemes?: string[]

  // Orientation
  supportedOrientations?: ('portrait' | 'landscapeLeft' | 'landscapeRight' | 'portraitUpsideDown')[]
}
```

### Example

```typescript
ios: {
  bundleId: 'com.mycompany.myapp',
  appName: 'My App',
  version: '1.0.0',
  buildNumber: '1',
  minimumVersion: '15.0',

  teamId: 'ABCD1234',

  capabilities: [
    'push-notifications',
    'sign-in-with-apple',
    'healthkit'
  ],

  permissions: {
    camera: 'Take photos and record video',
    microphone: 'Record audio for voice messages',
    photoLibrary: 'Save and select photos',
    location: 'Show your location on the map',
    faceId: 'Authenticate securely'
  },

  urlSchemes: ['myapp'],

  supportedOrientations: ['portrait', 'landscapeLeft', 'landscapeRight']
}
```

## Android Configuration

```typescript
interface AndroidConfig {
  packageName: string       // Package name
  appName: string           // Display name
  versionCode: number       // Integer version code
  versionName: string       // Version name string
  minSdkVersion?: number    // Minimum SDK (default: 24)
  targetSdkVersion?: number // Target SDK (default: 34)

  // Permissions
  permissions?: string[]

  // Features
  features?: string[]

  // Theme
  theme?: {
    primaryColor?: string
    accentColor?: string
    statusBarColor?: string
    navigationBarColor?: string
  }

  // Signing
  signing?: {
    keystore?: string
    keystorePassword?: string
    keyAlias?: string
    keyPassword?: string
  }
}
```

### Example

```typescript
android: {
  packageName: 'com.mycompany.myapp',
  appName: 'My App',
  versionCode: 1,
  versionName: '1.0.0',
  minSdkVersion: 24,
  targetSdkVersion: 34,

  permissions: [
    'android.permission.INTERNET',
    'android.permission.CAMERA',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.READ_EXTERNAL_STORAGE'
  ],

  features: [
    'android.hardware.camera',
    'android.hardware.location.gps'
  ],

  theme: {
    primaryColor: '#007AFF',
    accentColor: '#FF9500',
    statusBarColor: '#000000',
    navigationBarColor: '#ffffff'
  }
}
```

## Environment Variables

Access environment variables in config:

```typescript
const config: CraftAppConfig = {
  name: 'My App',
  version: process.env.APP_VERSION || '1.0.0',

  macos: {
    bundleId: process.env.BUNDLE_ID || 'com.mycompany.myapp',
    teamId: process.env.APPLE_TEAM_ID
  }
}
```

## Multiple Configurations

Create environment-specific configs:

```typescript
// craft.config.ts
const baseConfig = {
  name: 'My App',
  window: { width: 1200, height: 800 }
}

const devConfig = {
  ...baseConfig,
  // Development overrides
}

const prodConfig = {
  ...baseConfig,
  // Production overrides
}

export default process.env.NODE_ENV === 'production' ? prodConfig : devConfig
```
