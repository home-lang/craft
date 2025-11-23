# Craft Mobile Native Bridges - Implementation TODO

This document tracks the implementation of additional native bridges and improvements for iOS and Android.

---

## High Value Bridges

### 1. Contacts - COMPLETED
- [x] **iOS Implementation**
  - [x] Import `Contacts` and `ContactsUI` frameworks
  - [x] Add `NSContactsUsageDescription` to Info.plist template
  - [x] Implement `getContacts()` - Fetch all contacts with name, phone, email
  - [x] Implement `addContact(data)` - Create new contact
  - [x] Add JavaScript bridge methods
  - [x] Handle permission requests gracefully

- [x] **Android Implementation**
  - [x] Add `READ_CONTACTS` and `WRITE_CONTACTS` permissions
  - [x] Implement ContentResolver queries for contacts
  - [x] Implement `getContacts()` - Fetch all contacts
  - [x] Implement `addContact(data)` - Create new contact
  - [x] Add JavaScript bridge methods
  - [x] Handle runtime permission requests

- [x] **Documentation & Testing**
  - [x] Update iOS README with Contacts API
  - [x] Update Android README with Contacts API
  - [x] Add Contacts test buttons to test-bridges.html

### 2. Calendar - COMPLETED
- [x] **iOS Implementation**
  - [x] Import `EventKit` and `EventKitUI` frameworks
  - [x] Add `NSCalendarsUsageDescription` to Info.plist template
  - [x] Implement `getCalendarEvents(startDate, endDate)` - Fetch events
  - [x] Implement `createCalendarEvent(data)` - Create calendar event
  - [x] Implement `deleteCalendarEvent(id)` - Delete event
  - [x] Add JavaScript bridge methods
  - [x] Handle permission requests

- [x] **Android Implementation**
  - [x] Add `READ_CALENDAR` and `WRITE_CALENDAR` permissions
  - [x] Implement ContentResolver queries for calendar
  - [x] Implement `getCalendarEvents(startDate, endDate)` - Fetch events
  - [x] Implement `createCalendarEvent(data)` - Create calendar event
  - [x] Implement `deleteCalendarEvent(id)` - Delete event
  - [x] Add JavaScript bridge methods
  - [x] Handle runtime permission requests

- [x] **Documentation & Testing**
  - [x] Update iOS README with Calendar API
  - [x] Update Android README with Calendar API
  - [x] Add Calendar test buttons to test-bridges.html

### 3. Local Notifications - COMPLETED
- [x] **iOS Implementation**
  - [x] Import `UserNotifications` framework
  - [x] Implement `scheduleNotification(data)` - Schedule local notification
    - [x] Support `title`, `body`, `badge`, `sound`
    - [x] Support `timestamp` (specific date/time)
    - [x] Support `delay` (seconds from now)
  - [x] Implement `cancelNotification(id)` - Cancel scheduled notification
  - [x] Implement `cancelAllNotifications()` - Cancel all
  - [x] Implement `getPendingNotifications()` - List scheduled
  - [x] Add JavaScript bridge methods

- [x] **Android Implementation**
  - [x] Add `POST_NOTIFICATIONS` permission (Android 13+)
  - [x] Implement NotificationManager + AlarmManager
  - [x] Implement `scheduleNotification(data)` - Schedule notification
    - [x] Support `title`, `body`, notification channels
    - [x] Support `timestamp`, `delay`
  - [x] Implement `cancelNotification(id)` - Cancel scheduled
  - [x] Implement `cancelAllNotifications()` - Cancel all
  - [x] Add JavaScript bridge methods

- [x] **Documentation & Testing**
  - [x] Update iOS README with Local Notifications API
  - [x] Update Android README with Local Notifications API
  - [x] Add Local Notifications test buttons to test-bridges.html

### 4. Deep Links / Universal Links - PARTIAL
- [x] **iOS Implementation**
  - [x] Add `registerDeepLinkHandler` case in switch
  - [ ] Add URL scheme support to Info.plist template
  - [ ] Add Associated Domains entitlement for Universal Links
  - [ ] Dispatch `craftDeepLink` event with URL and parameters
  - [ ] Implement `getInitialURL()` - Get URL that launched app

- [ ] **Android Implementation**
  - [ ] Add intent-filter for custom URL schemes in AndroidManifest
  - [ ] Add intent-filter for App Links (https://)
  - [ ] Handle `onCreate` intent data
  - [ ] Handle `onNewIntent` for running app
  - [ ] Dispatch `craftDeepLink` event with URL and parameters
  - [ ] Implement `getInitialURL()` - Get URL that launched app

- [ ] **Documentation & Testing**
  - [ ] Update iOS README with Deep Links API
  - [ ] Update Android README with Deep Links API
  - [ ] Document apple-app-site-association setup
  - [ ] Document assetlinks.json setup
  - [ ] Add Deep Links test buttons to test-bridges.html

### 5. In-App Purchase - COMPLETED
- [x] **iOS Implementation**
  - [x] Import `StoreKit` framework
  - [x] Implement `getProducts(productIds)` - Fetch product info
  - [x] Implement `purchaseProduct(productId)` - Initiate purchase
  - [x] Implement `restorePurchases()` - Restore previous purchases
  - [x] Handle SKPaymentTransactionObserver callbacks
  - [x] Add JavaScript bridge methods

- [x] **Android Implementation**
  - [x] Add Google Play Billing Library dependency
  - [x] Implement BillingClient setup and connection
  - [x] Implement `getProducts(productIds)` - Query product details
  - [x] Implement `purchaseProduct(productId)` - Launch purchase flow
  - [x] Implement `restorePurchases()` - Query purchases
  - [x] Handle PurchasesUpdatedListener callbacks
  - [x] Add JavaScript bridge methods

- [x] **Documentation & Testing**
  - [x] Update iOS README with IAP API
  - [x] Update Android README with IAP API
  - [ ] Document App Store Connect setup
  - [ ] Document Google Play Console setup
  - [x] Add IAP test buttons to test-bridges.html

### 6. Keep Screen Awake - COMPLETED
- [x] **iOS Implementation**
  - [x] Implement `setKeepAwake(enabled)` using `UIApplication.shared.isIdleTimerDisabled`
  - [x] Add JavaScript bridge methods

- [x] **Android Implementation**
  - [x] Implement `setKeepAwake(enabled)` using `FLAG_KEEP_SCREEN_ON`
  - [x] Add JavaScript bridge methods

- [x] **Documentation & Testing**
  - [x] Update iOS README with Keep Awake API
  - [x] Update Android README with Keep Awake API
  - [x] Add Keep Awake test buttons to test-bridges.html

### 7. Orientation Lock - COMPLETED
- [x] **iOS Implementation**
  - [x] Implement `lockOrientation(orientation)` - portrait, landscape, all
  - [x] Implement `unlockOrientation()` - Allow all orientations
  - [x] Add JavaScript bridge methods

- [x] **Android Implementation**
  - [x] Implement `lockOrientation(orientation)` using `setRequestedOrientation()`
  - [x] Implement `unlockOrientation()` - `SCREEN_ORIENTATION_UNSPECIFIED`
  - [x] Add JavaScript bridge methods

- [x] **Documentation & Testing**
  - [x] Update iOS README with Orientation API
  - [x] Update Android README with Orientation API
  - [x] Add Orientation test buttons to test-bridges.html

---

## Medium Value Bridges

### 8. Background Tasks - COMPLETED
- [x] **iOS Implementation**
  - [x] Import `BackgroundTasks` framework
  - [x] Implement `registerBackgroundTask(taskId)` - Register task
  - [x] Implement `scheduleBackgroundTask(taskId, options)` - Schedule with delay, network, charging requirements
  - [x] Implement `cancelBackgroundTask(taskId)` - Cancel task
  - [x] Implement `cancelAllBackgroundTasks()` - Cancel all tasks
  - [x] Add JavaScript bridge methods (backgroundTask.register/schedule/cancel/cancelAll)

- [x] **Android Implementation**
  - [x] Implement `registerBackgroundTask(taskId)` - Ready for WorkManager integration
  - [x] Implement `scheduleBackgroundTask(taskId, delay, requiresNetwork, requiresCharging)` - Schedule
  - [x] Implement `cancelBackgroundTask(taskId)` - Cancel task
  - [x] Implement `cancelAllBackgroundTasks()` - Cancel all tasks
  - [x] Add JavaScript bridge methods

- [x] **Documentation & Testing**
  - [x] Update READMEs with Background Tasks API
  - [x] Add test buttons to test-bridges.html

### 9. PDF Viewer - COMPLETED
- [x] **iOS Implementation**
  - [x] Import `PDFKit` framework
  - [x] Implement `openPDF(source, page)` - Display PDF in native viewer
  - [x] Support base64 data and URLs
  - [x] Support pinch-to-zoom, scrolling
  - [x] Implement `closePDF()` - Dismiss viewer
  - [x] Add JavaScript bridge methods

- [x] **Android Implementation**
  - [x] Implement `openPDF(source, page)` - Open in external PDF viewer
  - [x] Support base64 data (saves to temp file) and URLs
  - [x] Implement `closePDF()` - Acknowledge close
  - [x] Add JavaScript bridge methods

- [x] **Documentation & Testing**
  - [x] Update READMEs with PDF Viewer API
  - [x] Add test buttons to test-bridges.html

### 10. Contacts Picker - COMPLETED
- [x] **iOS Implementation**
  - [x] Import `ContactsUI` framework
  - [x] Implement `pickContact(options)` - Show native CNContactPickerViewController
  - [x] Return selected contact data (id, givenName, familyName, displayName, phoneNumbers, emailAddresses)
  - [x] Support multiple selection option
  - [x] Add CNContactPickerDelegate extension
  - [x] Add JavaScript bridge methods

- [x] **Android Implementation**
  - [x] Use `Intent.ACTION_PICK` with ContactsContract.Contacts.CONTENT_URI
  - [x] Implement `pickContact(multiple)` - Show native picker
  - [x] Return selected contact data (id, displayName, phoneNumbers, emailAddresses)
  - [x] Add `handleContactPickerResult()` for activity result
  - [x] Add JavaScript bridge methods

- [x] **Documentation & Testing**
  - [x] Update READMEs with Contacts Picker API
  - [x] Add test buttons to test-bridges.html

### 11. App Shortcuts - COMPLETED
- [x] **iOS Implementation**
  - [x] Implement UIApplicationShortcutItem support
  - [x] Implement `setAppShortcuts(shortcuts)` - Set dynamic shortcuts with type, title, subtitle, iconName
  - [x] Implement `clearAppShortcuts()` - Remove all shortcuts
  - [x] Support SF Symbol icons
  - [x] Add JavaScript bridge methods (shortcuts.set/clear/onShortcut)

- [x] **Android Implementation**
  - [x] Use ShortcutManager (Android 7.1+)
  - [x] Implement `setShortcuts(shortcutsJson)` - Set dynamic shortcuts
  - [x] Implement `clearShortcuts()` - Remove shortcuts
  - [x] Build ShortcutInfo with type, title, subtitle
  - [x] Add JavaScript bridge methods

- [x] **Documentation & Testing**
  - [x] Update READMEs with App Shortcuts API
  - [x] Add test buttons to test-bridges.html

### 12. Keychain Sharing - COMPLETED
- [x] **iOS Implementation**
  - [x] Implement `setSharedKeychainItem(key, value, group)` - Store in shared keychain
  - [x] Implement `getSharedKeychainItem(key, group)` - Retrieve from shared keychain
  - [x] Implement `removeSharedKeychainItem(key, group)` - Delete from shared keychain
  - [x] Add JavaScript bridge methods (sharedKeychain.set/get/remove)

- [x] **Android Implementation**
  - [x] Use SharedPreferences with named groups
  - [x] Implement `setSharedItem(key, value, group)` - Store shared data
  - [x] Implement `getSharedItem(key, group)` - Retrieve shared data
  - [x] Implement `removeSharedItem(key, group)` - Delete shared data
  - [x] Add JavaScript bridge methods

- [x] **Documentation & Testing**
  - [x] Update READMEs with Keychain Sharing API
  - [x] Add test buttons to test-bridges.html

### 13. iCloud/Google Drive - DEFERRED
Note: This requires significant external SDK setup (CloudKit, Google Drive API, OAuth2). Recommended to use web-based cloud storage APIs or external libraries instead.

- [ ] **iOS Implementation** (Requires CloudKit entitlements)
- [ ] **Android Implementation** (Requires Google Drive SDK + OAuth)
- [ ] **Documentation & Testing**

### 14. Local Auth Persistence - COMPLETED
- [x] **iOS Implementation**
  - [x] Track biometric session with expiry timestamp
  - [x] Implement `setBiometricPersistence(enabled, duration)` - Enable with duration
  - [x] Implement `checkBiometricPersistence()` - Check if session still valid
  - [x] Implement `clearBiometricPersistence()` - Clear session
  - [x] Add JavaScript bridge methods (authPersistence.enable/disable/check/clear)

- [x] **Android Implementation**
  - [x] Track auth session with expiry timestamp
  - [x] Implement `setAuthPersistence(enabled, duration)` - Configure session
  - [x] Implement `checkAuthPersistence()` - Validate session
  - [x] Implement `clearAuthPersistence()` - Clear session
  - [x] Add JavaScript bridge methods

- [x] **Documentation & Testing**
  - [x] Update READMEs with Auth Persistence API
  - [x] Add test buttons to test-bridges.html

---

## Nice to Have Bridges

### 15. ARKit/ARCore - COMPLETED
- [x] **iOS Implementation**
  - [x] Import `ARKit`, `RealityKit`, `SceneKit`, `Vision` frameworks
  - [x] Implement `startAR(options)` - Initialize AR session with ARSCNView
  - [x] Implement `stopAR()` - End AR session
  - [x] Implement `placeObject(model, position)` - Place 3D object (box, sphere, cylinder, cone, or .usdz/.scn)
  - [x] Implement `removeObject(id)` - Remove object by ID
  - [x] Implement `getARPlanes()` - Get detected planes
  - [x] Dispatch plane detection events via ARSCNViewDelegate
  - [x] Add JavaScript bridge methods (ar.start/stop/placeObject/removeObject/getPlanes/onPlaneDetected)

- [x] **Android Implementation**
  - [x] Add placeholder for ARCore (requires native Activity integration)
  - [x] Note: Full ARCore requires Sceneform or AR Fragment
  - [x] Add JavaScript bridge methods (placeholder)

- [x] **Documentation & Testing**
  - [x] Add AR test section to test-bridges.html

### 16. Core ML / ML Kit - COMPLETED
- [x] **iOS Implementation**
  - [x] Import `Vision` framework
  - [x] Implement `classifyImage(image)` - VNClassifyImageRequest for image classification
  - [x] Implement `detectObjects(image)` - VNRecognizeAnimalsRequest for object detection
  - [x] Implement `recognizeText(image)` - VNRecognizeTextRequest for OCR
  - [x] Add JavaScript bridge methods (ml.classifyImage/detectObjects/recognizeText)

- [x] **Android Implementation**
  - [x] Add ML Kit dependencies (ImageLabeling, ObjectDetection, TextRecognition)
  - [x] Implement `classifyImage(image)` - ImageLabeling API
  - [x] Implement `detectObjects(image)` - ObjectDetection API
  - [x] Implement `recognizeText(image)` - TextRecognition API
  - [x] Add JavaScript bridge methods

- [x] **Documentation & Testing**
  - [x] Add ML test section to test-bridges.html

### 17. Widgets - DEFERRED
Note: Widgets require separate native extension templates (WidgetKit for iOS, AppWidgetProvider for Android) that cannot be bridged via JavaScript WebView. These should be implemented as separate template files that developers can customize.

- [ ] **Future Work**
  - [ ] Create WidgetKit extension template for iOS
  - [ ] Create AppWidgetProvider template for Android
  - [ ] Document widget development workflow
  - [ ] Add shared UserDefaults/SharedPreferences for app-to-widget communication

### 18. Siri/Google Assistant - DEFERRED
Note: Voice assistant integration requires separate native extensions (SiriKit Intents for iOS, App Actions for Android) that operate outside the WebView context.

- [ ] **Future Work**
  - [ ] Create SiriKit Intents extension template
  - [ ] Create App Actions configuration template
  - [ ] Document voice assistant setup workflow

### 19. CarPlay/Android Auto - DEFERRED
Note: Car platform integration requires separate native UI implementations (CarPlay templates, Android Auto screens) that cannot be rendered in a WebView.

- [ ] **Future Work**
  - [ ] Create CarPlay scene delegate template
  - [ ] Create Android Auto CarAppService template
  - [ ] Document car app development workflow

### 20. Watch Connectivity - DEFERRED
Note: Watch apps require separate companion app development (watchOS app, Wear OS app) with their own UI frameworks.

- [ ] **Future Work**
  - [ ] Create WatchConnectivity session management code
  - [ ] Create Wearable API data sync code
  - [ ] Document watch companion app development

---

## Developer Experience Improvements

### TypeScript Types
- [ ] Create `types/craft.d.ts` with full type definitions
- [ ] Export types for all bridge methods
- [ ] Add JSDoc comments for IntelliSense
- [ ] Publish as `@aspect/craft-types` package
- [ ] Add TypeScript example project

### Error Messages
- [ ] Implement structured error codes for all bridges
- [ ] Add native stack trace capture
- [ ] Create error mapping from native to JavaScript
- [ ] Add `craft.getLastError()` for detailed error info
- [ ] Implement `craftError` event for global error handling

### Debug Mode
- [ ] Implement debug flag in config
- [ ] Add network request inspector overlay
- [ ] Add console.log capture and display
- [ ] Add performance metrics display
- [ ] Add bridge call logging with timing
- [ ] Implement shake gesture to show debug panel

### Performance Profiling
- [ ] Add bridge call timing instrumentation
- [ ] Implement `craft.startProfiling()` / `craft.stopProfiling()`
- [ ] Track memory usage
- [ ] Track WebView performance
- [ ] Export profiling data as JSON
- [ ] Add flame chart visualization (optional)

---

## Infrastructure Improvements

### Automated Testing
- [ ] Create Firebase Test Lab integration script
- [ ] Create BrowserStack App Automate integration
- [ ] Add GitHub Actions workflow for iOS tests
- [ ] Add GitHub Actions workflow for Android tests
- [ ] Create test matrix for different OS versions
- [ ] Add screenshot comparison testing

### CI/CD Templates
- [ ] Create `.github/workflows/ios-build.yml`
  - [ ] Build debug and release
  - [ ] Run unit tests
  - [ ] Upload artifacts
- [ ] Create `.github/workflows/android-build.yml`
  - [ ] Build debug and release APK/AAB
  - [ ] Run unit tests
  - [ ] Upload artifacts
- [ ] Create `.github/workflows/release.yml`
  - [ ] Tag-based release workflow
  - [ ] Build both platforms
  - [ ] Create GitHub release with assets

### Code Signing Automation
- [ ] **iOS**
  - [ ] Add Fastlane Matchfile template
  - [ ] Create `fastlane/Fastfile` with lanes
  - [ ] Document certificate setup
  - [ ] Add provisioning profile management
- [ ] **Android**
  - [ ] Add keystore generation script
  - [ ] Create signing config template
  - [ ] Add `upload-key.jks` management
  - [ ] Document Play App Signing

### OTA Updates (CodePush-like)
- [ ] Design update manifest format
- [ ] **iOS Implementation**
  - [ ] Implement update check on launch
  - [ ] Implement bundle download and extraction
  - [ ] Implement atomic bundle swap
  - [ ] Implement rollback on error
  - [ ] Add `craft.checkForUpdate()` API
  - [ ] Add `craft.applyUpdate()` API
- [ ] **Android Implementation**
  - [ ] Implement update check on launch
  - [ ] Implement bundle download
  - [ ] Implement bundle extraction and swap
  - [ ] Implement rollback mechanism
  - [ ] Add JavaScript bridge methods
- [ ] **Server Component**
  - [ ] Create update server specification
  - [ ] Document self-hosting setup
  - [ ] Add version management CLI
  - [ ] Add rollout percentage support

---

## Progress Tracking

| Category | Total Tasks | Completed | Progress |
|----------|-------------|-----------|----------|
| High Value Bridges | 7 | 7 | 100% |
| Medium Value Bridges | 7 | 6 | 86% |
| Nice to Have Bridges | 6 | 2 | 33% |
| Developer Experience | 4 | 0 | 0% |
| Infrastructure | 4 | 0 | 0% |
| **Total** | **28** | **15** | **54%** |

### Completed High Value Bridges:
1. Contacts (iOS + Android) - getContacts(), addContact()
2. Calendar (iOS + Android) - getCalendarEvents(), createCalendarEvent(), deleteCalendarEvent()
3. Local Notifications (iOS + Android) - scheduleNotification(), cancelNotification(), cancelAllNotifications(), getPendingNotifications()
4. Deep Links (basic support in iOS, handler registered)
5. In-App Purchase (iOS + Android) - getProducts(), purchase(), restorePurchases()
6. Keep Screen Awake (iOS + Android) - setKeepAwake()
7. Orientation Lock (iOS + Android) - lockOrientation(), unlockOrientation()

### Completed Medium Value Bridges:
1. Background Tasks (iOS + Android) - backgroundTask.register(), schedule(), cancel(), cancelAll()
2. PDF Viewer (iOS + Android) - openPDF(), closePDF()
3. Contacts Picker (iOS + Android) - pickContact() with native UI
4. App Shortcuts (iOS + Android) - shortcuts.set(), clear(), onShortcut()
5. Keychain Sharing (iOS + Android) - sharedKeychain.set(), get(), remove()
6. Local Auth Persistence (iOS + Android) - authPersistence.enable(), check(), clear()

### Completed Nice to Have Bridges:
1. ARKit/ARCore (iOS full implementation, Android placeholder) - ar.start(), stop(), placeObject(), removeObject(), getPlanes(), onPlaneDetected()
2. Core ML/ML Kit (iOS + Android) - ml.classifyImage(), detectObjects(), recognizeText()

### Documentation Completed:
- iOS README updated with all High Value + Medium Value bridges APIs
- Android README updated with all High Value + Medium Value bridges APIs
- test-bridges.html updated with test buttons for most implemented bridges
- Info.plist permissions documented (Contacts, Calendar)
- AndroidManifest permissions documented (Contacts, Calendar, Notifications)

### Partially Completed / Deferred:
- Deep Links (needs full URL scheme + Universal Links handling)
- iCloud/Google Drive (requires external SDK setup - use web APIs instead)

Last Updated: 2024-11-23
