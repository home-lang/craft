/**
 * @fileoverview macOS Advanced Features API
 * @description Advanced macOS-specific features including Touch Bar, Desktop Widgets,
 * Stage Manager, Handoff/Continuity, Sidecar, and system integration.
 * @module @craft/api/macos-advanced
 */

import { isCraft, getPlatform } from './process'

// ============================================================================
// Touch Bar
// ============================================================================

/**
 * Touch Bar item types.
 */
export type TouchBarItemType =
  | 'button'
  | 'label'
  | 'slider'
  | 'popover'
  | 'colorPicker'
  | 'scrubber'
  | 'segmentedControl'
  | 'spacer'
  | 'group'

/**
 * Touch Bar button item.
 */
export interface TouchBarButton {
  type: 'button'
  id: string
  label?: string
  icon?: string // SF Symbol name or image path
  backgroundColor?: string
  accessibilityLabel?: string
}

/**
 * Touch Bar label item.
 */
export interface TouchBarLabel {
  type: 'label'
  id: string
  label: string
  textColor?: string
  accessibilityLabel?: string
}

/**
 * Touch Bar slider item.
 */
export interface TouchBarSlider {
  type: 'slider'
  id: string
  label?: string
  minValue: number
  maxValue: number
  value: number
  minAccessoryIcon?: string
  maxAccessoryIcon?: string
}

/**
 * Touch Bar color picker item.
 */
export interface TouchBarColorPicker {
  type: 'colorPicker'
  id: string
  selectedColor?: string
  availableColors?: string[]
}

/**
 * Touch Bar scrubber item.
 */
export interface TouchBarScrubber {
  type: 'scrubber'
  id: string
  items: Array<{ label?: string; icon?: string }>
  selectedIndex?: number
  mode: 'fixed' | 'free'
  showsArrowButtons?: boolean
}

/**
 * Touch Bar segmented control.
 */
export interface TouchBarSegmentedControl {
  type: 'segmentedControl'
  id: string
  segments: Array<{ label?: string; icon?: string }>
  selectedIndex?: number
  segmentStyle?: 'automatic' | 'rounded' | 'separated'
}

/**
 * Touch Bar popover item.
 */
export interface TouchBarPopover {
  type: 'popover'
  id: string
  label?: string
  icon?: string
  items: TouchBarItem[]
  showCloseButton?: boolean
}

/**
 * Touch Bar spacer.
 */
export interface TouchBarSpacer {
  type: 'spacer'
  size: 'small' | 'large' | 'flexible'
}

/**
 * Touch Bar group.
 */
export interface TouchBarGroup {
  type: 'group'
  id: string
  items: TouchBarItem[]
}

/**
 * Touch Bar item union type.
 */
export type TouchBarItem =
  | TouchBarButton
  | TouchBarLabel
  | TouchBarSlider
  | TouchBarColorPicker
  | TouchBarScrubber
  | TouchBarSegmentedControl
  | TouchBarPopover
  | TouchBarSpacer
  | TouchBarGroup

/**
 * Touch Bar API for MacBook Pro Touch Bar support.
 *
 * @example
 * // Create a Touch Bar
 * touchBar.set([
 *   { type: 'button', id: 'play', icon: 'play.fill' },
 *   { type: 'spacer', size: 'flexible' },
 *   { type: 'slider', id: 'volume', minValue: 0, maxValue: 100, value: 50 },
 *   { type: 'button', id: 'favorite', icon: 'heart.fill', backgroundColor: '#ff375f' }
 * ])
 *
 * // Handle interactions
 * touchBar.onTap('play', () => togglePlayback())
 * touchBar.onSliderChange('volume', (value) => setVolume(value))
 */
export const touchBar = {
  /**
   * Check if Touch Bar is available.
   */
  async isAvailable(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'macos') return false
    return (window as any).craft?.touchBar?.isAvailable?.() ?? false
  },

  /**
   * Set Touch Bar items.
   */
  set(items: TouchBarItem[]): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.touchBar?.set?.(items)
  },

  /**
   * Update a specific item.
   */
  updateItem(id: string, updates: Partial<TouchBarItem>): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.touchBar?.updateItem?.(id, updates)
  },

  /**
   * Clear Touch Bar.
   */
  clear(): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.touchBar?.clear?.()
  },

  /**
   * Register tap handler for button.
   */
  onTap(id: string, handler: () => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.touchBar?.onTap?.(id, handler)
  },

  /**
   * Register slider change handler.
   */
  onSliderChange(id: string, handler: (value: number) => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.touchBar?.onSliderChange?.(id, handler)
  },

  /**
   * Register color picker change handler.
   */
  onColorChange(id: string, handler: (color: string) => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.touchBar?.onColorChange?.(id, handler)
  },

  /**
   * Register scrubber selection handler.
   */
  onScrubberSelect(id: string, handler: (index: number) => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.touchBar?.onScrubberSelect?.(id, handler)
  },

  /**
   * Register segment selection handler.
   */
  onSegmentSelect(id: string, handler: (index: number) => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.touchBar?.onSegmentSelect?.(id, handler)
  },

  /**
   * Show/hide escape key.
   */
  setEscapeKeyVisible(visible: boolean): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.touchBar?.setEscapeKeyVisible?.(visible)
  }
}

// ============================================================================
// Desktop Widgets (WidgetKit)
// ============================================================================

/**
 * Widget family (size).
 */
export type WidgetFamily = 'systemSmall' | 'systemMedium' | 'systemLarge' | 'systemExtraLarge'

/**
 * Widget timeline entry.
 */
export interface WidgetTimelineEntry {
  /** Entry date */
  date: Date
  /** Widget content data */
  content: Record<string, any>
  /** Relevance score (0-1) */
  relevance?: number
}

/**
 * Widget configuration.
 */
export interface WidgetConfiguration {
  /** Widget kind identifier */
  kind: string
  /** Display name */
  displayName: string
  /** Description */
  description: string
  /** Supported families */
  supportedFamilies: WidgetFamily[]
  /** Configuration intent type (for configurable widgets) */
  configurationIntent?: string
}

/**
 * Desktop Widgets API for macOS widgets (WidgetKit).
 *
 * @example
 * // Register a widget
 * desktopWidgets.register({
 *   kind: 'weather',
 *   displayName: 'Weather',
 *   description: 'Shows current weather',
 *   supportedFamilies: ['systemSmall', 'systemMedium']
 * })
 *
 * // Provide timeline
 * desktopWidgets.provideTimeline('weather', async (context) => {
 *   const weather = await fetchWeather()
 *   return {
 *     entries: [
 *       { date: new Date(), content: { temp: weather.temp, condition: weather.condition } }
 *     ],
 *     policy: { type: 'after', date: new Date(Date.now() + 3600000) }
 *   }
 * })
 *
 * // Reload timeline
 * await desktopWidgets.reloadTimeline('weather')
 */
export const desktopWidgets = {
  /**
   * Check if widgets are supported.
   */
  async isSupported(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'macos') return false
    return (window as any).craft?.desktopWidgets?.isSupported?.() ?? false
  },

  /**
   * Register a widget configuration.
   */
  register(config: WidgetConfiguration): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.desktopWidgets?.register?.(config)
  },

  /**
   * Provide timeline for a widget.
   */
  provideTimeline(
    kind: string,
    provider: (context: { family: WidgetFamily; isPreview: boolean }) => Promise<{
      entries: WidgetTimelineEntry[]
      policy: { type: 'atEnd' | 'never' | 'after'; date?: Date }
    }>
  ): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.desktopWidgets?.provideTimeline?.(kind, provider)
  },

  /**
   * Reload timeline for a widget.
   */
  async reloadTimeline(kind: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.desktopWidgets?.reloadTimeline?.(kind)
  },

  /**
   * Reload all timelines.
   */
  async reloadAllTimelines(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.desktopWidgets?.reloadAllTimelines?.()
  },

  /**
   * Get current widget configurations.
   */
  async getCurrentConfigurations(kind: string): Promise<Array<{
    widgetId: string
    family: WidgetFamily
    intent?: Record<string, any>
  }>> {
    if (!isCraft() || getPlatform() !== 'macos') return []
    return (window as any).craft?.desktopWidgets?.getCurrentConfigurations?.(kind) ?? []
  },

  /**
   * Handle widget URL.
   */
  onWidgetURL(kind: string, handler: (url: string, widgetFamily: WidgetFamily) => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.desktopWidgets?.onWidgetURL?.(kind, handler)
  }
}

// ============================================================================
// Stage Manager
// ============================================================================

/**
 * Stage Manager API for window organization.
 *
 * @example
 * // Check if Stage Manager is active
 * const isActive = await stageManager.isActive()
 *
 * // Create a window set (group)
 * await stageManager.createSet(['window1', 'window2'])
 *
 * // Listen for active set changes
 * stageManager.onActiveSetChange((windowIds) => {
 *   console.log('Active set:', windowIds)
 * })
 */
export const stageManager = {
  /**
   * Check if Stage Manager is active.
   */
  async isActive(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'macos') return false
    return (window as any).craft?.stageManager?.isActive?.() ?? false
  },

  /**
   * Check if Stage Manager is available.
   */
  async isAvailable(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'macos') return false
    return (window as any).craft?.stageManager?.isAvailable?.() ?? false
  },

  /**
   * Get the current active window set.
   */
  async getActiveSet(): Promise<string[]> {
    if (!isCraft() || getPlatform() !== 'macos') return []
    return (window as any).craft?.stageManager?.getActiveSet?.() ?? []
  },

  /**
   * Create a window set.
   */
  async createSet(windowIds: string[]): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.stageManager?.createSet?.(windowIds)
  },

  /**
   * Add window to current set.
   */
  async addToCurrentSet(windowId: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.stageManager?.addToCurrentSet?.(windowId)
  },

  /**
   * Remove window from current set.
   */
  async removeFromCurrentSet(windowId: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.stageManager?.removeFromCurrentSet?.(windowId)
  },

  /**
   * Listen for active set changes.
   */
  onActiveSetChange(handler: (windowIds: string[]) => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.stageManager?.onActiveSetChange?.(handler)
  },

  /**
   * Listen for Stage Manager enable/disable.
   */
  onStateChange(handler: (isActive: boolean) => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.stageManager?.onStateChange?.(handler)
  }
}

// ============================================================================
// Handoff / Continuity
// ============================================================================

/**
 * User activity for Handoff.
 */
export interface UserActivity {
  /** Activity type (reverse domain notation) */
  activityType: string
  /** Title shown to user */
  title: string
  /** User info dictionary */
  userInfo?: Record<string, any>
  /** Web page URL for Universal Links */
  webpageURL?: string
  /** Whether activity should be indexed */
  isEligibleForSearch?: boolean
  /** Whether activity should be handed off */
  isEligibleForHandoff?: boolean
  /** Whether activity supports public indexing */
  isEligibleForPublicIndexing?: boolean
  /** Keywords for search */
  keywords?: string[]
  /** Expiration date */
  expirationDate?: Date
}

/**
 * Handoff/Continuity API for cross-device experiences.
 *
 * @example
 * // Start an activity for Handoff
 * handoff.startActivity({
 *   activityType: 'com.myapp.editing-document',
 *   title: 'Editing: My Document',
 *   userInfo: { documentId: '123', scrollPosition: 500 },
 *   webpageURL: 'https://myapp.com/doc/123'
 * })
 *
 * // Handle continuing activity from another device
 * handoff.onContinue((activity) => {
 *   openDocument(activity.userInfo.documentId)
 *   scrollTo(activity.userInfo.scrollPosition)
 * })
 *
 * // Universal Clipboard
 * const hasRemoteContent = await handoff.hasRemoteClipboardContent()
 */
export const handoff = {
  /**
   * Start a user activity for Handoff.
   */
  startActivity(activity: UserActivity): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.handoff?.startActivity?.(activity)
  },

  /**
   * Update the current activity.
   */
  updateActivity(updates: Partial<UserActivity>): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.handoff?.updateActivity?.(updates)
  },

  /**
   * Invalidate (stop) the current activity.
   */
  invalidateActivity(): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.handoff?.invalidateActivity?.()
  },

  /**
   * Handle continuing an activity from another device.
   */
  onContinue(handler: (activity: UserActivity) => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.handoff?.onContinue?.(handler)
  },

  /**
   * Check if there's content on remote clipboard (Universal Clipboard).
   */
  async hasRemoteClipboardContent(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'macos') return false
    return (window as any).craft?.handoff?.hasRemoteClipboardContent?.() ?? false
  },

  /**
   * Request AirDrop file transfer.
   */
  async shareViaAirDrop(filePaths: string[]): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'macos') return false
    return (window as any).craft?.handoff?.shareViaAirDrop?.(filePaths) ?? false
  },

  /**
   * Check if Handoff is available.
   */
  async isAvailable(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'macos') return false
    return (window as any).craft?.handoff?.isAvailable?.() ?? false
  }
}

// ============================================================================
// Sidecar
// ============================================================================

/**
 * Sidecar device info.
 */
export interface SidecarDevice {
  /** Device identifier */
  id: string
  /** Device name */
  name: string
  /** Device model */
  model: string
  /** Whether currently connected */
  isConnected: boolean
}

/**
 * Sidecar API for iPad as second display.
 *
 * @example
 * // Get available Sidecar devices
 * const devices = await sidecar.getAvailableDevices()
 *
 * // Connect to a device
 * await sidecar.connect(devices[0].id)
 *
 * // Move window to Sidecar display
 * await sidecar.moveWindowToSidecar(windowId)
 */
export const sidecar = {
  /**
   * Check if Sidecar is available.
   */
  async isAvailable(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'macos') return false
    return (window as any).craft?.sidecar?.isAvailable?.() ?? false
  },

  /**
   * Get available Sidecar devices.
   */
  async getAvailableDevices(): Promise<SidecarDevice[]> {
    if (!isCraft() || getPlatform() !== 'macos') return []
    return (window as any).craft?.sidecar?.getAvailableDevices?.() ?? []
  },

  /**
   * Get currently connected device.
   */
  async getConnectedDevice(): Promise<SidecarDevice | null> {
    if (!isCraft() || getPlatform() !== 'macos') return null
    return (window as any).craft?.sidecar?.getConnectedDevice?.()
  },

  /**
   * Connect to a Sidecar device.
   */
  async connect(deviceId: string): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'macos') return false
    return (window as any).craft?.sidecar?.connect?.(deviceId) ?? false
  },

  /**
   * Disconnect from Sidecar.
   */
  async disconnect(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.sidecar?.disconnect?.()
  },

  /**
   * Move a window to the Sidecar display.
   */
  async moveWindowToSidecar(windowId: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.sidecar?.moveWindowToSidecar?.(windowId)
  },

  /**
   * Listen for connection changes.
   */
  onConnectionChange(handler: (device: SidecarDevice | null) => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.sidecar?.onConnectionChange?.(handler)
  }
}

// ============================================================================
// Spotlight Integration
// ============================================================================

/**
 * Spotlight searchable item.
 */
export interface SpotlightItem {
  /** Unique identifier */
  uniqueIdentifier: string
  /** Domain identifier (for grouping) */
  domainIdentifier?: string
  /** Display title */
  title: string
  /** Content description */
  contentDescription?: string
  /** Thumbnail URL or path */
  thumbnailURL?: string
  /** Keywords for search */
  keywords?: string[]
  /** Content type (UTI) */
  contentType?: string
  /** URL to open when selected */
  contentURL?: string
  /** Rating (0-5) */
  rating?: number
  /** Relative importance */
  rankingHint?: number
}

/**
 * Spotlight API for search integration.
 *
 * @example
 * // Index items for Spotlight
 * await spotlight.indexItems([
 *   {
 *     uniqueIdentifier: 'doc-123',
 *     title: 'My Document',
 *     contentDescription: 'Important notes about the project',
 *     keywords: ['notes', 'project', 'important']
 *   }
 * ])
 *
 * // Delete items from index
 * await spotlight.deleteItems(['doc-123'])
 *
 * // Handle Spotlight search result selection
 * spotlight.onContinueActivity((identifier) => {
 *   openDocument(identifier)
 * })
 */
export const spotlight = {
  /**
   * Index items for Spotlight search.
   */
  async indexItems(items: SpotlightItem[]): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.spotlight?.indexItems?.(items)
  },

  /**
   * Delete items from Spotlight index.
   */
  async deleteItems(identifiers: string[]): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.spotlight?.deleteItems?.(identifiers)
  },

  /**
   * Delete all items in a domain.
   */
  async deleteItemsInDomain(domainIdentifier: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.spotlight?.deleteItemsInDomain?.(domainIdentifier)
  },

  /**
   * Delete all indexed items.
   */
  async deleteAllItems(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.spotlight?.deleteAllItems?.()
  },

  /**
   * Handle user selecting a Spotlight result.
   */
  onContinueActivity(handler: (identifier: string, userInfo?: Record<string, any>) => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.spotlight?.onContinueActivity?.(handler)
  },

  /**
   * Check indexing status.
   */
  async getIndexingStatus(): Promise<{
    isIndexing: boolean
    itemCount: number
  }> {
    if (!isCraft() || getPlatform() !== 'macos') {
      return { isIndexing: false, itemCount: 0 }
    }
    return (window as any).craft?.spotlight?.getIndexingStatus?.() ?? { isIndexing: false, itemCount: 0 }
  }
}

// ============================================================================
// Quick Actions (Services Menu)
// ============================================================================

/**
 * Quick Action definition.
 */
export interface QuickAction {
  /** Action identifier */
  id: string
  /** Display title */
  title: string
  /** Icon (SF Symbol or path) */
  icon?: string
  /** Input types this action accepts */
  inputTypes: Array<'text' | 'url' | 'file' | 'image'>
}

/**
 * Quick Actions API for Services menu integration.
 *
 * @example
 * // Register a quick action
 * quickActions.register({
 *   id: 'summarize-text',
 *   title: 'Summarize with MyApp',
 *   icon: 'text.alignleft',
 *   inputTypes: ['text']
 * })
 *
 * // Handle quick action invocation
 * quickActions.onInvoke('summarize-text', async (input) => {
 *   const summary = await summarize(input.text)
 *   return { result: summary }
 * })
 */
export const quickActions = {
  /**
   * Register a quick action.
   */
  register(action: QuickAction): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.quickActions?.register?.(action)
  },

  /**
   * Unregister a quick action.
   */
  unregister(actionId: string): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.quickActions?.unregister?.(actionId)
  },

  /**
   * Handle quick action invocation.
   */
  onInvoke(
    actionId: string,
    handler: (input: {
      text?: string
      url?: string
      filePaths?: string[]
    }) => Promise<{ result?: string; error?: string }>
  ): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.quickActions?.onInvoke?.(actionId, handler)
  }
}

// ============================================================================
// Share Extensions
// ============================================================================

/**
 * Share Extension API.
 *
 * @example
 * // Handle share extension invocation
 * shareExtension.onReceive((items) => {
 *   for (const item of items) {
 *     if (item.type === 'url') {
 *       saveBookmark(item.url)
 *     }
 *   }
 * })
 */
export const shareExtension = {
  /**
   * Handle receiving shared items.
   */
  onReceive(handler: (items: Array<{
    type: 'text' | 'url' | 'image' | 'file'
    text?: string
    url?: string
    filePath?: string
    mimeType?: string
  }>) => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.shareExtension?.onReceive?.(handler)
  },

  /**
   * Complete the share action.
   */
  async complete(success = true): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.shareExtension?.complete?.(success)
  },

  /**
   * Cancel the share action.
   */
  async cancel(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.shareExtension?.cancel?.()
  }
}

// ============================================================================
// Window Management
// ============================================================================

/**
 * Window tab group.
 */
export interface WindowTabGroup {
  /** Tab group identifier */
  id: string
  /** Windows in this group */
  windowIds: string[]
  /** Active window index */
  activeIndex: number
}

/**
 * Advanced Window Management API.
 *
 * @example
 * // Enable native tabs
 * windowManagement.enableTabs()
 *
 * // Create a new tab
 * await windowManagement.newTab()
 *
 * // Enter full screen
 * await windowManagement.enterFullScreen()
 *
 * // Set up split view
 * await windowManagement.createSplitView(window1Id, window2Id)
 */
export const windowManagement = {
  /**
   * Enable native window tabs.
   */
  enableTabs(): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.windowManagement?.enableTabs?.()
  },

  /**
   * Disable native window tabs.
   */
  disableTabs(): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.windowManagement?.disableTabs?.()
  },

  /**
   * Create a new tab.
   */
  async newTab(url?: string): Promise<string> {
    if (!isCraft() || getPlatform() !== 'macos') return ''
    return (window as any).craft?.windowManagement?.newTab?.(url) ?? ''
  },

  /**
   * Close current tab.
   */
  async closeTab(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.windowManagement?.closeTab?.()
  },

  /**
   * Get tab groups.
   */
  async getTabGroups(): Promise<WindowTabGroup[]> {
    if (!isCraft() || getPlatform() !== 'macos') return []
    return (window as any).craft?.windowManagement?.getTabGroups?.() ?? []
  },

  /**
   * Select a tab.
   */
  async selectTab(windowId: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.windowManagement?.selectTab?.(windowId)
  },

  /**
   * Move tab to new window.
   */
  async moveTabToNewWindow(windowId: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.windowManagement?.moveTabToNewWindow?.(windowId)
  },

  /**
   * Merge all windows.
   */
  async mergeAllWindows(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.windowManagement?.mergeAllWindows?.()
  },

  /**
   * Enter full screen mode.
   */
  async enterFullScreen(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.windowManagement?.enterFullScreen?.()
  },

  /**
   * Exit full screen mode.
   */
  async exitFullScreen(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.windowManagement?.exitFullScreen?.()
  },

  /**
   * Toggle full screen.
   */
  async toggleFullScreen(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.windowManagement?.toggleFullScreen?.()
  },

  /**
   * Create split view with two windows.
   */
  async createSplitView(leftWindowId: string, rightWindowId: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.windowManagement?.createSplitView?.(leftWindowId, rightWindowId)
  },

  /**
   * Exit split view.
   */
  async exitSplitView(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.windowManagement?.exitSplitView?.()
  },

  /**
   * Tile window to left half.
   */
  async tileLeft(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.windowManagement?.tileLeft?.()
  },

  /**
   * Tile window to right half.
   */
  async tileRight(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.windowManagement?.tileRight?.()
  },

  /**
   * Move window to space.
   */
  async moveToSpace(spaceIndex: number): Promise<void> {
    if (!isCraft() || getPlatform() !== 'macos') return
    return (window as any).craft?.windowManagement?.moveToSpace?.(spaceIndex)
  },

  /**
   * Register tab change handler.
   */
  onTabChange(handler: (tabGroup: WindowTabGroup) => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.windowManagement?.onTabChange?.(handler)
  },

  /**
   * Register full screen change handler.
   */
  onFullScreenChange(handler: (isFullScreen: boolean) => void): void {
    if (!isCraft() || getPlatform() !== 'macos') return
    ;(window as any).craft?.windowManagement?.onFullScreenChange?.(handler)
  }
}

// ============================================================================
// Exports
// ============================================================================

const macosAdvanced: {
  touchBar: typeof touchBar
  desktopWidgets: typeof desktopWidgets
  stageManager: typeof stageManager
  handoff: typeof handoff
  sidecar: typeof sidecar
  spotlight: typeof spotlight
  quickActions: typeof quickActions
  shareExtension: typeof shareExtension
  windowManagement: typeof windowManagement
} = {
  touchBar: touchBar,
  desktopWidgets: desktopWidgets,
  stageManager: stageManager,
  handoff: handoff,
  sidecar: sidecar,
  spotlight: spotlight,
  quickActions: quickActions,
  shareExtension: shareExtension,
  windowManagement: windowManagement
}

export default macosAdvanced
