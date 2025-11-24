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

/**
 * Augment the Window interface to include the Craft bridge
 */
declare global {
  interface Window {
    /**
     * Craft native bridge API (auto-injected)
     */
    craft: CraftBridgeAPI
  }
}
