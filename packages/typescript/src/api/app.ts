/**
 * Craft App API
 * Application lifecycle, configuration, and system integration
 * @module @craft/api/app
 */

import { getBridge } from '../bridge/core'

// ============================================================================
// Types
// ============================================================================

/**
 * Application information
 */
export interface AppInfo {
  /** App name */
  name: string
  /** App version */
  version: string
  /** Bundle identifier */
  bundleId?: string
  /** Build number */
  buildNumber?: string
  /** Platform */
  platform: 'macos' | 'windows' | 'linux' | 'ios' | 'android'
  /** Architecture */
  arch: 'x64' | 'arm64' | 'x86' | 'arm'
  /** App path */
  appPath: string
  /** User data path */
  userDataPath: string
  /** Executable path */
  executablePath: string
  /** Resources path */
  resourcesPath: string
  /** Temp path */
  tempPath: string
  /** Logs path */
  logsPath: string
  /** Is packaged app */
  isPackaged: boolean
  /** Is development mode */
  isDevelopment: boolean
}

/**
 * System preferences
 */
export interface SystemPreferences {
  /** Dark mode enabled */
  isDarkMode: boolean
  /** Accent color */
  accentColor: string
  /** Reduced motion */
  reducedMotion: boolean
  /** Reduced transparency */
  reducedTransparency: boolean
  /** High contrast */
  highContrast: boolean
  /** System font */
  systemFont: string
  /** System locale */
  locale: string
  /** System timezone */
  timezone: string
}

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
  /** Is primary display */
  isPrimary: boolean
  /** Display bounds */
  bounds: { x: number; y: number; width: number; height: number }
  /** Work area (excluding taskbar/dock) */
  workArea: { x: number; y: number; width: number; height: number }
  /** Refresh rate */
  refreshRate?: number
  /** Color depth */
  colorDepth?: number
  /** Is touchscreen */
  touchSupport?: boolean
}

/**
 * Badge options (dock/taskbar)
 */
export interface BadgeOptions {
  /** Badge text/number */
  badge: string | number | null
  /** Badge color (optional) */
  color?: string
}

/**
 * Notification options
 */
export interface NotificationOptions {
  /** Notification title */
  title: string
  /** Notification body */
  body?: string
  /** Notification subtitle (macOS) */
  subtitle?: string
  /** Icon path */
  icon?: string
  /** Sound to play */
  sound?: string | 'default' | 'none'
  /** Action buttons */
  actions?: Array<{ action: string; title: string; icon?: string }>
  /** Close button text */
  closeButtonText?: string
  /** Has reply field */
  hasReply?: boolean
  /** Reply placeholder */
  replyPlaceholder?: string
  /** Timeout type */
  timeoutType?: 'default' | 'never'
  /** Urgency (Linux) */
  urgency?: 'low' | 'normal' | 'critical'
  /** Silent */
  silent?: boolean
  /** Tag for grouping/replacing */
  tag?: string
}

/**
 * App event types
 */
export type AppEventType =
  | 'ready'
  | 'activate'
  | 'deactivate'
  | 'will-quit'
  | 'quit'
  | 'before-quit'
  | 'window-all-closed'
  | 'open-file'
  | 'open-url'
  | 'theme-changed'
  | 'accent-color-changed'
  | 'display-added'
  | 'display-removed'
  | 'display-metrics-changed'
  | 'power-suspend'
  | 'power-resume'
  | 'power-on-ac'
  | 'power-on-battery'
  | 'lock-screen'
  | 'unlock-screen'
  | 'user-did-become-active'
  | 'user-did-resign-active'

/**
 * App event data map
 */
export interface AppEventMap {
  'ready': void
  'activate': { hasVisibleWindows: boolean }
  'deactivate': void
  'will-quit': { preventDefault: () => void }
  'quit': void
  'before-quit': { preventDefault: () => void }
  'window-all-closed': void
  'open-file': { path: string }
  'open-url': { url: string }
  'theme-changed': { theme: 'light' | 'dark' }
  'accent-color-changed': { color: string }
  'display-added': DisplayInfo
  'display-removed': { id: string }
  'display-metrics-changed': { display: DisplayInfo; changedMetrics: string[] }
  'power-suspend': void
  'power-resume': void
  'power-on-ac': void
  'power-on-battery': void
  'lock-screen': void
  'unlock-screen': void
  'user-did-become-active': void
  'user-did-resign-active': void
}

/**
 * App event handler
 */
export type AppEventHandler<T extends AppEventType> = (data: AppEventMap[T]) => void

/**
 * Global shortcut handler
 */
export type ShortcutHandler = () => void

// ============================================================================
// App Manager Class
// ============================================================================

/**
 * Application manager for lifecycle and system integration
 */
class AppManager {
  private _listeners: Map<string, Set<Function>> = new Map()
  private _shortcuts: Map<string, ShortcutHandler> = new Map()
  private _info: AppInfo | null = null
  private _preferences: SystemPreferences | null = null

  constructor() {
    this._setupEventListeners()
  }

  private _setupEventListeners(): void {
    if (typeof window !== 'undefined') {
      // System events
      const events: AppEventType[] = [
        'ready', 'activate', 'deactivate', 'will-quit', 'quit', 'before-quit',
        'window-all-closed', 'open-file', 'open-url', 'theme-changed',
        'accent-color-changed', 'display-added', 'display-removed',
        'display-metrics-changed', 'power-suspend', 'power-resume',
        'power-on-ac', 'power-on-battery', 'lock-screen', 'unlock-screen',
        'user-did-become-active', 'user-did-resign-active'
      ]

      events.forEach(event => {
        window.addEventListener(`craft:app:${event}` as any, (e: CustomEvent) => {
          this._emit(event, e.detail)
        })
      })

      // Global shortcut events
      window.addEventListener('craft:shortcut' as any, (e: CustomEvent) => {
        const accelerator = e.detail?.accelerator
        const handler = this._shortcuts.get(accelerator)
        if (handler) {
          handler()
        }
      })

      // Theme change detection via media query
      if (window.matchMedia) {
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
          this._emit('theme-changed', { theme: e.matches ? 'dark' : 'light' })
        })
      }
    }
  }

  private _emit(event: string, data?: any): void {
    const listeners = this._listeners.get(event)
    if (listeners) {
      listeners.forEach(fn => fn(data))
    }
  }

  /**
   * Register an event handler
   */
  on<T extends AppEventType>(event: T, handler: AppEventHandler<T>): () => void {
    if (!this._listeners.has(event)) {
      this._listeners.set(event, new Set())
    }
    this._listeners.get(event)!.add(handler)

    return () => {
      this._listeners.get(event)?.delete(handler)
    }
  }

  /**
   * Register a one-time event handler
   */
  once<T extends AppEventType>(event: T, handler: AppEventHandler<T>): () => void {
    const wrapper = (data: AppEventMap[T]) => {
      this._listeners.get(event)?.delete(wrapper)
      handler(data)
    }
    return this.on(event, wrapper as any)
  }

  /**
   * Remove event handler
   */
  off<T extends AppEventType>(event: T, handler: AppEventHandler<T>): void {
    this._listeners.get(event)?.delete(handler)
  }

  // ==========================================================================
  // App Lifecycle
  // ==========================================================================

  /**
   * Quit the application
   */
  async quit(): Promise<void> {
    await this._call('quit')
  }

  /**
   * Exit with code
   */
  async exit(code: number = 0): Promise<void> {
    await this._call('exit', { code })
  }

  /**
   * Relaunch the application
   */
  async relaunch(options?: { args?: string[]; execPath?: string }): Promise<void> {
    await this._call('relaunch', options)
  }

  /**
   * Hide the application (macOS)
   */
  async hide(): Promise<void> {
    await this._call('hide')
  }

  /**
   * Show the application (macOS)
   */
  async show(): Promise<void> {
    await this._call('show')
  }

  /**
   * Focus the application
   */
  async focus(): Promise<void> {
    await this._call('focus')
  }

  // ==========================================================================
  // Dock Icon (macOS)
  // ==========================================================================

  /**
   * Hide dock icon (macOS)
   */
  async hideDockIcon(): Promise<void> {
    await this._call('hideDockIcon')
  }

  /**
   * Show dock icon (macOS)
   */
  async showDockIcon(): Promise<void> {
    await this._call('showDockIcon')
  }

  /**
   * Set dock icon badge
   */
  async setBadge(badge: string | number | null): Promise<void> {
    await this._call('setBadge', { badge: badge?.toString() ?? '' })
  }

  /**
   * Get dock icon badge
   */
  async getBadge(): Promise<string> {
    return this._call('getBadge')
  }

  /**
   * Bounce dock icon (macOS)
   */
  async bounce(type: 'critical' | 'informational' = 'informational'): Promise<number> {
    return this._call('bounce', { type })
  }

  /**
   * Cancel dock icon bounce (macOS)
   */
  async cancelBounce(id: number): Promise<void> {
    await this._call('cancelBounce', { id })
  }

  /**
   * Set dock icon
   */
  async setDockIcon(icon: string): Promise<void> {
    await this._call('setDockIcon', { icon })
  }

  // ==========================================================================
  // App Information
  // ==========================================================================

  /**
   * Get application information
   */
  async getInfo(): Promise<AppInfo> {
    if (!this._info) {
      this._info = await this._call<AppInfo>('getInfo')
    }
    return this._info
  }

  /**
   * Get app name
   */
  async getName(): Promise<string> {
    const info = await this.getInfo()
    return info.name
  }

  /**
   * Get app version
   */
  async getVersion(): Promise<string> {
    const info = await this.getInfo()
    return info.version
  }

  /**
   * Get app path
   */
  async getAppPath(): Promise<string> {
    const info = await this.getInfo()
    return info.appPath
  }

  /**
   * Get path to special directory
   */
  async getPath(name: 'home' | 'appData' | 'userData' | 'temp' | 'exe' | 'desktop' | 'documents' | 'downloads' | 'music' | 'pictures' | 'videos' | 'logs'): Promise<string> {
    return this._call('getPath', { name })
  }

  // ==========================================================================
  // System Preferences
  // ==========================================================================

  /**
   * Get system preferences
   */
  async getSystemPreferences(): Promise<SystemPreferences> {
    if (!this._preferences) {
      this._preferences = await this._call<SystemPreferences>('getSystemPreferences')
    }
    return this._preferences
  }

  /**
   * Check if dark mode is enabled
   */
  async isDarkMode(): Promise<boolean> {
    // Try browser API first
    if (typeof window !== 'undefined' && window.matchMedia) {
      return window.matchMedia('(prefers-color-scheme: dark)').matches
    }
    const prefs = await this.getSystemPreferences()
    return prefs.isDarkMode
  }

  /**
   * Get accent color
   */
  async getAccentColor(): Promise<string> {
    const prefs = await this.getSystemPreferences()
    return prefs.accentColor
  }

  /**
   * Check if reduced motion is enabled
   */
  async isReducedMotion(): Promise<boolean> {
    if (typeof window !== 'undefined' && window.matchMedia) {
      return window.matchMedia('(prefers-reduced-motion: reduce)').matches
    }
    const prefs = await this.getSystemPreferences()
    return prefs.reducedMotion
  }

  /**
   * Get system locale
   */
  async getLocale(): Promise<string> {
    if (typeof navigator !== 'undefined') {
      return navigator.language || 'en-US'
    }
    const prefs = await this.getSystemPreferences()
    return prefs.locale
  }

  // ==========================================================================
  // Display
  // ==========================================================================

  /**
   * Get all displays
   */
  async getDisplays(): Promise<DisplayInfo[]> {
    return this._call('getDisplays')
  }

  /**
   * Get primary display
   */
  async getPrimaryDisplay(): Promise<DisplayInfo> {
    return this._call('getPrimaryDisplay')
  }

  /**
   * Get display at point
   */
  async getDisplayAtPoint(x: number, y: number): Promise<DisplayInfo | null> {
    return this._call('getDisplayAtPoint', { x, y })
  }

  // ==========================================================================
  // Notifications
  // ==========================================================================

  /**
   * Send a notification
   */
  async notify(options: NotificationOptions): Promise<void> {
    await this._call('notify', options)
  }

  /**
   * Check if notifications are supported
   */
  async isNotificationSupported(): Promise<boolean> {
    if (typeof Notification !== 'undefined') {
      return Notification.permission !== 'denied'
    }
    return this._call('isNotificationSupported')
  }

  // ==========================================================================
  // Global Shortcuts
  // ==========================================================================

  /**
   * Register a global shortcut
   */
  async registerShortcut(accelerator: string, handler: ShortcutHandler): Promise<boolean> {
    this._shortcuts.set(accelerator, handler)
    return this._call('registerShortcut', { accelerator })
  }

  /**
   * Unregister a global shortcut
   */
  async unregisterShortcut(accelerator: string): Promise<void> {
    this._shortcuts.delete(accelerator)
    await this._call('unregisterShortcut', { accelerator })
  }

  /**
   * Unregister all global shortcuts
   */
  async unregisterAllShortcuts(): Promise<void> {
    this._shortcuts.clear()
    await this._call('unregisterAllShortcuts')
  }

  /**
   * Check if a shortcut is registered
   */
  async isShortcutRegistered(accelerator: string): Promise<boolean> {
    return this._call('isShortcutRegistered', { accelerator })
  }

  // ==========================================================================
  // Appearance
  // ==========================================================================

  /**
   * Set app appearance (macOS)
   */
  async setAppearance(appearance: 'light' | 'dark' | 'system'): Promise<void> {
    await this._call('setAppearance', { appearance })
  }

  /**
   * Get current appearance
   */
  async getAppearance(): Promise<'light' | 'dark'> {
    return this._call('getAppearance')
  }

  // ==========================================================================
  // Power Management
  // ==========================================================================

  /**
   * Start power save blocker
   */
  async startPowerSaveBlocker(type: 'prevent-app-suspension' | 'prevent-display-sleep'): Promise<number> {
    return this._call('startPowerSaveBlocker', { type })
  }

  /**
   * Stop power save blocker
   */
  async stopPowerSaveBlocker(id: number): Promise<void> {
    await this._call('stopPowerSaveBlocker', { id })
  }

  /**
   * Check if power save blocker is active
   */
  async isPowerSaveBlockerActive(id: number): Promise<boolean> {
    return this._call('isPowerSaveBlockerActive', { id })
  }

  /**
   * Get system idle time
   */
  async getIdleTime(): Promise<number> {
    return this._call('getIdleTime')
  }

  // ==========================================================================
  // Login Items (macOS/Windows)
  // ==========================================================================

  /**
   * Set login item settings
   */
  async setLoginItemSettings(options: { openAtLogin: boolean; openAsHidden?: boolean; path?: string; args?: string[] }): Promise<void> {
    await this._call('setLoginItemSettings', options)
  }

  /**
   * Get login item settings
   */
  async getLoginItemSettings(): Promise<{ openAtLogin: boolean; openAsHidden: boolean; wasOpenedAtLogin: boolean; wasOpenedAsHidden: boolean }> {
    return this._call('getLoginItemSettings')
  }

  // ==========================================================================
  // Helper Methods
  // ==========================================================================

  private async _call<T = void>(action: string, data?: Record<string, any>): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        try {
          (window as any).webkit.messageHandlers.craft.postMessage({
            type: 'app',
            action,
            data
          })
          resolve(undefined as T)
        } catch (error) {
          reject(error)
        }
      })
    }

    const bridge = getBridge()
    return bridge.request(`app.${action}`, data)
  }
}

// ============================================================================
// Exports
// ============================================================================

/**
 * Global app manager instance
 */
export const appManager = new AppManager()

/**
 * Alias for convenience
 */
export const app = appManager

// Re-export common functionality directly
export const quit = () => appManager.quit()
export const hide = () => appManager.hide()
export const show = () => appManager.show()
export const focus = () => appManager.focus()
export const hideDockIcon = () => appManager.hideDockIcon()
export const showDockIcon = () => appManager.showDockIcon()
export const setBadge = (badge: string | number | null) => appManager.setBadge(badge)
export const getInfo = () => appManager.getInfo()
export const getVersion = () => appManager.getVersion()
export const getName = () => appManager.getName()
export const getPath = (name: Parameters<typeof appManager.getPath>[0]) => appManager.getPath(name)
export const isDarkMode = () => appManager.isDarkMode()
export const getLocale = () => appManager.getLocale()
export const notify = (options: NotificationOptions) => appManager.notify(options)
export const registerShortcut = (accelerator: string, handler: ShortcutHandler) => appManager.registerShortcut(accelerator, handler)
export const unregisterShortcut = (accelerator: string) => appManager.unregisterShortcut(accelerator)

export default appManager
