# Troubleshooting

Solutions to common issues when developing with Craft.

## Installation Issues

### Zig not found

**Symptom:** `craft build` fails with "zig not found"

**Solution:**
```bash
# macOS (Homebrew)
brew install zig

# Linux
# Download from https://ziglang.org/download/

# Verify installation
zig version
# Should output: 0.13.0 or later
```

### Bun not found

**Symptom:** Commands fail with "bun not found"

**Solution:**
```bash
# Install Bun
curl -fsSL https://bun.sh/install | bash

# Verify
bun --version
```

### WebView2 not installed (Windows)

**Symptom:** App crashes on Windows with WebView2 error

**Solution:**
```bash
# WebView2 is included with Windows 11
# For Windows 10, install from:
# https://developer.microsoft.com/microsoft-edge/webview2/
```

## Build Issues

### Build fails with "file not found"

**Symptom:** Build fails saying it can't find `index.html` or entry file

**Solution:**
1. Check `craft.config.ts` has correct `entry` path:
```typescript
entry: './index.html'  // Relative to project root
```

2. Verify the file exists:
```bash
ls -la index.html
```

### TypeScript errors

**Symptom:** TypeScript compilation errors

**Solution:**
```bash
# Make sure ts-craft is installed
bun add ts-craft

# Check tsconfig.json includes the types
{
  "compilerOptions": {
    "types": ["@stacksjs/ts-craft"]
  }
}
```

### Cross-compilation fails

**Symptom:** Building for different platform fails

**Solution:**
```bash
# Ensure Zig is properly installed with all targets
zig targets | grep -i "your-target"

# For Windows from macOS/Linux:
craft build --platform windows

# For macOS from other platforms:
# Requires macOS SDK - use CI/CD or actual Mac
```

## Runtime Issues

### Window doesn't open

**Symptom:** App starts but no window appears

**Solution:**
1. Check for JavaScript errors in console
2. Verify `index.html` loads correctly
3. Check window configuration:
```typescript
window: {
  width: 800,   // Must be > 0
  height: 600,  // Must be > 0
  visible: true // Ensure not hidden
}
```

### Hot reload not working

**Symptom:** Changes don't appear without restart

**Solution:**
1. Ensure dev server is running: `bun run dev`
2. Check for JavaScript errors blocking reload
3. Force refresh: Cmd+R (macOS) or Ctrl+R (Windows/Linux)
4. Restart dev server if needed

### API calls fail

**Symptom:** Craft APIs return errors or undefined

**Solution:**
1. Ensure Craft is initialized:
```typescript
import { isReady } from '@stacksjs/ts-craft'

// Wait for Craft to initialize
await isReady()

// Now use APIs
await fs.readFile('/path')
```

2. Check you're in a Craft environment:
```typescript
if (typeof window.craft === 'undefined') {
  console.error('Not running in Craft')
}
```

### Permission denied

**Symptom:** File or system operations fail with permission error

**Solution:**
1. Check entitlements (macOS):
```typescript
macos: {
  entitlements: {
    'com.apple.security.files.user-selected.read-write': true
  }
}
```

2. Request permissions at runtime (mobile):
```typescript
const granted = await permissions.request('camera')
if (!granted) {
  // Handle denied permission
}
```

## Mobile Issues

### iOS build fails

**Symptom:** `craft build --platform ios` fails

**Solution:**
1. Ensure Xcode is installed with iOS SDK
2. Check signing configuration:
```typescript
ios: {
  bundleId: 'com.yourcompany.app',
  teamId: 'YOUR_TEAM_ID'
}
```

3. Open in Xcode for detailed errors:
```bash
open ios/MyApp.xcworkspace
```

### Android build fails

**Symptom:** `craft build --platform android` fails

**Solution:**
1. Ensure Android SDK is installed
2. Set ANDROID_HOME:
```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

3. Accept SDK licenses:
```bash
$ANDROID_HOME/tools/bin/sdkmanager --licenses
```

### Biometrics not working

**Symptom:** Face ID / Touch ID / fingerprint fails

**Solution:**
1. Check device supports biometrics:
```typescript
const available = await biometrics.isAvailable()
console.log('Biometrics available:', available)
```

2. Add required permission strings:
```typescript
ios: {
  permissions: {
    faceId: 'Authenticate to access your data'
  }
}
```

3. On simulator, enable Face ID enrollment in Features menu

### Safe area not respected

**Symptom:** Content appears under notch or home indicator

**Solution:**
```typescript
import { device } from '@stacksjs/ts-craft'

const { safeAreaInsets } = await device.getScreenInfo()

// Apply safe area padding
document.body.style.paddingTop = `${safeAreaInsets.top}px`
document.body.style.paddingBottom = `${safeAreaInsets.bottom}px`

// Or use CSS
body {
  padding-top: env(safe-area-inset-top);
  padding-bottom: env(safe-area-inset-bottom);
}
```

## Performance Issues

### Slow startup

**Symptom:** App takes long to launch

**Solution:**
1. Minimize initial JavaScript bundle
2. Defer non-critical loading:
```typescript
// Load immediately
import { window } from '@stacksjs/ts-craft'

// Load when needed
const { db } = await import('@stacksjs/ts-craft')
```

3. Use code splitting in bundler

### High memory usage

**Symptom:** App uses excessive memory

**Solution:**
1. Profile with platform tools (Instruments, DevTools)
2. Clear unused data:
```typescript
// Clear event listeners
element.removeEventListener('click', handler)

// Clear intervals
clearInterval(intervalId)
```

3. Use virtual scrolling for long lists

### Slow animations

**Symptom:** Animations are choppy

**Solution:**
1. Use CSS transforms instead of layout properties
2. Add `will-change` hints:
```css
.animated {
  will-change: transform, opacity;
}
```

3. Use native animations on mobile:
```typescript
Animated.timing(value, {
  useNativeDriver: true  // Offload to native
})
```

## Common Error Messages

### "Bridge not initialized"

Craft hasn't finished loading. Wait for ready state:
```typescript
import { isReady } from '@stacksjs/ts-craft'
await isReady()
```

### "Permission denied: camera"

Request permission before using:
```typescript
const granted = await permissions.request('camera')
```

### "Network request failed"

Check network entitlements:
```typescript
macos: {
  entitlements: {
    'com.apple.security.network.client': true
  }
}
```

### "Database locked"

Close previous database connection:
```typescript
await oldDb.close()
const db = await database.open('app.db')
```

## Getting Help

If you're still stuck:

1. **Check documentation**: Review API docs for the feature
2. **Search issues**: https://github.com/aspect/craft/issues
3. **Create issue**: Include:
   - Craft version
   - Platform and OS version
   - Steps to reproduce
   - Error messages / logs
   - Minimal reproduction code
