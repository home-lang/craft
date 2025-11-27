export interface WindowOptions {
  /**
   * Window title
   */
  title?: string

  /**
   * Window width in pixels
   * @default 800
   */
  width?: number

  /**
   * Window height in pixels
   * @default 600
   */
  height?: number

  /**
   * X position of window
   */
  x?: number

  /**
   * Y position of window
   */
  y?: number

  /**
   * Whether window is resizable
   * @default true
   */
  resizable?: boolean

  /**
   * Whether window is frameless
   * @default false
   */
  frameless?: boolean

  /**
   * Whether window has transparency
   * @default false
   */
  transparent?: boolean

  /**
   * Whether window is always on top
   * @default false
   */
  alwaysOnTop?: boolean

  /**
   * Whether window starts in fullscreen
   * @default false
   */
  fullscreen?: boolean

  /**
   * Enable dark mode
   */
  darkMode?: boolean

  /**
   * Enable hot reload for development
   * @default false
   */
  hotReload?: boolean

  /**
   * Enable developer tools
   * @default false in production, true in development
   */
  devTools?: boolean

  /**
   * Enable system tray icon
   * @default false
   */
  systemTray?: boolean

  /**
   * Hide dock icon (menubar-only mode, macOS)
   * @default false
   */
  hideDockIcon?: boolean

  /**
   * Menubar-only mode (no window, only system tray)
   * @default false
   */
  menubarOnly?: boolean

  /**
   * Hide the titlebar (content extends to window edge)
   * @default false
   */
  titlebarHidden?: boolean
}

export interface AppConfig {
  /**
   * HTML content to display
   */
  html?: string

  /**
   * URL to load
   */
  url?: string

  /**
   * Window options
   */
  window?: WindowOptions

  /**
   * Path to Craft binary (auto-detected if not provided)
   */
  craftPath?: string
}


// ============================================================================
// Craft Bridge API Type Definitions
// These types describe the JavaScript API available in the WebView
// ============================================================================

/**
 * Craft System Tray API (available as window.craft.tray in WebView)
 */
export interface CraftTrayAPI {
    /**
     * Update the system tray title/text
     * Updates in real-time (60fps max)
     * @param title - Text to show in menubar (max 20 chars recommended)
     */
    setTitle(title: string): Promise<void>

    /**
     * Set tooltip text for the tray icon
     * @param tooltip - Tooltip text (shows on hover)
     */
    setTooltip(tooltip: string): Promise<void>

    /**
     * Register a click handler for tray icon clicks
     * @param callback - Function to call when tray icon is clicked
     * @returns Function to unregister the handler
     */
    onClick(callback: (event: TrayClickEvent) => void): () => void

    /**
     * Convenience: toggle window visibility on tray click
     * @returns Function to unregister the handler
     */
    onClickToggleWindow(): () => void

    /**
     * Set a context menu for the tray icon
     * @param items - Menu item definitions
     */
    setMenu(items: MenuItem[]): Promise<void>
}

/**
 * Craft Window Control API (available as window.craft.window in WebView)
 */
export interface CraftWindowAPI {
    /**
     * Show the window
     */
    show(): Promise<void>

    /**
     * Hide the window
     */
    hide(): Promise<void>

    /**
     * Toggle window visibility
     */
    toggle(): Promise<void>

    /**
     * Minimize the window
     */
    minimize(): Promise<void>

    /**
     * Close the window
     */
    close(): Promise<void>
}

/**
 * Craft App Control API (available as window.craft.app in WebView)
 */
export interface CraftAppAPI {
    /**
     * Hide the dock icon (menubar-only mode, macOS)
     */
    hideDockIcon(): Promise<void>

    /**
     * Show the dock icon (normal mode, macOS)
     */
    showDockIcon(): Promise<void>

    /**
     * Quit the application
     */
    quit(): Promise<void>

    /**
     * Send a native system notification
     * @param options - Notification configuration
     */
    notify(options: NotificationOptions): Promise<void>

    /**
     * Get application information
     */
    getInfo(): Promise<AppInfo>
}

/**
 * Complete Craft Bridge API (available as window.craft in WebView)
 */
export interface CraftBridgeAPI {
    /**
     * System tray control
     */
    tray: CraftTrayAPI

    /**
     * Window control
     */
    window: CraftWindowAPI

    /**
     * Application control
     */
    app: CraftAppAPI
}

/**
 * Tray click event details
 */
export interface TrayClickEvent {
    /**
     * Which mouse button was clicked
     */
    button: 'left' | 'right' | 'middle'

    /**
     * Timestamp of the click
     */
    timestamp: number

    /**
     * Keyboard modifiers held during click
     */
    modifiers: {
        command?: boolean
        shift?: boolean
        option?: boolean
        control?: boolean
    }
}

/**
 * Menu item configuration
 */
export interface MenuItem {
    /**
     * Unique identifier for the menu item
     */
    id?: string

    /**
     * Label text to display
     */
    label?: string

    /**
     * Menu item type
     */
    type?: 'normal' | 'separator' | 'checkbox' | 'radio'

    /**
     * Whether the item is checked (for checkbox/radio types)
     */
    checked?: boolean

    /**
     * Whether the item is enabled
     */
    enabled?: boolean

    /**
     * Action to perform when clicked (built-in or custom)
     */
    action?: 'show' | 'hide' | 'toggle' | 'quit' | string

    /**
     * Keyboard shortcut (e.g., 'Cmd+Q')
     */
    shortcut?: string

    /**
     * Submenu items
     */
    submenu?: MenuItem[]
}

/**
 * Application information
 */
export interface AppInfo {
    /**
     * Application name
     */
    name: string

    /**
     * Application version
     */
    version: string

    /**
     * Platform (macos, linux, windows)
     */
    platform: string
}

/**
 * Notification options
 */
export interface NotificationOptions {
    /**
     * Notification title (required)
     */
    title: string

    /**
     * Notification body text
     */
    body?: string

    /**
     * Icon path or data URL
     */
    icon?: string

    /**
     * Sound to play
     * - "default" - System default sound
     * - "Glass" - Glass sound (macOS)
     * - "Ping" - Ping sound (macOS)
     * - Or any system sound name
     */
    sound?: string

    /**
     * Action buttons (platform dependent)
     */
    actions?: Array<{
        action: string
        title: string
    }>

    /**
     * Notification tag (for grouping/replacing)
     */
    tag?: string

    /**
     * Auto-close timeout in milliseconds
     */
    timeout?: number
}

// ============================================================================
// Mobile Platform APIs
// ============================================================================

/**
 * Device information (mobile platforms)
 */
export interface DeviceInfo {
  /**
   * Platform (ios, android)
   */
  platform: 'ios' | 'android'

  /**
   * OS version
   */
  osVersion: string

  /**
   * Device model
   */
  model: string

  /**
   * Screen width in points
   */
  screenWidth: number

  /**
   * Screen height in points
   */
  screenHeight: number

  /**
   * Device pixel ratio
   */
  scaleFactor: number

  /**
   * Whether device is a tablet
   */
  isTablet: boolean

  /**
   * Safe area insets
   */
  safeAreaInsets: {
    top: number
    bottom: number
    left: number
    right: number
  }
}

/**
 * Permission types
 */
export type Permission =
  | 'camera'
  | 'microphone'
  | 'location'
  | 'photos'
  | 'notifications'
  | 'contacts'
  | 'calendar'
  | 'reminders'

/**
 * Permission status
 */
export type PermissionStatus = 'granted' | 'denied' | 'notDetermined' | 'restricted'

/**
 * Haptic feedback types
 */
export type HapticType =
  | 'selection'
  | 'impact-light'
  | 'impact-medium'
  | 'impact-heavy'
  | 'notification-success'
  | 'notification-warning'
  | 'notification-error'

/**
 * Camera options
 */
export interface CameraOptions {
  /**
   * Camera type (front or back)
   */
  type?: 'front' | 'back'

  /**
   * Media type to capture
   */
  mediaType?: 'photo' | 'video'

  /**
   * Maximum video duration in seconds
   */
  maxDuration?: number

  /**
   * Video quality
   */
  quality?: 'low' | 'medium' | 'high'
}

/**
 * Photo picker options
 */
export interface PhotoPickerOptions {
  /**
   * Maximum number of selections
   */
  maxSelections?: number

  /**
   * Media types to show
   */
  mediaType?: 'photo' | 'video' | 'all'
}

/**
 * Share options
 */
export interface ShareOptions {
  /**
   * Text to share
   */
  text?: string

  /**
   * URL to share
   */
  url?: string

  /**
   * Title (Android only)
   */
  title?: string

  /**
   * Dialog title (Android only)
   */
  dialogTitle?: string
}

/**
 * Craft Mobile API (device-specific features)
 */
export interface CraftMobileAPI {
  /**
   * Get device information
   */
  getDeviceInfo(): Promise<DeviceInfo>

  /**
   * Request permission
   * @param permission - Permission type to request
   */
  requestPermission(permission: Permission): Promise<PermissionStatus>

  /**
   * Check permission status
   * @param permission - Permission type to check
   */
  checkPermission(permission: Permission): Promise<PermissionStatus>

  /**
   * Trigger haptic feedback
   * @param type - Haptic feedback type
   */
  haptic(type: HapticType): Promise<void>

  /**
   * Vibrate device
   * @param duration - Duration in milliseconds
   */
  vibrate(duration: number): Promise<void>

  /**
   * Show native toast (Android) or banner (iOS)
   * @param message - Message to display
   * @param duration - Duration in milliseconds (optional)
   */
  toast(message: string, duration?: number): Promise<void>

  /**
   * Open camera to capture photo/video
   * @param options - Camera configuration
   */
  openCamera(options?: CameraOptions): Promise<string>

  /**
   * Open photo picker
   * @param options - Picker configuration
   */
  pickPhoto(options?: PhotoPickerOptions): Promise<string[]>

  /**
   * Share content via system share sheet
   * @param options - Share configuration
   */
  share(options: ShareOptions): Promise<void>

  /**
   * Set orientation lock
   * @param orientation - Orientation to lock to
   */
  setOrientation(orientation: 'portrait' | 'landscape' | 'any'): Promise<void>

  /**
   * Set status bar style (iOS)
   * @param style - Status bar style
   */
  setStatusBarStyle(style: 'light' | 'dark' | 'default'): Promise<void>

  /**
   * Open app settings
   */
  openSettings(): Promise<void>

  /**
   * Check if biometric auth is available
   */
  isBiometricAvailable(): Promise<boolean>

  /**
   * Authenticate with biometrics
   * @param reason - Reason shown to user (iOS)
   */
  authenticateBiometric(reason: string): Promise<boolean>

  /**
   * Store data securely (keychain/keystore)
   * @param key - Storage key
   * @param value - Value to store
   */
  secureStore(key: string, value: string): Promise<void>

  /**
   * Retrieve data from secure storage
   * @param key - Storage key
   */
  secureRetrieve(key: string): Promise<string | null>

  /**
   * Delete data from secure storage
   * @param key - Storage key
   */
  secureDelete(key: string): Promise<void>
}

/**
 * Complete Craft Bridge API (available as window.craft in WebView)
 * Unified across desktop and mobile platforms
 */
export interface CraftBridgeAPI {
  /**
   * System tray control (desktop only)
   */
  tray?: CraftTrayAPI

  /**
   * Window control (desktop)
   */
  window?: CraftWindowAPI

  /**
   * Application control
   */
  app: CraftAppAPI

  /**
   * Mobile-specific APIs (mobile only)
   */
  mobile?: CraftMobileAPI

  /**
   * File system APIs
   */
  fs?: CraftFileSystemAPI

  /**
   * Database APIs
   */
  db?: CraftDatabaseAPI

  /**
   * HTTP client APIs
   */
  http?: CraftHttpAPI

  /**
   * Crypto APIs
   */
  crypto?: CraftCryptoAPI
}

/**
 * File system API
 */
export interface CraftFileSystemAPI {
  /**
   * Read file contents
   * @param path - File path
   */
  readFile(path: string): Promise<string>

  /**
   * Write file contents
   * @param path - File path
   * @param content - File content
   */
  writeFile(path: string, content: string): Promise<void>

  /**
   * Read directory contents
   * @param path - Directory path
   */
  readDir(path: string): Promise<string[]>

  /**
   * Create directory
   * @param path - Directory path
   */
  mkdir(path: string): Promise<void>

  /**
   * Remove file or directory
   * @param path - Path to remove
   */
  remove(path: string): Promise<void>

  /**
   * Check if path exists
   * @param path - Path to check
   */
  exists(path: string): Promise<boolean>
}

/**
 * Database API (SQLite)
 */
export interface CraftDatabaseAPI {
  /**
   * Execute SQL query
   * @param sql - SQL query
   * @param params - Query parameters
   */
  execute(sql: string, params?: unknown[]): Promise<void>

  /**
   * Query database
   * @param sql - SQL query
   * @param params - Query parameters
   */
  query(sql: string, params?: unknown[]): Promise<unknown[]>

  /**
   * Begin transaction
   */
  beginTransaction(): Promise<void>

  /**
   * Commit transaction
   */
  commit(): Promise<void>

  /**
   * Rollback transaction
   */
  rollback(): Promise<void>
}

/**
 * HTTP client API
 */
export interface CraftHttpAPI {
  /**
   * Fetch resource
   * @param url - URL to fetch
   * @param options - Fetch options
   */
  fetch(url: string, options?: RequestInit): Promise<Response>

  /**
   * Download file with progress
   * @param url - URL to download
   * @param destination - Download destination path
   * @param onProgress - Progress callback
   */
  download(
    url: string,
    destination: string,
    onProgress?: (progress: { loaded: number, total: number }) => void
  ): Promise<void>

  /**
   * Upload file with progress
   * @param url - Upload URL
   * @param filePath - File to upload
   * @param onProgress - Progress callback
   */
  upload(
    url: string,
    filePath: string,
    onProgress?: (progress: { loaded: number, total: number }) => void
  ): Promise<Response>
}

/**
 * Crypto API
 */
export interface CraftCryptoAPI {
  /**
   * Generate random bytes
   * @param size - Number of bytes
   */
  randomBytes(size: number): Promise<Uint8Array>

  /**
   * Hash data
   * @param algorithm - Hash algorithm
   * @param data - Data to hash
   */
  hash(algorithm: 'sha256' | 'sha512' | 'md5', data: string): Promise<string>

  /**
   * Encrypt data
   * @param data - Data to encrypt
   * @param key - Encryption key
   */
  encrypt(data: string, key: string): Promise<string>

  /**
   * Decrypt data
   * @param encryptedData - Data to decrypt
   * @param key - Decryption key
   */
  decrypt(encryptedData: string, key: string): Promise<string>
}

// ============================================================================
// Event Emitter Pattern
// ============================================================================

/**
 * Event types for craft.on() and craft.off()
 */
export type CraftEventType =
  | 'window:focus'
  | 'window:blur'
  | 'window:resize'
  | 'window:move'
  | 'window:close'
  | 'window:minimize'
  | 'window:maximize'
  | 'window:fullscreen'
  | 'app:activate'
  | 'app:deactivate'
  | 'app:beforeQuit'
  | 'app:willQuit'
  | 'tray:click'
  | 'tray:rightClick'
  | 'tray:doubleClick'
  | 'menu:click'
  | 'shortcut:triggered'
  | 'deeplink:open'
  | 'file:drop'
  | 'theme:change'
  | 'network:online'
  | 'network:offline'
  | 'battery:low'
  | 'battery:charging'
  | 'idle:active'
  | 'idle:idle'
  | 'display:added'
  | 'display:removed'
  | 'display:changed'

/**
 * Event data map for typed event handlers
 */
export interface CraftEventMap {
  'window:focus': void
  'window:blur': void
  'window:resize': { width: number; height: number }
  'window:move': { x: number; y: number }
  'window:close': void
  'window:minimize': void
  'window:maximize': void
  'window:fullscreen': { isFullscreen: boolean }
  'app:activate': void
  'app:deactivate': void
  'app:beforeQuit': { preventDefault: () => void }
  'app:willQuit': void
  'tray:click': TrayClickEvent
  'tray:rightClick': TrayClickEvent
  'tray:doubleClick': TrayClickEvent
  'menu:click': { menuId: string; itemId: string }
  'shortcut:triggered': { shortcut: string }
  'deeplink:open': { url: string }
  'file:drop': { files: string[] }
  'theme:change': { theme: 'light' | 'dark' | 'system' }
  'network:online': void
  'network:offline': void
  'battery:low': { level: number }
  'battery:charging': { isCharging: boolean }
  'idle:active': void
  'idle:idle': { idleTime: number }
  'display:added': DisplayInfo
  'display:removed': { id: string }
  'display:changed': DisplayInfo
}

/**
 * Event handler type
 */
export type CraftEventHandler<T extends CraftEventType> = (data: CraftEventMap[T]) => void

/**
 * Display information
 */
export interface DisplayInfo {
  /** Display ID */
  id: string
  /** Display name */
  name: string
  /** Width in pixels */
  width: number
  /** Height in pixels */
  height: number
  /** Scale factor */
  scaleFactor: number
  /** Whether this is the primary display */
  isPrimary: boolean
  /** Display bounds */
  bounds: { x: number; y: number; width: number; height: number }
  /** Work area bounds (excluding taskbar/dock) */
  workArea: { x: number; y: number; width: number; height: number }
}

/**
 * Event emitter API
 */
export interface CraftEventEmitter {
  /**
   * Register an event handler
   * @param event - Event type
   * @param handler - Event handler function
   * @returns Unsubscribe function
   */
  on<T extends CraftEventType>(event: T, handler: CraftEventHandler<T>): () => void

  /**
   * Register a one-time event handler
   * @param event - Event type
   * @param handler - Event handler function
   * @returns Unsubscribe function
   */
  once<T extends CraftEventType>(event: T, handler: CraftEventHandler<T>): () => void

  /**
   * Remove an event handler
   * @param event - Event type
   * @param handler - Event handler function
   */
  off<T extends CraftEventType>(event: T, handler: CraftEventHandler<T>): void

  /**
   * Remove all handlers for an event
   * @param event - Event type
   */
  removeAllListeners(event?: CraftEventType): void

  /**
   * Emit an event (internal use)
   * @param event - Event type
   * @param data - Event data
   */
  emit<T extends CraftEventType>(event: T, data: CraftEventMap[T]): void
}

// ============================================================================
// Mobile Platform Configurations
// ============================================================================

/**
 * iOS-specific configuration
 */
export interface IOSConfig {
  /** Bundle identifier */
  bundleId: string
  /** App name */
  appName: string
  /** Version string */
  version: string
  /** Build number */
  buildNumber: string
  /** Minimum iOS version */
  minimumOSVersion?: string
  /** Device families (1=iPhone, 2=iPad) */
  deviceFamily?: (1 | 2)[]
  /** Supported orientations */
  orientations?: ('portrait' | 'portraitUpsideDown' | 'landscapeLeft' | 'landscapeRight')[]
  /** Status bar style */
  statusBarStyle?: 'default' | 'lightContent' | 'darkContent'
  /** Hide status bar */
  statusBarHidden?: boolean
  /** Requires full screen */
  requiresFullScreen?: boolean
  /** Background modes */
  backgroundModes?: ('audio' | 'location' | 'fetch' | 'remote-notification' | 'processing')[]
  /** URL schemes */
  urlSchemes?: string[]
  /** Associated domains (for universal links) */
  associatedDomains?: string[]
  /** App Transport Security settings */
  ats?: {
    allowsArbitraryLoads?: boolean
    allowsArbitraryLoadsForMedia?: boolean
    allowsArbitraryLoadsInWebContent?: boolean
    exceptionDomains?: Record<string, {
      includesSubdomains?: boolean
      allowsInsecureHTTPLoads?: boolean
    }>
  }
  /** Privacy usage descriptions */
  privacyDescriptions?: {
    camera?: string
    microphone?: string
    photoLibrary?: string
    location?: string
    locationAlways?: string
    contacts?: string
    calendars?: string
    reminders?: string
    healthShare?: string
    healthUpdate?: string
    motion?: string
    bluetooth?: string
    faceId?: string
    speechRecognition?: string
    tracking?: string
  }
  /** Capabilities */
  capabilities?: {
    pushNotifications?: boolean
    appGroups?: string[]
    iCloud?: { containers?: string[] }
    healthKit?: boolean
    homeKit?: boolean
    siriKit?: boolean
    carPlay?: boolean
    accessWifi?: boolean
    nfc?: boolean
  }
  /** Entitlements */
  entitlements?: Record<string, any>
}

/**
 * Android-specific configuration
 */
export interface AndroidConfig {
  /** Package name */
  packageName: string
  /** App name */
  appName: string
  /** Version name */
  versionName: string
  /** Version code */
  versionCode: number
  /** Minimum SDK version */
  minSdkVersion?: number
  /** Target SDK version */
  targetSdkVersion?: number
  /** Compile SDK version */
  compileSdkVersion?: number
  /** Supported screen sizes */
  screenSizes?: ('small' | 'normal' | 'large' | 'xlarge')[]
  /** Screen orientations */
  orientations?: ('portrait' | 'landscape' | 'sensor')[]
  /** Permissions */
  permissions?: string[]
  /** Features */
  features?: Array<{ name: string; required?: boolean }>
  /** Intent filters */
  intentFilters?: Array<{
    action: string
    category?: string[]
    data?: { scheme?: string; host?: string; pathPrefix?: string }
  }>
  /** Deep links */
  deepLinks?: Array<{
    scheme: string
    host: string
    pathPrefix?: string
  }>
  /** Gradle config */
  gradle?: {
    buildToolsVersion?: string
    ndkVersion?: string
    kotlinVersion?: string
    dependencies?: string[]
    plugins?: string[]
  }
  /** ProGuard rules */
  proguardRules?: string[]
  /** Signing config */
  signing?: {
    keyAlias: string
    keyPassword?: string
    storeFile: string
    storePassword?: string
  }
  /** Adaptive icon */
  adaptiveIcon?: {
    foreground: string
    background: string
    monochromeIcon?: string
  }
  /** Splash screen */
  splashScreen?: {
    backgroundColor: string
    icon: string
    iconWidth?: number
  }
}

/**
 * macOS-specific configuration
 */
export interface MacOSConfig {
  /** Bundle identifier */
  bundleId: string
  /** App name */
  appName: string
  /** Version */
  version: string
  /** Build number */
  buildNumber: string
  /** Minimum macOS version */
  minimumOSVersion?: string
  /** App category */
  category?: string
  /** Copyright */
  copyright?: string
  /** Sandbox enabled */
  sandbox?: boolean
  /** Hardened runtime */
  hardenedRuntime?: boolean
  /** Code signing identity */
  signingIdentity?: string
  /** Provisioning profile */
  provisioningProfile?: string
  /** Entitlements */
  entitlements?: {
    'com.apple.security.app-sandbox'?: boolean
    'com.apple.security.network.client'?: boolean
    'com.apple.security.network.server'?: boolean
    'com.apple.security.files.user-selected.read-only'?: boolean
    'com.apple.security.files.user-selected.read-write'?: boolean
    'com.apple.security.files.downloads.read-only'?: boolean
    'com.apple.security.files.downloads.read-write'?: boolean
    'com.apple.security.device.camera'?: boolean
    'com.apple.security.device.microphone'?: boolean
    'com.apple.security.device.usb'?: boolean
    'com.apple.security.device.bluetooth'?: boolean
    'com.apple.security.personal-information.location'?: boolean
    'com.apple.security.personal-information.addressbook'?: boolean
    'com.apple.security.personal-information.calendars'?: boolean
    'com.apple.security.automation.apple-events'?: boolean
    [key: string]: boolean | string | string[] | undefined
  }
  /** URL schemes */
  urlSchemes?: string[]
  /** File type associations */
  fileAssociations?: Array<{
    extension: string
    name: string
    role: 'Editor' | 'Viewer' | 'Shell' | 'None'
    icon?: string
  }>
  /** DMG options */
  dmg?: {
    title?: string
    icon?: string
    background?: string
    windowWidth?: number
    windowHeight?: number
    iconSize?: number
    contents?: Array<{ x: number; y: number; type: 'file' | 'link'; path: string }>
  }
  /** Notarization */
  notarization?: {
    appleId: string
    teamId: string
    password?: string
  }
}

/**
 * Windows-specific configuration
 */
export interface WindowsConfig {
  /** Application ID */
  appId: string
  /** App name */
  appName: string
  /** Version */
  version: string
  /** Publisher name */
  publisher: string
  /** Publisher display name */
  publisherDisplayName: string
  /** Description */
  description?: string
  /** App icon */
  icon?: string
  /** Request elevation */
  requestedExecutionLevel?: 'asInvoker' | 'highestAvailable' | 'requireAdministrator'
  /** File associations */
  fileAssociations?: Array<{
    extension: string
    name: string
    description?: string
    icon?: string
  }>
  /** Protocol handlers */
  protocols?: Array<{
    name: string
    schemes: string[]
  }>
  /** NSIS installer options */
  nsis?: {
    oneClick?: boolean
    perMachine?: boolean
    allowElevation?: boolean
    allowToChangeInstallationDirectory?: boolean
    installerIcon?: string
    uninstallerIcon?: string
    installerHeaderIcon?: string
    createDesktopShortcut?: boolean | 'always'
    createStartMenuShortcut?: boolean
    shortcutName?: string
    include?: string
    license?: string
  }
  /** MSI installer options */
  msi?: {
    oneClick?: boolean
    perMachine?: boolean
    upgradeCode?: string
  }
  /** MSIX package options */
  msix?: {
    identityName?: string
    applicationId?: string
    publisher?: string
    publisherDisplayName?: string
    certificateFile?: string
    certificatePassword?: string
  }
  /** Code signing */
  signing?: {
    certificateFile?: string
    certificatePassword?: string
    certificateSubjectName?: string
    certificateSha1?: string
    signingHashAlgorithms?: ('sha1' | 'sha256')[]
    timestampServer?: string
  }
}

/**
 * Linux-specific configuration
 */
export interface LinuxConfig {
  /** App name */
  appName: string
  /** Executable name */
  executableName: string
  /** Version */
  version: string
  /** Description */
  description?: string
  /** Maintainer */
  maintainer?: string
  /** Vendor */
  vendor?: string
  /** Homepage */
  homepage?: string
  /** Category */
  category?: string
  /** Icon */
  icon?: string | Record<string, string>
  /** Desktop file */
  desktop?: {
    Name?: string
    GenericName?: string
    Comment?: string
    Exec?: string
    Icon?: string
    Terminal?: boolean
    Type?: string
    Categories?: string[]
    MimeType?: string[]
    StartupWMClass?: string
    Keywords?: string[]
  }
  /** Deb package options */
  deb?: {
    depends?: string[]
    recommends?: string[]
    section?: string
    priority?: string
    scripts?: {
      preinst?: string
      postinst?: string
      prerm?: string
      postrm?: string
    }
  }
  /** RPM package options */
  rpm?: {
    requires?: string[]
    license?: string
    group?: string
    scripts?: {
      pre?: string
      post?: string
      preun?: string
      postun?: string
    }
  }
  /** AppImage options */
  appImage?: {
    license?: string
    category?: string
  }
  /** Flatpak options */
  flatpak?: {
    appId: string
    branch?: string
    runtime?: string
    runtimeVersion?: string
    sdk?: string
    permissions?: string[]
    modules?: any[]
  }
  /** Snap options */
  snap?: {
    name: string
    grade?: 'stable' | 'devel'
    confinement?: 'strict' | 'classic' | 'devmode'
    base?: string
    plugs?: string[]
    slots?: string[]
  }
}

/**
 * Complete app configuration with platform-specific options
 */
export interface CraftAppConfig extends AppConfig {
  /** iOS configuration */
  ios?: IOSConfig
  /** Android configuration */
  android?: AndroidConfig
  /** macOS configuration */
  macos?: MacOSConfig
  /** Windows configuration */
  windows?: WindowsConfig
  /** Linux configuration */
  linux?: LinuxConfig
}

/**
 * Augment the Window interface to include the Craft bridge
 */
declare global {
  interface Window {
    /**
     * Craft native bridge API (auto-injected)
     */
    craft: CraftBridgeAPI & CraftEventEmitter
  }
}
