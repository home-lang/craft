/**
 * @fileoverview Android Advanced Features API
 * @description Advanced Android-specific features including Jetpack Compose integration,
 * Material You dynamic colors, Photo Picker, Work Manager, Foreground Services, and more.
 * @module @craft/api/android-advanced
 */

import { isCraft, getPlatform } from './process'

// ============================================================================
// Material You / Dynamic Colors
// ============================================================================

/**
 * Material You color scheme.
 */
export interface MaterialYouColors {
  /** Primary color */
  primary: string
  /** On primary color */
  onPrimary: string
  /** Primary container */
  primaryContainer: string
  /** On primary container */
  onPrimaryContainer: string
  /** Secondary color */
  secondary: string
  /** On secondary */
  onSecondary: string
  /** Secondary container */
  secondaryContainer: string
  /** On secondary container */
  onSecondaryContainer: string
  /** Tertiary color */
  tertiary: string
  /** On tertiary */
  onTertiary: string
  /** Tertiary container */
  tertiaryContainer: string
  /** On tertiary container */
  onTertiaryContainer: string
  /** Error color */
  error: string
  /** On error */
  onError: string
  /** Error container */
  errorContainer: string
  /** On error container */
  onErrorContainer: string
  /** Background */
  background: string
  /** On background */
  onBackground: string
  /** Surface */
  surface: string
  /** On surface */
  onSurface: string
  /** Surface variant */
  surfaceVariant: string
  /** On surface variant */
  onSurfaceVariant: string
  /** Outline */
  outline: string
  /** Outline variant */
  outlineVariant: string
}

/**
 * Material You API for dynamic theming.
 *
 * @example
 * // Get current dynamic colors
 * const colors = await materialYou.getColors()
 * document.body.style.backgroundColor = colors.background
 *
 * // Listen for wallpaper changes
 * materialYou.onColorsChange((colors) => {
 *   applyTheme(colors)
 * })
 */
export const materialYou = {
  /**
   * Check if Material You is supported.
   */
  async isSupported(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'android') return false
    return (window as any).craft?.materialYou?.isSupported?.() ?? false
  },

  /**
   * Get current dynamic colors.
   */
  async getColors(darkMode = false): Promise<MaterialYouColors | null> {
    if (!isCraft() || getPlatform() !== 'android') return null
    return (window as any).craft?.materialYou?.getColors?.(darkMode)
  },

  /**
   * Get colors from a specific source.
   */
  async getColorsFromSource(source: 'wallpaper' | 'content'): Promise<MaterialYouColors | null> {
    if (!isCraft() || getPlatform() !== 'android') return null
    return (window as any).craft?.materialYou?.getColorsFromSource?.(source)
  },

  /**
   * Listen for color changes.
   */
  onColorsChange(handler: (colors: MaterialYouColors) => void): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.materialYou?.onColorsChange?.(handler)
  },

  /**
   * Apply dynamic colors to system bars.
   */
  async applyToSystemBars(colors?: {
    statusBarColor?: string
    navigationBarColor?: string
    lightStatusBar?: boolean
    lightNavigationBar?: boolean
  }): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.materialYou?.applyToSystemBars?.(colors)
  },

  /**
   * Generate color scheme from seed color.
   */
  async generateScheme(seedColor: string, darkMode = false): Promise<MaterialYouColors | null> {
    if (!isCraft() || getPlatform() !== 'android') return null
    return (window as any).craft?.materialYou?.generateScheme?.(seedColor, darkMode)
  }
}

// ============================================================================
// Photo Picker (Android 13+)
// ============================================================================

/**
 * Photo picker media type.
 */
export type PhotoPickerMediaType = 'images' | 'videos' | 'all'

/**
 * Selected media item.
 */
export interface PhotoPickerResult {
  /** Content URI */
  uri: string
  /** MIME type */
  mimeType: string
  /** File name */
  name: string
  /** File size in bytes */
  size: number
  /** Width (for images/videos) */
  width?: number
  /** Height (for images/videos) */
  height?: number
  /** Duration in ms (for videos) */
  duration?: number
  /** Date taken */
  dateTaken?: Date
}

/**
 * Photo Picker API for Android 13+ privacy-preserving media selection.
 *
 * @example
 * // Pick a single image
 * const photo = await photoPicker.pickImage()
 *
 * // Pick multiple images (up to 10)
 * const photos = await photoPicker.pickImages(10)
 *
 * // Pick a video
 * const video = await photoPicker.pickVideo()
 */
export const photoPicker = {
  /**
   * Check if Photo Picker is available (Android 13+).
   */
  async isAvailable(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'android') return false
    return (window as any).craft?.photoPicker?.isAvailable?.() ?? false
  },

  /**
   * Pick a single image.
   */
  async pickImage(): Promise<PhotoPickerResult | null> {
    if (!isCraft() || getPlatform() !== 'android') return null
    return (window as any).craft?.photoPicker?.pickImage?.()
  },

  /**
   * Pick multiple images.
   */
  async pickImages(maxCount = 10): Promise<PhotoPickerResult[]> {
    if (!isCraft() || getPlatform() !== 'android') return []
    return (window as any).craft?.photoPicker?.pickImages?.(maxCount) ?? []
  },

  /**
   * Pick a single video.
   */
  async pickVideo(): Promise<PhotoPickerResult | null> {
    if (!isCraft() || getPlatform() !== 'android') return null
    return (window as any).craft?.photoPicker?.pickVideo?.()
  },

  /**
   * Pick multiple videos.
   */
  async pickVideos(maxCount = 10): Promise<PhotoPickerResult[]> {
    if (!isCraft() || getPlatform() !== 'android') return []
    return (window as any).craft?.photoPicker?.pickVideos?.(maxCount) ?? []
  },

  /**
   * Pick mixed media (images and videos).
   */
  async pickMedia(options?: {
    maxCount?: number
    mediaType?: PhotoPickerMediaType
  }): Promise<PhotoPickerResult[]> {
    if (!isCraft() || getPlatform() !== 'android') return []
    return (window as any).craft?.photoPicker?.pickMedia?.(options) ?? []
  },

  /**
   * Get a persistent URI for the selected media.
   * Takes a content URI and returns a file path that can be used after app restart.
   */
  async getPersistedUri(uri: string): Promise<string | null> {
    if (!isCraft() || getPlatform() !== 'android') return null
    return (window as any).craft?.photoPicker?.getPersistedUri?.(uri)
  }
}

// ============================================================================
// Work Manager
// ============================================================================

/**
 * Work request constraints.
 */
export interface WorkConstraints {
  /** Require network connectivity */
  requiresNetwork?: 'connected' | 'unmetered' | 'not_roaming' | 'metered'
  /** Require charging */
  requiresCharging?: boolean
  /** Require device idle */
  requiresDeviceIdle?: boolean
  /** Require battery not low */
  requiresBatteryNotLow?: boolean
  /** Require storage not low */
  requiresStorageNotLow?: boolean
}

/**
 * Work request configuration.
 */
export interface WorkRequest {
  /** Unique work name */
  name: string
  /** Work type */
  type: 'oneTime' | 'periodic'
  /** Input data */
  inputData?: Record<string, string | number | boolean>
  /** Constraints */
  constraints?: WorkConstraints
  /** Initial delay in milliseconds */
  initialDelay?: number
  /** Repeat interval in milliseconds (for periodic work) */
  repeatInterval?: number
  /** Flex interval in milliseconds (for periodic work) */
  flexInterval?: number
  /** Backoff policy */
  backoffPolicy?: {
    policy: 'linear' | 'exponential'
    delayMs: number
  }
  /** Tags for grouping */
  tags?: string[]
  /** Expedited work (Android 12+) */
  expedited?: boolean
}

/**
 * Work info.
 */
export interface WorkInfo {
  /** Work ID */
  id: string
  /** Work name */
  name: string
  /** Current state */
  state: 'enqueued' | 'running' | 'succeeded' | 'failed' | 'blocked' | 'cancelled'
  /** Output data */
  outputData?: Record<string, any>
  /** Run attempt count */
  runAttemptCount: number
  /** Tags */
  tags: string[]
  /** Progress (0-100) */
  progress?: number
}

/**
 * Work Manager API for background task scheduling.
 *
 * @example
 * // Schedule a one-time sync task
 * await workManager.enqueue({
 *   name: 'sync-data',
 *   type: 'oneTime',
 *   constraints: {
 *     requiresNetwork: 'connected'
 *   },
 *   inputData: { userId: '123' }
 * })
 *
 * // Schedule periodic cleanup
 * await workManager.enqueue({
 *   name: 'cleanup',
 *   type: 'periodic',
 *   repeatInterval: 24 * 60 * 60 * 1000, // Daily
 *   constraints: {
 *     requiresCharging: true,
 *     requiresDeviceIdle: true
 *   }
 * })
 *
 * // Monitor work progress
 * workManager.observeWork('sync-data', (info) => {
 *   console.log('State:', info.state, 'Progress:', info.progress)
 * })
 */
export const workManager = {
  /**
   * Enqueue a work request.
   */
  async enqueue(request: WorkRequest): Promise<string> {
    if (!isCraft() || getPlatform() !== 'android') {
      return `mock-${Date.now()}`
    }
    return (window as any).craft?.workManager?.enqueue?.(request) ?? `mock-${Date.now()}`
  },

  /**
   * Enqueue unique work (replaces existing work with same name).
   */
  async enqueueUnique(
    request: WorkRequest,
    existingWorkPolicy: 'replace' | 'keep' | 'append' | 'update'
  ): Promise<string> {
    if (!isCraft() || getPlatform() !== 'android') {
      return `mock-${Date.now()}`
    }
    return (window as any).craft?.workManager?.enqueueUnique?.(request, existingWorkPolicy) ?? `mock-${Date.now()}`
  },

  /**
   * Cancel work by name.
   */
  async cancelByName(name: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.workManager?.cancelByName?.(name)
  },

  /**
   * Cancel work by ID.
   */
  async cancelById(id: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.workManager?.cancelById?.(id)
  },

  /**
   * Cancel work by tag.
   */
  async cancelByTag(tag: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.workManager?.cancelByTag?.(tag)
  },

  /**
   * Cancel all work.
   */
  async cancelAll(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.workManager?.cancelAll?.()
  },

  /**
   * Get work info by name.
   */
  async getWorkInfo(name: string): Promise<WorkInfo | null> {
    if (!isCraft() || getPlatform() !== 'android') return null
    return (window as any).craft?.workManager?.getWorkInfo?.(name)
  },

  /**
   * Get work info by ID.
   */
  async getWorkInfoById(id: string): Promise<WorkInfo | null> {
    if (!isCraft() || getPlatform() !== 'android') return null
    return (window as any).craft?.workManager?.getWorkInfoById?.(id)
  },

  /**
   * Get work info by tag.
   */
  async getWorkInfoByTag(tag: string): Promise<WorkInfo[]> {
    if (!isCraft() || getPlatform() !== 'android') return []
    return (window as any).craft?.workManager?.getWorkInfoByTag?.(tag) ?? []
  },

  /**
   * Observe work by name.
   */
  observeWork(name: string, handler: (info: WorkInfo) => void): () => void {
    if (!isCraft() || getPlatform() !== 'android') return () => {}
    return (window as any).craft?.workManager?.observeWork?.(name, handler) ?? (() => {})
  },

  /**
   * Prune finished work from database.
   */
  async pruneWork(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.workManager?.pruneWork?.()
  },

  /**
   * Register work handler (called when work executes).
   */
  onWork(name: string, handler: (
    inputData: Record<string, any>,
    setProgress: (progress: number) => void
  ) => Promise<{ success: boolean; outputData?: Record<string, any> }>): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.workManager?.onWork?.(name, handler)
  }
}

// ============================================================================
// Foreground Services
// ============================================================================

/**
 * Foreground service type.
 */
export type ForegroundServiceType =
  | 'camera'
  | 'connectedDevice'
  | 'dataSync'
  | 'health'
  | 'location'
  | 'mediaPlayback'
  | 'mediaProjection'
  | 'microphone'
  | 'phoneCall'
  | 'remoteMessaging'
  | 'shortService'
  | 'specialUse'
  | 'systemExempted'

/**
 * Notification configuration for foreground service.
 */
export interface ForegroundNotification {
  /** Notification channel ID */
  channelId: string
  /** Notification ID */
  notificationId: number
  /** Title */
  title: string
  /** Content text */
  content: string
  /** Small icon resource name */
  smallIcon: string
  /** Large icon URL */
  largeIcon?: string
  /** Ongoing (can't be dismissed) */
  ongoing?: boolean
  /** Actions */
  actions?: Array<{
    id: string
    title: string
    icon?: string
  }>
  /** Progress (for determinate progress) */
  progress?: {
    max: number
    current: number
    indeterminate?: boolean
  }
}

/**
 * Foreground Services API for long-running operations.
 *
 * @example
 * // Start a media playback service
 * await foregroundService.start({
 *   type: 'mediaPlayback',
 *   notification: {
 *     channelId: 'playback',
 *     notificationId: 1,
 *     title: 'Now Playing',
 *     content: 'Song Name - Artist',
 *     smallIcon: 'ic_music_note',
 *     actions: [
 *       { id: 'pause', title: 'Pause', icon: 'ic_pause' },
 *       { id: 'next', title: 'Next', icon: 'ic_skip_next' }
 *     ]
 *   }
 * })
 *
 * // Handle notification actions
 * foregroundService.onAction((actionId) => {
 *   if (actionId === 'pause') pausePlayback()
 * })
 *
 * // Stop the service
 * await foregroundService.stop()
 */
export const foregroundService = {
  /**
   * Start a foreground service.
   */
  async start(config: {
    type: ForegroundServiceType
    notification: ForegroundNotification
  }): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.foregroundService?.start?.(config)
  },

  /**
   * Stop the foreground service.
   */
  async stop(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.foregroundService?.stop?.()
  },

  /**
   * Update notification.
   */
  async updateNotification(notification: Partial<ForegroundNotification>): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.foregroundService?.updateNotification?.(notification)
  },

  /**
   * Check if service is running.
   */
  async isRunning(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'android') return false
    return (window as any).craft?.foregroundService?.isRunning?.() ?? false
  },

  /**
   * Register notification action handler.
   */
  onAction(handler: (actionId: string) => void): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.foregroundService?.onAction?.(handler)
  }
}

// ============================================================================
// Predictive Back Gesture
// ============================================================================

/**
 * Back event info.
 */
export interface BackEvent {
  /** Touch X position */
  touchX: number
  /** Touch Y position */
  touchY: number
  /** Progress of the back gesture (0-1) */
  progress: number
  /** Swipe edge: 0 = left, 1 = right */
  swipeEdge: 0 | 1
}

/**
 * Predictive Back API for Android 13+ back gesture handling.
 *
 * @example
 * // Enable predictive back
 * predictiveBack.enable()
 *
 * // Handle back progress for animations
 * predictiveBack.onProgress((event) => {
 *   // Animate UI based on progress
 *   element.style.transform = `translateX(${event.progress * -100}px)`
 * })
 *
 * // Handle back committed
 * predictiveBack.onCommit(() => {
 *   navigateBack()
 * })
 */
export const predictiveBack = {
  /**
   * Check if predictive back is supported.
   */
  async isSupported(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'android') return false
    return (window as any).craft?.predictiveBack?.isSupported?.() ?? false
  },

  /**
   * Enable predictive back handling.
   */
  enable(): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.predictiveBack?.enable?.()
  },

  /**
   * Disable predictive back handling.
   */
  disable(): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.predictiveBack?.disable?.()
  },

  /**
   * Register back started handler.
   */
  onStart(handler: (event: BackEvent) => void): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.predictiveBack?.onStart?.(handler)
  },

  /**
   * Register back progress handler.
   */
  onProgress(handler: (event: BackEvent) => void): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.predictiveBack?.onProgress?.(handler)
  },

  /**
   * Register back committed handler.
   */
  onCommit(handler: () => void): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.predictiveBack?.onCommit?.()
  },

  /**
   * Register back cancelled handler.
   */
  onCancel(handler: () => void): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.predictiveBack?.onCancel?.(handler)
  }
}

// ============================================================================
// Per-App Language Preferences
// ============================================================================

/**
 * Language Preferences API for per-app language settings (Android 13+).
 *
 * @example
 * // Get available languages
 * const languages = await appLanguage.getAvailableLanguages()
 *
 * // Set app language
 * await appLanguage.setLanguage('es')
 *
 * // Get current language
 * const current = await appLanguage.getCurrentLanguage()
 */
export const appLanguage = {
  /**
   * Check if per-app language is supported.
   */
  async isSupported(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'android') return false
    return (window as any).craft?.appLanguage?.isSupported?.() ?? false
  },

  /**
   * Get available languages defined in app.
   */
  async getAvailableLanguages(): Promise<string[]> {
    if (!isCraft() || getPlatform() !== 'android') return []
    return (window as any).craft?.appLanguage?.getAvailableLanguages?.() ?? []
  },

  /**
   * Get current app language.
   */
  async getCurrentLanguage(): Promise<string | null> {
    if (!isCraft() || getPlatform() !== 'android') return null
    return (window as any).craft?.appLanguage?.getCurrentLanguage?.()
  },

  /**
   * Set app language.
   */
  async setLanguage(languageTag: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.appLanguage?.setLanguage?.(languageTag)
  },

  /**
   * Reset to system language.
   */
  async resetToSystem(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.appLanguage?.resetToSystem?.()
  },

  /**
   * Open system language settings for this app.
   */
  async openSettings(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.appLanguage?.openSettings?.()
  }
}

// ============================================================================
// App Widgets
// ============================================================================

/**
 * Widget size class.
 */
export type WidgetSizeClass = 'small' | 'medium' | 'large' | 'extraLarge'

/**
 * Widget configuration.
 */
export interface WidgetConfig {
  /** Widget class name */
  widgetClass: string
  /** Minimum width in dp */
  minWidth: number
  /** Minimum height in dp */
  minHeight: number
  /** Target cell width */
  targetCellWidth?: number
  /** Target cell height */
  targetCellHeight?: number
  /** Maximum resize width */
  maxResizeWidth?: number
  /** Maximum resize height */
  maxResizeHeight?: number
  /** Update period in milliseconds (minimum 30 minutes) */
  updatePeriodMs?: number
  /** Whether widget is resizable */
  resizable?: boolean
  /** Widget category */
  category?: 'homeScreen' | 'keyguard' | 'searchBox'
}

/**
 * Widget data.
 */
export interface WidgetData {
  /** Widget ID */
  widgetId: number
  /** Widget data */
  data: Record<string, any>
}

/**
 * App Widgets API for home screen widgets.
 *
 * @example
 * // Update widget content
 * await widgets.updateWidget(widgetId, {
 *   title: 'Weather',
 *   temperature: '72°F',
 *   icon: 'sunny'
 * })
 *
 * // Request widget pin
 * await widgets.requestPin('WeatherWidget')
 *
 * // Handle widget interactions
 * widgets.onInteraction((widgetId, action) => {
 *   if (action === 'refresh') {
 *     refreshWeatherData()
 *   }
 * })
 */
export const widgets = {
  /**
   * Get all active widget IDs for a widget class.
   */
  async getActiveWidgets(widgetClass: string): Promise<number[]> {
    if (!isCraft() || getPlatform() !== 'android') return []
    return (window as any).craft?.widgets?.getActiveWidgets?.(widgetClass) ?? []
  },

  /**
   * Update a widget.
   */
  async updateWidget(widgetId: number, data: Record<string, any>): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.widgets?.updateWidget?.(widgetId, data)
  },

  /**
   * Update all widgets of a class.
   */
  async updateAllWidgets(widgetClass: string, data: Record<string, any>): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.widgets?.updateAllWidgets?.(widgetClass, data)
  },

  /**
   * Request to pin a widget to home screen.
   */
  async requestPin(widgetClass: string): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'android') return false
    return (window as any).craft?.widgets?.requestPin?.(widgetClass) ?? false
  },

  /**
   * Check if app widgets are supported.
   */
  async isSupported(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'android') return false
    return (window as any).craft?.widgets?.isSupported?.() ?? false
  },

  /**
   * Register widget update handler.
   */
  onUpdate(widgetClass: string, handler: (widgetIds: number[]) => void): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.widgets?.onUpdate?.(widgetClass, handler)
  },

  /**
   * Register widget interaction handler.
   */
  onInteraction(handler: (widgetId: number, action: string, extras?: Record<string, any>) => void): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.widgets?.onInteraction?.(handler)
  },

  /**
   * Register widget resize handler.
   */
  onResize(handler: (widgetId: number, width: number, height: number) => void): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.widgets?.onResize?.(handler)
  },

  /**
   * Register widget delete handler.
   */
  onDelete(handler: (widgetId: number) => void): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.widgets?.onDelete?.(handler)
  }
}

// ============================================================================
// Google Play Billing
// ============================================================================

/**
 * Product details from Google Play.
 */
export interface PlayProduct {
  /** Product ID */
  productId: string
  /** Product type */
  productType: 'inapp' | 'subs'
  /** Title */
  title: string
  /** Name */
  name: string
  /** Description */
  description: string
  /** One-time purchase offer (for inapp) */
  oneTimePurchaseOfferDetails?: {
    formattedPrice: string
    priceAmountMicros: number
    priceCurrencyCode: string
  }
  /** Subscription offer details (for subs) */
  subscriptionOfferDetails?: Array<{
    offerId: string
    basePlanId: string
    offerTags: string[]
    pricingPhases: Array<{
      formattedPrice: string
      priceAmountMicros: number
      priceCurrencyCode: string
      billingPeriod: string
      billingCycleCount: number
      recurrenceMode: 'infinite' | 'finite' | 'nonRecurring'
    }>
  }>
}

/**
 * Purchase result.
 */
export interface PlayPurchase {
  /** Order ID */
  orderId: string
  /** Package name */
  packageName: string
  /** Product IDs */
  products: string[]
  /** Purchase time */
  purchaseTime: number
  /** Purchase state */
  purchaseState: 'purchased' | 'pending' | 'unspecified'
  /** Purchase token */
  purchaseToken: string
  /** Whether acknowledged */
  isAcknowledged: boolean
  /** Whether auto-renewing */
  isAutoRenewing: boolean
}

/**
 * Google Play Billing API.
 *
 * @example
 * // Query products
 * const products = await playBilling.getProducts(['premium', 'coins_100'], 'inapp')
 *
 * // Launch purchase flow
 * const result = await playBilling.purchase('premium')
 *
 * // Check purchases
 * const purchases = await playBilling.getPurchases('inapp')
 */
export const playBilling = {
  /**
   * Connect to billing service.
   */
  async connect(): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'android') return false
    return (window as any).craft?.playBilling?.connect?.() ?? false
  },

  /**
   * Disconnect from billing service.
   */
  async disconnect(): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.playBilling?.disconnect?.()
  },

  /**
   * Query product details.
   */
  async getProducts(productIds: string[], productType: 'inapp' | 'subs'): Promise<PlayProduct[]> {
    if (!isCraft() || getPlatform() !== 'android') return []
    return (window as any).craft?.playBilling?.getProducts?.(productIds, productType) ?? []
  },

  /**
   * Launch purchase flow.
   */
  async purchase(productId: string, options?: {
    offerToken?: string
    isOfferPersonalized?: boolean
    oldPurchaseToken?: string
    replacementMode?: 'charge_prorated_price' | 'charge_full_price' | 'without_proration' | 'deferred'
  }): Promise<{ success: boolean; purchase?: PlayPurchase; error?: string }> {
    if (!isCraft() || getPlatform() !== 'android') {
      return { success: false, error: 'Play Billing not available' }
    }
    return (window as any).craft?.playBilling?.purchase?.(productId, options) ?? { success: false }
  },

  /**
   * Get purchases.
   */
  async getPurchases(productType: 'inapp' | 'subs'): Promise<PlayPurchase[]> {
    if (!isCraft() || getPlatform() !== 'android') return []
    return (window as any).craft?.playBilling?.getPurchases?.(productType) ?? []
  },

  /**
   * Acknowledge a purchase.
   */
  async acknowledgePurchase(purchaseToken: string): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'android') return false
    return (window as any).craft?.playBilling?.acknowledgePurchase?.(purchaseToken) ?? false
  },

  /**
   * Consume a purchase (for consumables).
   */
  async consumePurchase(purchaseToken: string): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'android') return false
    return (window as any).craft?.playBilling?.consumePurchase?.(purchaseToken) ?? false
  },

  /**
   * Check subscription status.
   */
  async isSubscribed(productId: string): Promise<boolean> {
    if (!isCraft() || getPlatform() !== 'android') return false
    return (window as any).craft?.playBilling?.isSubscribed?.(productId) ?? false
  },

  /**
   * Listen for purchases updates.
   */
  onPurchasesUpdated(handler: (purchases: PlayPurchase[]) => void): void {
    if (!isCraft() || getPlatform() !== 'android') return
    ;(window as any).craft?.playBilling?.onPurchasesUpdated?.(handler)
  },

  /**
   * Show subscription management.
   */
  async showSubscriptionManagement(productId?: string): Promise<void> {
    if (!isCraft() || getPlatform() !== 'android') return
    return (window as any).craft?.playBilling?.showSubscriptionManagement?.(productId)
  }
}

// ============================================================================
// Exports
// ============================================================================

export default {
  materialYou,
  photoPicker,
  workManager,
  foregroundService,
  predictiveBack,
  appLanguage,
  widgets,
  playBilling
}
