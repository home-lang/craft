/**
 * @fileoverview Windows Advanced Features API
 * @description Advanced Windows-specific features including Jump Lists, Taskbar Progress,
 * Toast Notifications, Windows Hello, Widgets, and Windows App SDK integration.
 * @module @craft/api/windows-advanced
 */

import { isCraft, getPlatform } from './process'

// ============================================================================
// Jump Lists
// ============================================================================

/**
 * Jump list task.
 */
export interface JumpListTask {
  /** Task identifier */
  id: string
  /** Display title */
  title: string
  /** Description */
  description?: string
  /** Icon path or index */
  icon?: string
  /** Icon index (for exe icons) */
  iconIndex?: number
  /** Arguments to pass when launched */
  arguments?: string
  /** Working directory */
  workingDirectory?: string
}

/**
 * Jump list category.
 */
export interface JumpListCategory {
  /** Category type */
  type: 'tasks' | 'frequent' | 'recent' | 'custom'
  /** Custom category title (for 'custom' type) */
  title?: string
  /** Items in this category */
  items: JumpListTask[]
}

/**
 * Jump Lists API for Windows taskbar integration.
 *
 * @example
 * // Set up jump list
 * await jumpList.set([
 *   {
 *     type: 'tasks',
 *     items: [
 *       { id: 'new', title: 'New Window', icon: '%SystemRoot%\\system32\\shell32.dll', iconIndex: 1 },
 *       { id: 'settings', title: 'Settings', arguments: '--settings' }
 *     ]
 *   },
 *   {
 *     type: 'custom',
 *     title: 'Recent Projects',
 *     items: recentProjects.map(p => ({ id: p.id, title: p.name, arguments: `--project ${p.id}` }))
 *   }
 * ])
 *
 * // Handle jump list item click
 * jumpList.onItemClick((id, args) => {
 *   if (id === 'settings') openSettings()
 * })
 */
export const jumpList = {
  /**
   * Check if Jump Lists are supported.
   */
  async isSupported(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'windows') return false
    return (window as any).craft?.jumpList?.isSupported?.() ?? false
  },

  /**
   * Set the jump list categories.
   */
  async set(categories: JumpListCategory[]): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.jumpList?.set?.(categories)
  },

  /**
   * Clear the jump list.
   */
  async clear(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.jumpList?.clear?.()
  },

  /**
   * Add item to recent list.
   */
  async addToRecent(filePath: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.jumpList?.addToRecent?.(filePath)
  },

  /**
   * Clear recent list.
   */
  async clearRecent(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.jumpList?.clearRecent?.()
  },

  /**
   * Add item to frequent list.
   */
  async addToFrequent(filePath: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.jumpList?.addToFrequent?.(filePath)
  },

  /**
   * Clear frequent list.
   */
  async clearFrequent(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.jumpList?.clearFrequent?.()
  },

  /**
   * Handle jump list item click.
   */
  onItemClick(handler: (itemId: string, arguments_: string | null) => void): void {
    if (!isCraft() || getPlatform() !== 'windows') return
    ;(window as any).craft?.jumpList?.onItemClick?.(handler)
  }
}

// ============================================================================
// Taskbar Progress
// ============================================================================

/**
 * Taskbar progress state.
 */
export type TaskbarProgressState = 'none' | 'indeterminate' | 'normal' | 'error' | 'paused'

/**
 * Taskbar Progress API for Windows taskbar.
 *
 * @example
 * // Show download progress
 * await taskbarProgress.setState('normal')
 * await taskbarProgress.setProgress(0.5) // 50%
 *
 * // Show indeterminate progress
 * await taskbarProgress.setState('indeterminate')
 *
 * // Show error state
 * await taskbarProgress.setState('error')
 *
 * // Clear progress
 * await taskbarProgress.setState('none')
 */
export const taskbarProgress = {
  /**
   * Set progress state.
   */
  async setState(state: TaskbarProgressState): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.taskbarProgress?.setState?.(state)
  },

  /**
   * Set progress value (0-1).
   */
  async setProgress(value: number): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.taskbarProgress?.setProgress?.(Math.max(0, Math.min(1, value)))
  },

  /**
   * Clear progress.
   */
  async clear(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.taskbarProgress?.clear?.()
  },

  /**
   * Flash taskbar button.
   */
  async flash(options?: {
    count?: number
    interval?: number
    flags?: 'all' | 'caption' | 'tray'
  }): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.taskbarProgress?.flash?.(options)
  },

  /**
   * Stop flashing.
   */
  async stopFlash(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.taskbarProgress?.stopFlash?.()
  },

  /**
   * Set overlay icon.
   */
  async setOverlayIcon(iconPath: string | null, description?: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.taskbarProgress?.setOverlayIcon?.(iconPath, description)
  }
}

// ============================================================================
// Toast Notifications
// ============================================================================

/**
 * Toast notification action.
 */
export interface ToastAction {
  /** Action identifier */
  id: string
  /** Button text */
  content: string
  /** Action type */
  type?: 'foreground' | 'background' | 'protocol'
  /** Arguments to pass */
  arguments?: string
  /** Image for button */
  imageUri?: string
  /** Input ID to reference */
  inputId?: string
}

/**
 * Toast notification input.
 */
export interface ToastInput {
  /** Input identifier */
  id: string
  /** Input type */
  type: 'text' | 'selection'
  /** Placeholder text (for text input) */
  placeHolderContent?: string
  /** Default value */
  defaultInput?: string
  /** Selection options (for selection input) */
  selections?: Array<{ id: string; content: string }>
}

/**
 * Toast notification content.
 */
export interface ToastContent {
  /** Title text (first line) */
  title: string
  /** Body text (second line) */
  body?: string
  /** Additional body text (third line) */
  body2?: string
  /** App logo override */
  appLogoOverride?: {
    uri: string
    hint?: 'circle' | 'none'
  }
  /** Hero image (full width) */
  heroImage?: {
    uri: string
  }
  /** Inline image */
  inlineImage?: {
    uri: string
  }
  /** Attribution text */
  attribution?: string
  /** Audio */
  audio?: {
    src?: 'default' | 'im' | 'mail' | 'reminder' | 'sms' | 'alarm' | string
    loop?: boolean
    silent?: boolean
  }
  /** Scenario type */
  scenario?: 'default' | 'alarm' | 'reminder' | 'incomingCall' | 'urgent'
  /** Expiration time */
  expirationTime?: Date
  /** Actions */
  actions?: ToastAction[]
  /** Inputs */
  inputs?: ToastInput[]
  /** Progress bar */
  progress?: {
    value: number | 'indeterminate'
    title?: string
    status?: string
    valueStringOverride?: string
  }
}

/**
 * Toast Notifications API for Windows notifications.
 *
 * @example
 * // Show simple notification
 * await toastNotifications.show({
 *   title: 'Download Complete',
 *   body: 'Your file has been downloaded successfully.',
 *   actions: [
 *     { id: 'open', content: 'Open File' },
 *     { id: 'folder', content: 'Open Folder' }
 *   ]
 * })
 *
 * // Show progress notification
 * const tag = 'download-1'
 * await toastNotifications.show({
 *   title: 'Downloading...',
 *   body: 'file.zip',
 *   progress: { value: 0.5, status: '50% complete' }
 * }, { tag })
 *
 * // Update progress
 * await toastNotifications.update(tag, {
 *   progress: { value: 1, status: 'Complete!' }
 * })
 *
 * // Handle action
 * toastNotifications.onActivated((args) => {
 *   if (args.actionId === 'open') openFile()
 * })
 */
export const toastNotifications = {
  /**
   * Check if toast notifications are supported.
   */
  async isSupported(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'windows') return false
    return (window as any).craft?.toastNotifications?.isSupported?.() ?? false
  },

  /**
   * Show a toast notification.
   */
  async show(content: ToastContent, options?: {
    tag?: string
    group?: string
    suppressPopup?: boolean
  }): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.toastNotifications?.show?.(content, options)
  },

  /**
   * Update an existing notification by tag.
   */
  async update(tag: string, updates: Partial<ToastContent>): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.toastNotifications?.update?.(tag, updates)
  },

  /**
   * Hide a notification by tag.
   */
  async hide(tag: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.toastNotifications?.hide?.(tag)
  },

  /**
   * Hide a notification group.
   */
  async hideGroup(group: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.toastNotifications?.hideGroup?.(group)
  },

  /**
   * Clear all notifications.
   */
  async clearAll(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.toastNotifications?.clearAll?.()
  },

  /**
   * Get notification history.
   */
  async getHistory(): Promise<Array<{ tag: string; group: string; deliveredTime: Date }>> {
    if (!isCraft() || getPlatform() !== 'windows') return []
    return (window as any).craft?.toastNotifications?.getHistory?.() ?? []
  },

  /**
   * Handle notification activation (click or action).
   */
  onActivated(handler: (args: {
    tag?: string
    group?: string
    actionId?: string
    arguments?: string
    userInput?: Record<string, string>
  }) => void): void {
    if (!isCraft() || getPlatform() !== 'windows') return
    ;(window as any).craft?.toastNotifications?.onActivated?.(handler)
  },

  /**
   * Handle notification dismissed.
   */
  onDismissed(handler: (args: {
    tag?: string
    reason: 'user' | 'application' | 'timeout'
  }) => void): void {
    if (!isCraft() || getPlatform() !== 'windows') return
    ;(window as any).craft?.toastNotifications?.onDismissed?.(handler)
  }
}

// ============================================================================
// Windows Hello (Biometrics)
// ============================================================================

/**
 * Windows Hello availability.
 */
export interface WindowsHelloAvailability {
  /** Whether Windows Hello is available */
  isAvailable: boolean
  /** Available biometric types */
  biometricTypes: Array<'face' | 'fingerprint' | 'iris'>
  /** Whether device supports companion devices */
  supportsCompanionDevice: boolean
}

/**
 * Windows Hello API for biometric authentication.
 *
 * @example
 * // Check availability
 * const hello = await windowsHello.getAvailability()
 * if (hello.isAvailable) {
 *   // Authenticate
 *   const result = await windowsHello.authenticate('Confirm your identity')
 *   if (result.success) {
 *     // User authenticated
 *   }
 * }
 *
 * // Create a credential
 * const credential = await windowsHello.createCredential('user@example.com', 'Sign in to MyApp')
 *
 * // Verify credential
 * const verified = await windowsHello.verifyCredential(credential.keyId, 'Sign in to MyApp')
 */
export const windowsHello = {
  /**
   * Check Windows Hello availability.
   */
  async getAvailability(): Promise<WindowsHelloAvailability> {
    if (!isCraft() || getPlatform() !== 'windows') {
      return { isAvailable: false, biometricTypes: [], supportsCompanionDevice: false }
    }
    return (window as any).craft?.windowsHello?.getAvailability?.() ?? {
      isAvailable: false,
      biometricTypes: [],
      supportsCompanionDevice: false
    }
  },

  /**
   * Prompt for Windows Hello authentication.
   */
  async authenticate(message: string): Promise<{
    success: boolean
    error?: 'canceled' | 'notConfigured' | 'notAllowed' | 'unknown'
  }> {
    if (!isCraft() || getPlatform() !== 'windows') {
      return { success: false, error: 'notConfigured' }
    }
    return (window as any).craft?.windowsHello?.authenticate?.(message) ?? { success: false }
  },

  /**
   * Create a Windows Hello credential.
   */
  async createCredential(
    userId: string,
    message: string
  ): Promise<{
    success: boolean
    keyId?: string
    publicKey?: string
    attestation?: string
    error?: string
  }> {
    if (!isCraft() || getPlatform() !== 'windows') {
      return { success: false, error: 'Windows Hello not available' }
    }
    return (window as any).craft?.windowsHello?.createCredential?.(userId, message) ?? { success: false }
  },

  /**
   * Sign data with Windows Hello credential.
   */
  async signWithCredential(
    keyId: string,
    challenge: string,
    message: string
  ): Promise<{
    success: boolean
    signature?: string
    error?: string
  }> {
    if (!isCraft() || getPlatform() !== 'windows') {
      return { success: false, error: 'Windows Hello not available' }
    }
    return (window as any).craft?.windowsHello?.signWithCredential?.(keyId, challenge, message) ?? { success: false }
  },

  /**
   * Delete a Windows Hello credential.
   */
  async deleteCredential(keyId: string): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'windows') return false
    return (window as any).craft?.windowsHello?.deleteCredential?.(keyId) ?? false
  },

  /**
   * Check if a credential exists.
   */
  async hasCredential(keyId: string): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'windows') return false
    return (window as any).craft?.windowsHello?.hasCredential?.(keyId) ?? false
  }
}

// ============================================================================
// Windows Widgets
// ============================================================================

/**
 * Widget template type.
 */
export type WidgetTemplateType =
  | 'small'
  | 'medium'
  | 'large'
  | 'adaptive'

/**
 * Widget content.
 */
export interface WindowsWidgetContent {
  /** Template JSON */
  template: Record<string, any>
  /** Data to bind to template */
  data: Record<string, any>
}

/**
 * Windows Widgets API (Windows 11).
 *
 * @example
 * // Register widget provider
 * windowsWidgets.register({
 *   id: 'weather-widget',
 *   name: 'Weather',
 *   description: 'Shows current weather',
 *   defaultTemplate: 'medium'
 * })
 *
 * // Provide content
 * windowsWidgets.onContentRequested('weather-widget', async (context) => {
 *   const weather = await fetchWeather()
 *   return {
 *     template: weatherTemplate,
 *     data: { temp: weather.temp, condition: weather.condition }
 *   }
 * })
 *
 * // Handle customization
 * windowsWidgets.onCustomize('weather-widget', async (settings) => {
 *   // Save user settings
 * })
 */
export const windowsWidgets = {
  /**
   * Check if Windows Widgets are supported.
   */
  async isSupported(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'windows') return false
    return (window as any).craft?.windowsWidgets?.isSupported?.() ?? false
  },

  /**
   * Register a widget provider.
   */
  register(config: {
    id: string
    name: string
    description: string
    defaultTemplate: WidgetTemplateType
    supportedTemplates?: WidgetTemplateType[]
    hasCustomization?: boolean
  }): void {
    if (!isCraft() || getPlatform() !== 'windows') return
    ;(window as any).craft?.windowsWidgets?.register?.(config)
  },

  /**
   * Unregister a widget provider.
   */
  unregister(widgetId: string): void {
    if (!isCraft() || getPlatform() !== 'windows') return
    ;(window as any).craft?.windowsWidgets?.unregister?.(widgetId)
  },

  /**
   * Handle content request.
   */
  onContentRequested(
    widgetId: string,
    handler: (context: {
      templateType: WidgetTemplateType
      customData?: Record<string, any>
    }) => Promise<WindowsWidgetContent>
  ): void {
    if (!isCraft() || getPlatform() !== 'windows') return
    ;(window as any).craft?.windowsWidgets?.onContentRequested?.(widgetId, handler)
  },

  /**
   * Update widget content.
   */
  async updateContent(widgetId: string, content: WindowsWidgetContent): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.windowsWidgets?.updateContent?.(widgetId, content)
  },

  /**
   * Handle widget action.
   */
  onAction(
    widgetId: string,
    handler: (action: string, data?: Record<string, any>) => void
  ): void {
    if (!isCraft() || getPlatform() !== 'windows') return
    ;(window as any).craft?.windowsWidgets?.onAction?.(widgetId, handler)
  },

  /**
   * Handle customization.
   */
  onCustomize(
    widgetId: string,
    handler: (settings: Record<string, any>) => Promise<void>
  ): void {
    if (!isCraft() || getPlatform() !== 'windows') return
    ;(window as any).craft?.windowsWidgets?.onCustomize?.(widgetId, handler)
  }
}

// ============================================================================
// MSIX Packaging / Auto-Update
// ============================================================================

/**
 * Package version info.
 */
export interface PackageVersion {
  /** Major version */
  major: number
  /** Minor version */
  minor: number
  /** Build version */
  build: number
  /** Revision version */
  revision: number
  /** Full version string */
  full: string
}

/**
 * Update info.
 */
export interface UpdateInfo {
  /** Whether update is available */
  isAvailable: boolean
  /** Whether update is mandatory */
  isMandatory: boolean
  /** New version */
  version?: PackageVersion
  /** Update size in bytes */
  updateSize?: number
}

/**
 * MSIX/Auto-Update API for Windows Store apps.
 *
 * @example
 * // Check for updates
 * const update = await msixUpdate.checkForUpdates()
 * if (update.isAvailable) {
 *   // Download and install
 *   await msixUpdate.downloadAndInstall({
 *     showProgress: true,
 *     restartOnComplete: true
 *   })
 * }
 */
export const msixUpdate = {
  /**
   * Get current package version.
   */
  async getCurrentVersion(): Promise<PackageVersion | null> {
    if (!isCraft() || getPlatform() !== 'windows') return null
    return (window as any).craft?.msixUpdate?.getCurrentVersion?.()
  },

  /**
   * Check for updates.
   */
  async checkForUpdates(): Promise<UpdateInfo> {
    if (!isCraft() || getPlatform() !== 'windows') {
      return { isAvailable: false, isMandatory: false }
    }
    return (window as any).craft?.msixUpdate?.checkForUpdates?.() ?? { isAvailable: false, isMandatory: false }
  },

  /**
   * Download and install update.
   */
  async downloadAndInstall(options?: {
    showProgress?: boolean
    restartOnComplete?: boolean
  }): Promise<{ success: boolean; error?: string }> {
    if (!isCraft() || getPlatform() !== 'windows') {
      return { success: false, error: 'MSIX not available' }
    }
    return (window as any).craft?.msixUpdate?.downloadAndInstall?.(options) ?? { success: false }
  },

  /**
   * Get download progress.
   */
  onDownloadProgress(handler: (progress: {
    bytesDownloaded: number
    totalBytes: number
    percentage: number
  }) => void): void {
    if (!isCraft() || getPlatform() !== 'windows') return
    ;(window as any).craft?.msixUpdate?.onDownloadProgress?.(handler)
  },

  /**
   * Check if running as MSIX package.
   */
  async isPackaged(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'windows') return false
    return (window as any).craft?.msixUpdate?.isPackaged?.() ?? false
  },

  /**
   * Get package install location.
   */
  async getInstallLocation(): Promise<string | null> {
    if (!isCraft() || getPlatform() !== 'windows') return null
    return (window as any).craft?.msixUpdate?.getInstallLocation?.()
  }
}

// ============================================================================
// Share Target
// ============================================================================

/**
 * Shared data item.
 */
export interface SharedDataItem {
  /** Data type */
  type: 'text' | 'uri' | 'html' | 'bitmap' | 'file'
  /** Text content */
  text?: string
  /** URI */
  uri?: string
  /** HTML content */
  html?: string
  /** File path */
  filePath?: string
  /** File name */
  fileName?: string
  /** Content type */
  contentType?: string
}

/**
 * Share Target API for Windows share integration.
 *
 * @example
 * // Handle incoming share
 * shareTarget.onShare(async (items, operation) => {
 *   for (const item of items) {
 *     if (item.type === 'uri') {
 *       await saveBookmark(item.uri)
 *     } else if (item.type === 'file') {
 *       await importFile(item.filePath)
 *     }
 *   }
 *   operation.complete()
 * })
 */
export const shareTarget = {
  /**
   * Handle incoming share.
   */
  onShare(handler: (
    items: SharedDataItem[],
    operation: {
      complete: () => void
      fail: (error: string) => void
    }
  ) => Promise<void>): void {
    if (!isCraft() || getPlatform() !== 'windows') return
    ;(window as any).craft?.shareTarget?.onShare?.(handler)
  },

  /**
   * Check if app was launched as share target.
   */
  async wasLaunchedAsShareTarget(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'windows') return false
    return (window as any).craft?.shareTarget?.wasLaunchedAsShareTarget?.() ?? false
  },

  /**
   * Get shared data if launched as share target.
   */
  async getSharedData(): Promise<SharedDataItem[]> {
    if (!isCraft() || getPlatform() !== 'windows') return []
    return (window as any).craft?.shareTarget?.getSharedData?.() ?? []
  }
}

// ============================================================================
// Startup Tasks
// ============================================================================

/**
 * Startup Task API for Windows launch at startup.
 *
 * @example
 * // Check if startup is enabled
 * const state = await startupTask.getState()
 *
 * // Request startup
 * await startupTask.request()
 *
 * // Disable startup
 * await startupTask.disable()
 */
export const startupTask = {
  /**
   * Get current startup state.
   */
  async getState(): Promise<'disabled' | 'disabledByUser' | 'enabled' | 'disabledByPolicy' | 'enabledByPolicy'> {
    if (!isCraft() || getPlatform() !== 'windows') return 'disabled'
    return (window as any).craft?.startupTask?.getState?.() ?? 'disabled'
  },

  /**
   * Request enabling startup.
   */
  async request(): Promise<'disabled' | 'disabledByUser' | 'enabled' | 'disabledByPolicy' | 'enabledByPolicy'> {
    if (!isCraft() || getPlatform() !== 'windows') return 'disabled'
    return (window as any).craft?.startupTask?.request?.() ?? 'disabled'
  },

  /**
   * Disable startup.
   */
  async disable(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.startupTask?.disable?.()
  }
}

// ============================================================================
// Secondary Tiles
// ============================================================================

/**
 * Secondary tile configuration.
 */
export interface SecondaryTile {
  /** Tile ID */
  tileId: string
  /** Display name */
  displayName: string
  /** Arguments when launched */
  arguments: string
  /** Square 150x150 logo */
  square150x150Logo: string
  /** Wide 310x150 logo */
  wide310x150Logo?: string
  /** Square 310x310 logo */
  square310x310Logo?: string
  /** Background color */
  backgroundColor?: string
  /** Show name on tile */
  showNameOnSquare150x150Logo?: boolean
  /** Show name on wide tile */
  showNameOnWide310x150Logo?: boolean
}

/**
 * Secondary Tiles API for Windows Start menu tiles.
 *
 * @example
 * // Pin a tile
 * await secondaryTiles.pin({
 *   tileId: 'project-123',
 *   displayName: 'My Project',
 *   arguments: '--project 123',
 *   square150x150Logo: 'ms-appx:///Assets/ProjectTile.png'
 * })
 *
 * // Check if pinned
 * const isPinned = await secondaryTiles.exists('project-123')
 *
 * // Update tile
 * await secondaryTiles.updateBadge('project-123', 5)
 */
export const secondaryTiles = {
  /**
   * Check if secondary tiles are supported.
   */
  async isSupported(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'windows') return false
    return (window as any).craft?.secondaryTiles?.isSupported?.() ?? false
  },

  /**
   * Pin a secondary tile.
   */
  async pin(tile: SecondaryTile): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'windows') return false
    return (window as any).craft?.secondaryTiles?.pin?.(tile) ?? false
  },

  /**
   * Unpin a secondary tile.
   */
  async unpin(tileId: string): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'windows') return false
    return (window as any).craft?.secondaryTiles?.unpin?.(tileId) ?? false
  },

  /**
   * Check if a tile exists.
   */
  async exists(tileId: string): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'windows') return false
    return (window as any).craft?.secondaryTiles?.exists?.(tileId) ?? false
  },

  /**
   * Get all pinned tiles.
   */
  async getAll(): Promise<string[]> {
    if (!isCraft() || getPlatform() !== 'windows') return []
    return (window as any).craft?.secondaryTiles?.getAll?.() ?? []
  },

  /**
   * Update tile content.
   */
  async updateTile(tileId: string, content: {
    text1?: string
    text2?: string
    text3?: string
    image?: string
  }): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.secondaryTiles?.updateTile?.(tileId, content)
  },

  /**
   * Update tile badge.
   */
  async updateBadge(tileId: string, value: number | 'none' | 'activity' | 'alert' | 'attention' | 'available' | 'away' | 'busy' | 'newMessage' | 'paused' | 'playing' | 'unavailable' | 'error'): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.secondaryTiles?.updateBadge?.(tileId, value)
  },

  /**
   * Clear tile notification.
   */
  async clearTile(tileId: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'windows') return
    return (window as any).craft?.secondaryTiles?.clearTile?.(tileId)
  },

  /**
   * Handle tile launch.
   */
  onLaunch(handler: (tileId: string, arguments_: string) => void): void {
    if (!isCraft() || getPlatform() !== 'windows') return
    ;(window as any).craft?.secondaryTiles?.onLaunch?.(handler)
  }
}

// ============================================================================
// Exports
// ============================================================================

const windowsAdvanced: {
  jumpList: typeof jumpList
  taskbarProgress: typeof taskbarProgress
  toastNotifications: typeof toastNotifications
  windowsHello: typeof windowsHello
  windowsWidgets: typeof windowsWidgets
  msixUpdate: typeof msixUpdate
  shareTarget: typeof shareTarget
  startupTask: typeof startupTask
  secondaryTiles: typeof secondaryTiles
} = {
  jumpList: jumpList,
  taskbarProgress: taskbarProgress,
  toastNotifications: toastNotifications,
  windowsHello: windowsHello,
  windowsWidgets: windowsWidgets,
  msixUpdate: msixUpdate,
  shareTarget: shareTarget,
  startupTask: startupTask,
  secondaryTiles: secondaryTiles
}

export default windowsAdvanced
