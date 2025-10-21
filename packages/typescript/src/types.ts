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
   * Path to Zyte binary (auto-detected if not provided)
   */
  zytePath?: string
}


// ============================================================================
// Zyte Bridge API Type Definitions
// These types describe the JavaScript API available in the WebView
// ============================================================================

/**
 * Zyte System Tray API (available as window.zyte.tray in WebView)
 */
export interface ZyteTrayAPI {
    /**
     * Update the system tray title/text
     * @param title - Text to show in menubar (max 20 characters)
     */
    setTitle(title: string): Promise<void>

    /**
     * Set tooltip text for the tray icon
     * @param tooltip - Tooltip text to display on hover
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
     * @param items - Array of menu items
     */
    setMenu(items: MenuItem[]): Promise<void>
}

/**
 * Zyte Window Control API (available as window.zyte.window in WebView)
 */
export interface ZyteWindowAPI {
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
 * Zyte App Control API (available as window.zyte.app in WebView)
 */
export interface ZyteAppAPI {
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
     * Get application information
     */
    getInfo(): Promise<AppInfo>
}

/**
 * Complete Zyte Bridge API (available as window.zyte in WebView)
 */
export interface ZyteBridgeAPI {
    /**
     * System tray control
     */
    tray: ZyteTrayAPI

    /**
     * Window control
     */
    window: ZyteWindowAPI

    /**
     * Application control
     */
    app: ZyteAppAPI
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
 * Augment the Window interface to include the Zyte bridge
 */
declare global {
    interface Window {
        /**
         * Zyte native bridge API (auto-injected)
         */
        zyte: ZyteBridgeAPI
    }
}
