# Craft OTA Updates

Over-the-Air (OTA) updates allow you to push web content updates to your app without going through the App Store or Play Store review process.

## Overview

The Craft OTA system consists of:

1. **Client SDK** - JavaScript API (`craft.ota`) for checking and applying updates
2. **Native Handler** - iOS/Android code for downloading and managing bundles
3. **Update Server** - Server that hosts update manifests and bundles

## How It Works

1. App launches and checks for updates
2. If update available, downloads new bundle in background
3. On next launch (or immediately), new bundle is loaded
4. If update fails, automatic rollback to previous version

## JavaScript API

```typescript
// Check for updates
const update = await craft.ota.checkForUpdate();
if (update.available) {
  console.log(`New version ${update.version} available`);
  console.log(`Size: ${update.downloadSize} bytes`);
}

// Download update (in background)
await craft.ota.downloadUpdate();

// Apply update (restarts app)
await craft.ota.applyUpdate();

// Or apply on next launch
await craft.ota.downloadUpdate({ applyOnRestart: true });

// Get current bundle info
const info = craft.ota.getCurrentBundle();
console.log(`Version: ${info.version}`);
console.log(`Hash: ${info.hash}`);

// Rollback to previous version
await craft.ota.rollback();

// Listen for update events
craft.ota.onProgress((progress) => {
  console.log(`Download: ${progress.percent}%`);
});
```

## Update Manifest Format

The server returns a JSON manifest:

```json
{
  "version": "1.2.0",
  "buildNumber": 42,
  "releaseNotes": "Bug fixes and improvements",
  "mandatory": false,
  "bundleUrl": "https://updates.example.com/bundles/1.2.0.zip",
  "bundleHash": "sha256:abc123...",
  "downloadSize": 1234567,
  "minAppVersion": "1.0.0",
  "targetPlatform": "all",
  "rolloutPercentage": 100,
  "createdAt": "2024-01-15T12:00:00Z"
}
```

## Server Setup

### Self-Hosted

1. Create an update manifest endpoint:
   ```
   GET https://your-server.com/api/updates/check
   Query: platform=ios|android, currentVersion=1.0.0, appVersion=1.0.0
   ```

2. Host bundle files:
   ```
   https://your-server.com/bundles/{version}.zip
   ```

3. Configure in your app:
   ```typescript
   craft.ota.configure({
     updateUrl: 'https://your-server.com/api/updates/check',
     checkOnLaunch: true,
     checkInterval: 3600000, // 1 hour
   });
   ```

### Bundle Structure

The bundle zip should contain:
- `index.html` - Main entry point
- `assets/` - CSS, JS, images
- `manifest.json` - Bundle metadata

## Security Considerations

1. **HTTPS Only** - All update URLs must use HTTPS
2. **Hash Verification** - Bundles are verified using SHA-256
3. **Signature Verification** - Optional RSA signature for bundles
4. **Rollback** - Automatic rollback if bundle fails to load

## Platform Specifics

### iOS
- Bundles stored in Library/Application Support/craft-updates/
- Atomic swap using file system operations
- WKWebView loadFileURL for local bundles

### Android
- Bundles stored in internal storage
- Atomic extraction using temp directories
- WebView loadUrl with file:// protocol

## Limitations

- Only web content (HTML, CSS, JS, assets) can be updated
- Native code changes require App Store/Play Store update
- Bundle size should be reasonable (< 10MB recommended)
- First bundle on fresh install comes from app package

## Error Handling

```typescript
try {
  await craft.ota.downloadUpdate();
} catch (error) {
  if (error.code === 'NETWORK_ERROR') {
    // Retry later
  } else if (error.code === 'HASH_MISMATCH') {
    // Bundle corrupted, retry download
  } else if (error.code === 'INSUFFICIENT_STORAGE') {
    // Prompt user to free space
  }
}
```
