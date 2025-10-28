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
