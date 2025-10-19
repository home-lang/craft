# Zyte Production Deployment Guide

## Table of Contents

1. [Building for Production](#building-for-production)
2. [Platform-Specific Guides](#platform-specific-guides)
3. [Code Signing](#code-signing)
4. [Distribution](#distribution)
5. [CI/CD Integration](#cicd-integration)
6. [Best Practices](#best-practices)

---

## Building for Production

### 1. Build Modes

```bash
# Development build (with debug symbols)
zig build

# Release build (optimized, no debug info)
zig build -Doptimize=ReleaseFast

# Release with safety checks
zig build -Doptimize=ReleaseSafe

# Smallest binary size
zig build -Doptimize=ReleaseSmall
```

### 2. Configuration

Create a production `zyte.toml`:

```toml
[app]
hot_reload = false
system_tray = false
log_level = "warn"
log_file = "app.log"

[window]
title = "My Production App"
width = 1200
height = 800
dev_tools = false

[webview]
dev_tools = false
user_agent = "MyApp/1.0"
```

### 3. Environment Variables

```bash
# Set production mode
export ZYTE_ENV=production

# Disable developer features
export ZYTE_DEV_MODE=false

# Set log level
export ZYTE_LOG_LEVEL=warn
```

---

## Platform-Specific Guides

### macOS Deployment

#### 1. Create App Bundle

```bash
# Build the app
zig build -Doptimize=ReleaseFast

# Create app structure
mkdir -p MyApp.app/Contents/MacOS
mkdir -p MyApp.app/Contents/Resources

# Copy binary
cp zig-out/bin/my-app MyApp.app/Contents/MacOS/

# Create Info.plist
cat > MyApp.app/Contents/Info.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>my-app</string>
  <key>CFBundleIdentifier</key>
  <string>com.mycompany.myapp</string>
  <key>CFBundleName</key>
  <string>My App</string>
  <key>CFBundleVersion</key>
  <string>1.0.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.15</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST
```

#### 2. Code Signing

```bash
# Sign the app
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name" \
  MyApp.app

# Verify signature
codesign --verify --deep --strict --verbose=2 MyApp.app
```

#### 3. Notarization

```bash
# Create a ZIP for notarization
ditto -c -k --keepParent MyApp.app MyApp.zip

# Submit for notarization
xcrun notarytool submit MyApp.zip \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "app-specific-password" \
  --wait

# Staple the ticket
xcrun stapler staple MyApp.app
```

#### 4. Create DMG

```bash
# Create DMG
hdiutil create -volname "My App" \
  -srcfolder MyApp.app \
  -ov -format UDZO \
  MyApp.dmg
```

### Linux Deployment

#### 1. Create AppImage

```bash
# Build
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-gnu

# Create AppDir structure
mkdir -p MyApp.AppDir/usr/bin
mkdir -p MyApp.AppDir/usr/share/applications
mkdir -p MyApp.AppDir/usr/share/icons/hicolor/256x256/apps

# Copy files
cp zig-out/bin/my-app MyApp.AppDir/usr/bin/

# Create desktop file
cat > MyApp.AppDir/usr/share/applications/myapp.desktop << 'DESKTOP'
[Desktop Entry]
Name=My App
Exec=my-app
Icon=myapp
Type=Application
Categories=Utility;
DESKTOP

# Create AppImage
appimagetool MyApp.AppDir MyApp-x86_64.AppImage
```

#### 2. Create .deb Package

```bash
# Create package structure
mkdir -p myapp_1.0-1_amd64/DEBIAN
mkdir -p myapp_1.0-1_amd64/usr/bin
mkdir -p myapp_1.0-1_amd64/usr/share/applications

# Create control file
cat > myapp_1.0-1_amd64/DEBIAN/control << 'CONTROL'
Package: myapp
Version: 1.0-1
Architecture: amd64
Maintainer: Your Name <your@email.com>
Description: My App
 My application description
CONTROL

# Copy binary
cp zig-out/bin/my-app myapp_1.0-1_amd64/usr/bin/

# Build package
dpkg-deb --build myapp_1.0-1_amd64
```

### Windows Deployment

#### 1. Build for Windows

```bash
# Cross-compile from macOS/Linux
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows
```

#### 2. Create Installer with NSIS

```nsis
; MyApp.nsi
!define APP_NAME "My App"
!define COMP_NAME "My Company"
!define VERSION "1.0.0"
!define INSTALL_DIR "$PROGRAMFILES64\${APP_NAME}"

Name "${APP_NAME}"
OutFile "MyApp-Setup.exe"
InstallDir "${INSTALL_DIR}"

Section "MainSection" SEC01
  SetOutPath "$INSTDIR"
  File "zig-out\bin\my-app.exe"
  
  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\my-app.exe"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}.lnk" "$INSTDIR\my-app.exe"
SectionEnd
```

---

## Code Signing

### macOS

```bash
# List available certificates
security find-identity -v -p codesigning

# Sign with entitlements
codesign --entitlements entitlements.plist \
  --options runtime \
  --sign "Developer ID Application: Your Name" \
  MyApp.app
```

Example `entitlements.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.cs.allow-jit</key>
  <true/>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
  <true/>
  <key>com.apple.security.cs.disable-library-validation</key>
  <true/>
</dict>
</plist>
```

### Windows

```bash
# Sign with signtool
signtool sign /f certificate.pfx \
  /p password \
  /t http://timestamp.digicert.com \
  my-app.exe
```

---

## Distribution

### App Store (macOS)

1. Create app-specific build
2. Sign with Distribution certificate
3. Package for App Store
4. Upload with Transporter

### Microsoft Store (Windows)

1. Create MSIX package
2. Sign with Windows certificate
3. Upload to Partner Center

### Direct Download

```bash
# Create checksums
shasum -a 256 MyApp.dmg > MyApp.dmg.sha256
shasum -a 256 MyApp-Setup.exe > MyApp-Setup.exe.sha256
```

---

## CI/CD Integration

### GitHub Actions

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Zig
        run: |
          brew install zig
      
      - name: Build
        run: zig build -Doptimize=ReleaseFast
      
      - name: Create DMG
        run: |
          # DMG creation steps
      
      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: myapp-macos
          path: MyApp.dmg

  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Zig
        run: |
          # Install Zig on Linux
      
      - name: Build
        run: zig build -Doptimize=ReleaseFast
      
      - name: Create AppImage
        run: |
          # AppImage creation steps
      
      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: myapp-linux
          path: MyApp-x86_64.AppImage
```

---

## Best Practices

### 1. Security

- ✅ Always use code signing in production
- ✅ Disable dev tools in production builds
- ✅ Use HTTPS for all network requests
- ✅ Validate all user inputs
- ✅ Keep dependencies updated

### 2. Performance

- ✅ Use `ReleaseFast` for maximum performance
- ✅ Profile your application before release
- ✅ Minimize binary size with `ReleaseSmall` if needed
- ✅ Use arena allocators for bulk operations
- ✅ Enable memory tracking in dev mode only

### 3. User Experience

- ✅ Provide clear error messages
- ✅ Include crash reporting
- ✅ Add auto-update mechanism
- ✅ Test on multiple OS versions
- ✅ Provide uninstall instructions

### 4. Monitoring

```zig
// Add telemetry (opt-in)
const telemetry = @import("telemetry.zig");

pub fn main() !void {
    if (user_opted_in) {
        try telemetry.init();
        try telemetry.trackEvent("app_started");
    }
}
```

### 5. Crash Reporting

```zig
// Enable crash reporter
const crash_reporter = @import("crash_reporter.zig");

pub fn main() !void {
    crash_reporter.enable();
    defer crash_reporter.flush();
    
    // Your app code
}
```

---

## Troubleshooting

### macOS: "App is damaged"

```bash
# Remove quarantine flag
xattr -cr MyApp.app
```

### Linux: Missing dependencies

```bash
# Check dependencies
ldd my-app

# Install GTK dependencies
sudo apt install libgtk-3-0 libwebkit2gtk-4.0-37
```

### Windows: DLL not found

```bash
# Include required DLLs in installer
# Or use static linking
```

---

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Microsoft Partner Center](https://partner.microsoft.com/)
- [AppImage Documentation](https://appimage.org/)
- [Zig Build System](https://ziglang.org/documentation/master/#Build-System)

---

**Ready to deploy? Check our [examples](../examples) for reference implementations!**
