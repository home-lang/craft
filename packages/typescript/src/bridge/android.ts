/**
 * Craft Android Bridge
 * Complete Android native bridge with WebView, permissions, and platform APIs
 */

// Types
export interface AndroidWebViewConfig {
  url?: string
  html?: string
  javaScriptEnabled?: boolean
  domStorageEnabled?: boolean
  allowFileAccess?: boolean
  allowContentAccess?: boolean
  mediaPlaybackRequiresUserGesture?: boolean
  supportZoom?: boolean
  builtInZoomControls?: boolean
  displayZoomControls?: boolean
  cacheMode?: 'default' | 'noCache' | 'cacheOnly' | 'cacheElseNetwork'
  mixedContentMode?: 'never' | 'always' | 'compatibility'
  safeBrowsingEnabled?: boolean
}

export interface AndroidPermission {
  type:
    | 'camera'
    | 'microphone'
    | 'readStorage'
    | 'writeStorage'
    | 'location'
    | 'fineLocation'
    | 'backgroundLocation'
    | 'contacts'
    | 'calendar'
    | 'phone'
    | 'sms'
    | 'bluetooth'
    | 'bluetoothConnect'
    | 'bluetoothScan'
    | 'bluetoothAdvertise'
    | 'notifications'
    | 'bodySensors'
    | 'activityRecognition'
    | 'nearbyWifiDevices'
    | 'readMediaImages'
    | 'readMediaVideo'
    | 'readMediaAudio'
  status: 'granted' | 'denied' | 'shouldShowRationale'
}

export interface AndroidBiometricConfig {
  title: string
  subtitle?: string
  description?: string
  negativeButtonText: string
  allowedAuthenticators?: ('biometricStrong' | 'biometricWeak' | 'deviceCredential')[]
}

export interface AndroidNotificationChannel {
  id: string
  name: string
  description?: string
  importance: 'none' | 'min' | 'low' | 'default' | 'high' | 'max'
  enableLights?: boolean
  lightColor?: string
  enableVibration?: boolean
  vibrationPattern?: number[]
  showBadge?: boolean
  sound?: string
  bypassDnd?: boolean
}

export interface AndroidNotification {
  channelId: string
  id: number
  title: string
  body: string
  smallIcon: string
  largeIcon?: string
  color?: string
  autoCancel?: boolean
  ongoing?: boolean
  priority?: 'min' | 'low' | 'default' | 'high' | 'max'
  category?: 'alarm' | 'call' | 'email' | 'error' | 'event' | 'message' | 'progress' | 'promo' | 'recommendation' | 'reminder' | 'service' | 'social' | 'status' | 'system' | 'transport'
  visibility?: 'public' | 'private' | 'secret'
  actions?: Array<{ action: string; title: string; icon?: string }>
  bigTextStyle?: { bigText: string; contentTitle?: string; summaryText?: string }
  bigPictureStyle?: { picture: string; contentTitle?: string; summaryText?: string; largeIcon?: string }
  inboxStyle?: { lines: string[]; contentTitle?: string; summaryText?: string }
}

export interface AndroidMaterialYouColors {
  primary: string
  onPrimary: string
  primaryContainer: string
  onPrimaryContainer: string
  secondary: string
  onSecondary: string
  secondaryContainer: string
  onSecondaryContainer: string
  tertiary: string
  onTertiary: string
  tertiaryContainer: string
  onTertiaryContainer: string
  error: string
  onError: string
  errorContainer: string
  onErrorContainer: string
  background: string
  onBackground: string
  surface: string
  onSurface: string
  surfaceVariant: string
  onSurfaceVariant: string
  outline: string
  outlineVariant: string
}

export interface AndroidWidget {
  widgetId: string
  className: string
  updatePeriodMillis?: number
  initialLayout: string
}

export interface AndroidWorkRequest {
  id: string
  workerClass: string
  inputData?: Record<string, unknown>
  constraints?: {
    networkType?: 'connected' | 'unmetered' | 'notRoaming' | 'metered'
    requiresCharging?: boolean
    requiresDeviceIdle?: boolean
    requiresBatteryNotLow?: boolean
    requiresStorageNotLow?: boolean
  }
  backoffPolicy?: { policy: 'linear' | 'exponential'; delay: number }
  tags?: string[]
}

// Android WebView Bridge
export class AndroidWebView {
  private id: string
  private config: AndroidWebViewConfig

  constructor(config: AndroidWebViewConfig = {}) {
    this.id = `webview_${Date.now()}_${Math.random().toString(36).slice(2)}`
    this.config = config
  }

  /**
   * Create the WebView
   */
  async create(): Promise<void> {
    await this.callNative('createWebView', {
      id: this.id,
      config: this.config,
    })
  }

  /**
   * Load a URL
   */
  async loadURL(url: string, headers?: Record<string, string>): Promise<void> {
    await this.callNative('loadURL', { id: this.id, url, headers })
  }

  /**
   * Load HTML content
   */
  async loadHTML(html: string, baseUrl?: string, mimeType?: string): Promise<void> {
    await this.callNative('loadHTML', { id: this.id, html, baseUrl, mimeType })
  }

  /**
   * Evaluate JavaScript
   */
  async evaluateJavaScript<T = unknown>(script: string): Promise<T> {
    return this.callNative('evaluateJavaScript', { id: this.id, script })
  }

  /**
   * Go back in history
   */
  async goBack(): Promise<void> {
    await this.callNative('goBack', { id: this.id })
  }

  /**
   * Go forward in history
   */
  async goForward(): Promise<void> {
    await this.callNative('goForward', { id: this.id })
  }

  /**
   * Reload the page
   */
  async reload(): Promise<void> {
    await this.callNative('reload', { id: this.id })
  }

  /**
   * Stop loading
   */
  async stopLoading(): Promise<void> {
    await this.callNative('stopLoading', { id: this.id })
  }

  /**
   * Clear cache
   */
  async clearCache(includeDiskFiles = true): Promise<void> {
    await this.callNative('clearCache', { id: this.id, includeDiskFiles })
  }

  /**
   * Destroy the WebView
   */
  async destroy(): Promise<void> {
    await this.callNative('destroyWebView', { id: this.id })
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}_${Math.random().toString(36).slice(2)}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    console.warn(`[AndroidBridge] ${method} called but not in Android WebView context`)
    return undefined as T
  }
}

// Android Permissions
export class AndroidPermissions {
  /**
   * Check permission status
   */
  async check(type: AndroidPermission['type']): Promise<AndroidPermission['status']> {
    return this.callNative('checkPermission', { type })
  }

  /**
   * Request single permission
   */
  async request(type: AndroidPermission['type']): Promise<AndroidPermission['status']> {
    return this.callNative('requestPermission', { type })
  }

  /**
   * Request multiple permissions
   */
  async requestMultiple(types: AndroidPermission['type'][]): Promise<Record<AndroidPermission['type'], AndroidPermission['status']>> {
    return this.callNative('requestMultiplePermissions', { types })
  }

  /**
   * Should show request rationale
   */
  async shouldShowRationale(type: AndroidPermission['type']): Promise<boolean> {
    return this.callNative('shouldShowRequestRationale', { type })
  }

  /**
   * Open app settings
   */
  async openSettings(): Promise<void> {
    await this.callNative('openAppSettings', {})
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    return 'granted' as T
  }
}

// Android Biometrics
export class AndroidBiometrics {
  /**
   * Check biometric availability
   */
  async isAvailable(): Promise<{ available: boolean; biometricType: 'fingerprint' | 'face' | 'iris' | 'none' }> {
    return this.callNative('checkBiometricAvailability', {})
  }

  /**
   * Authenticate with biometrics
   */
  async authenticate(config: AndroidBiometricConfig): Promise<{ success: boolean; error?: string }> {
    return this.callNative('authenticateBiometric', config)
  }

  /**
   * Check if device has enrolled biometrics
   */
  async hasEnrolledBiometrics(): Promise<boolean> {
    return this.callNative('hasEnrolledBiometrics', {})
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    return { available: false, biometricType: 'none' } as T
  }
}

// Android Notifications
export class AndroidNotifications {
  /**
   * Create notification channel (required for Android 8+)
   */
  async createChannel(channel: AndroidNotificationChannel): Promise<void> {
    await this.callNative('createNotificationChannel', channel)
  }

  /**
   * Delete notification channel
   */
  async deleteChannel(channelId: string): Promise<void> {
    await this.callNative('deleteNotificationChannel', { channelId })
  }

  /**
   * Show notification
   */
  async show(notification: AndroidNotification): Promise<void> {
    await this.callNative('showNotification', notification)
  }

  /**
   * Cancel notification
   */
  async cancel(notificationId: number): Promise<void> {
    await this.callNative('cancelNotification', { notificationId })
  }

  /**
   * Cancel all notifications
   */
  async cancelAll(): Promise<void> {
    await this.callNative('cancelAllNotifications', {})
  }

  /**
   * Request notification permission (Android 13+)
   */
  async requestPermission(): Promise<boolean> {
    return this.callNative('requestNotificationPermission', {})
  }

  /**
   * Check if notifications are enabled
   */
  async areNotificationsEnabled(): Promise<boolean> {
    return this.callNative('areNotificationsEnabled', {})
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    return true as T
  }
}

// Android Material You / Dynamic Colors
export class AndroidMaterialYou {
  /**
   * Check if dynamic colors are available
   */
  async isAvailable(): Promise<boolean> {
    return this.callNative('isDynamicColorAvailable', {})
  }

  /**
   * Get dynamic colors
   */
  async getColors(): Promise<AndroidMaterialYouColors | null> {
    return this.callNative('getDynamicColors', {})
  }

  /**
   * Listen for color changes (wallpaper change)
   */
  onColorChange(callback: (colors: AndroidMaterialYouColors) => void): () => void {
    const handler = (event: CustomEvent) => callback(event.detail)
    window.addEventListener('material-you-colors' as any, handler)
    return () => window.removeEventListener('material-you-colors' as any, handler)
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    return false as T
  }
}

// Android Photo Picker
export class AndroidPhotoPicker {
  /**
   * Pick single image
   */
  async pickImage(): Promise<{ uri: string; mimeType: string } | null> {
    return this.callNative('pickImage', {})
  }

  /**
   * Pick multiple images
   */
  async pickImages(maxItems = 10): Promise<Array<{ uri: string; mimeType: string }>> {
    return this.callNative('pickImages', { maxItems })
  }

  /**
   * Pick single video
   */
  async pickVideo(): Promise<{ uri: string; mimeType: string; duration: number } | null> {
    return this.callNative('pickVideo', {})
  }

  /**
   * Pick visual media (images and videos)
   */
  async pickVisualMedia(maxItems = 10): Promise<Array<{ uri: string; mimeType: string; type: 'image' | 'video' }>> {
    return this.callNative('pickVisualMedia', { maxItems })
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    return null as T
  }
}

// Android Work Manager
export class AndroidWorkManager {
  /**
   * Enqueue one-time work
   */
  async enqueueOneTime(request: AndroidWorkRequest): Promise<void> {
    await this.callNative('enqueueOneTimeWork', request)
  }

  /**
   * Enqueue periodic work
   */
  async enqueuePeriodic(request: AndroidWorkRequest & { repeatInterval: number; repeatIntervalUnit: 'minutes' | 'hours' | 'days' }): Promise<void> {
    await this.callNative('enqueuePeriodicWork', request)
  }

  /**
   * Cancel work by ID
   */
  async cancelById(id: string): Promise<void> {
    await this.callNative('cancelWorkById', { id })
  }

  /**
   * Cancel work by tag
   */
  async cancelByTag(tag: string): Promise<void> {
    await this.callNative('cancelWorkByTag', { tag })
  }

  /**
   * Cancel all work
   */
  async cancelAll(): Promise<void> {
    await this.callNative('cancelAllWork', {})
  }

  /**
   * Get work info by ID
   */
  async getWorkInfoById(id: string): Promise<{ state: 'enqueued' | 'running' | 'succeeded' | 'failed' | 'blocked' | 'cancelled'; outputData?: Record<string, unknown> } | null> {
    return this.callNative('getWorkInfoById', { id })
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    return undefined as T
  }
}

// Android Foreground Service
export class AndroidForegroundService {
  /**
   * Start foreground service
   */
  async start(config: {
    notificationId: number
    notification: AndroidNotification
    serviceType?: 'camera' | 'connectedDevice' | 'dataSync' | 'location' | 'mediaPlayback' | 'mediaProjection' | 'microphone' | 'phoneCall' | 'remoteMessaging' | 'shortService'
  }): Promise<void> {
    await this.callNative('startForegroundService', config)
  }

  /**
   * Stop foreground service
   */
  async stop(): Promise<void> {
    await this.callNative('stopForegroundService', {})
  }

  /**
   * Update notification
   */
  async updateNotification(notification: Partial<AndroidNotification>): Promise<void> {
    await this.callNative('updateForegroundNotification', notification)
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    return undefined as T
  }
}

// Android Predictive Back Gesture
export class AndroidPredictiveBack {
  /**
   * Enable predictive back gesture
   */
  async enable(): Promise<void> {
    await this.callNative('enablePredictiveBack', {})
  }

  /**
   * Disable predictive back gesture
   */
  async disable(): Promise<void> {
    await this.callNative('disablePredictiveBack', {})
  }

  /**
   * Register back callback
   */
  onBackPressed(callback: () => boolean): () => void {
    const handler = (event: CustomEvent) => {
      const handled = callback()
      if ((window as any).CraftBridge) {
        ;(window as any).CraftBridge.postMessage(
          JSON.stringify({
            method: 'backPressedResult',
            params: { handled },
          })
        )
      }
    }
    window.addEventListener('back-pressed' as any, handler)
    return () => window.removeEventListener('back-pressed' as any, handler)
  }

  /**
   * Listen for back progress (for animations)
   */
  onBackProgress(callback: (progress: { touchX: number; touchY: number; progress: number }) => void): () => void {
    const handler = (event: CustomEvent) => callback(event.detail)
    window.addEventListener('back-progress' as any, handler)
    return () => window.removeEventListener('back-progress' as any, handler)
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    return undefined as T
  }
}

// Android Per-App Language
export class AndroidPerAppLanguage {
  /**
   * Get current app locale
   */
  async getCurrentLocale(): Promise<string> {
    return this.callNative('getCurrentAppLocale', {})
  }

  /**
   * Set app locale
   */
  async setLocale(localeTag: string): Promise<void> {
    await this.callNative('setAppLocale', { localeTag })
  }

  /**
   * Reset to system locale
   */
  async resetToSystemLocale(): Promise<void> {
    await this.callNative('resetToSystemLocale', {})
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    return 'en' as T
  }
}

// Android Widgets
export class AndroidWidgets {
  /**
   * Register widget
   */
  async register(widget: AndroidWidget): Promise<void> {
    await this.callNative('registerWidget', widget)
  }

  /**
   * Update widget
   */
  async update(widgetId: string, views: Record<string, unknown>): Promise<void> {
    await this.callNative('updateWidget', { widgetId, views })
  }

  /**
   * Get widget IDs
   */
  async getWidgetIds(className: string): Promise<number[]> {
    return this.callNative('getWidgetIds', { className })
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    return [] as T
  }
}

// Android Play Billing
export class AndroidPlayBilling {
  /**
   * Check if billing is ready
   */
  async isReady(): Promise<boolean> {
    return this.callNative('isBillingReady', {})
  }

  /**
   * Query product details
   */
  async queryProducts(productIds: string[], productType: 'inapp' | 'subs'): Promise<
    Array<{
      productId: string
      name: string
      description: string
      formattedPrice: string
      priceAmountMicros: number
      priceCurrencyCode: string
    }>
  > {
    return this.callNative('queryProductDetails', { productIds, productType })
  }

  /**
   * Launch purchase flow
   */
  async purchase(productId: string, productType: 'inapp' | 'subs'): Promise<{ purchaseToken: string; orderId: string } | null> {
    return this.callNative('launchBillingFlow', { productId, productType })
  }

  /**
   * Consume purchase
   */
  async consumePurchase(purchaseToken: string): Promise<void> {
    await this.callNative('consumePurchase', { purchaseToken })
  }

  /**
   * Acknowledge purchase
   */
  async acknowledgePurchase(purchaseToken: string): Promise<void> {
    await this.callNative('acknowledgePurchase', { purchaseToken })
  }

  /**
   * Query purchases
   */
  async queryPurchases(productType: 'inapp' | 'subs'): Promise<
    Array<{
      productId: string
      purchaseToken: string
      orderId: string
      purchaseTime: number
      isAcknowledged: boolean
      purchaseState: 'pending' | 'purchased' | 'unspecified'
    }>
  > {
    return this.callNative('queryPurchases', { productType })
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    return [] as T
  }
}

// Android Firebase
export class AndroidFirebase {
  /**
   * Get FCM token
   */
  async getFCMToken(): Promise<string | null> {
    return this.callNative('getFCMToken', {})
  }

  /**
   * Subscribe to topic
   */
  async subscribeToTopic(topic: string): Promise<void> {
    await this.callNative('subscribeToTopic', { topic })
  }

  /**
   * Unsubscribe from topic
   */
  async unsubscribeFromTopic(topic: string): Promise<void> {
    await this.callNative('unsubscribeFromTopic', { topic })
  }

  /**
   * Log analytics event
   */
  async logEvent(name: string, params?: Record<string, unknown>): Promise<void> {
    await this.callNative('logAnalyticsEvent', { name, params })
  }

  /**
   * Set user property
   */
  async setUserProperty(name: string, value: string): Promise<void> {
    await this.callNative('setUserProperty', { name, value })
  }

  /**
   * Set user ID
   */
  async setUserId(userId: string | null): Promise<void> {
    await this.callNative('setUserId', { userId })
  }

  /**
   * Record exception
   */
  async recordException(error: Error): Promise<void> {
    await this.callNative('recordException', {
      message: error.message,
      stack: error.stack,
    })
  }

  /**
   * Set Crashlytics key
   */
  async setCrashlyticsKey(key: string, value: string | number | boolean): Promise<void> {
    await this.callNative('setCrashlyticsKey', { key, value })
  }

  /**
   * Get Remote Config value
   */
  async getRemoteConfigValue(key: string): Promise<string | number | boolean | null> {
    return this.callNative('getRemoteConfigValue', { key })
  }

  /**
   * Fetch Remote Config
   */
  async fetchRemoteConfig(minimumFetchInterval?: number): Promise<void> {
    await this.callNative('fetchRemoteConfig', { minimumFetchInterval })
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    return null as T
  }
}

// Android Native Components
export class AndroidNativeComponents {
  /**
   * Show bottom sheet
   */
  async showBottomSheet(config: {
    title?: string
    items?: Array<{ id: string; title: string; icon?: string; subtitle?: string }>
    dismissible?: boolean
    halfExpanded?: boolean
  }): Promise<string | null> {
    return this.callNative('showBottomSheet', config)
  }

  /**
   * Show navigation drawer
   */
  async showNavigationDrawer(config: {
    items: Array<{ id: string; title: string; icon?: string; selected?: boolean; group?: string }>
    headerTitle?: string
    headerSubtitle?: string
    headerImage?: string
  }): Promise<string | null> {
    return this.callNative('showNavigationDrawer', config)
  }

  /**
   * Show date picker
   */
  async showDatePicker(config?: {
    initialDate?: string
    minDate?: string
    maxDate?: string
    title?: string
  }): Promise<string | null> {
    return this.callNative('showDatePicker', config || {})
  }

  /**
   * Show time picker
   */
  async showTimePicker(config?: {
    initialHour?: number
    initialMinute?: number
    is24Hour?: boolean
    title?: string
  }): Promise<{ hour: number; minute: number } | null> {
    return this.callNative('showTimePicker', config || {})
  }

  /**
   * Show toast
   */
  async showToast(message: string, duration: 'short' | 'long' = 'short'): Promise<void> {
    await this.callNative('showToast', { message, duration })
  }

  /**
   * Show snackbar
   */
  async showSnackbar(config: {
    message: string
    action?: { text: string; color?: string }
    duration?: 'short' | 'long' | 'indefinite'
  }): Promise<boolean> {
    return this.callNative('showSnackbar', config)
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).CraftBridge) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: string) => {
          delete (window as any)[callbackId]
          try {
            const parsed = JSON.parse(result)
            if (parsed.error) reject(new Error(parsed.error))
            else resolve(parsed.result)
          } catch {
            resolve(result as T)
          }
        }
        ;(window as any).CraftBridge.postMessage(JSON.stringify({ method, params, callbackId }))
      })
    }
    return null as T
  }
}

// Export all Android modules
export const android: {
  WebView: typeof AndroidWebView
  Permissions: AndroidPermissions
  Biometrics: AndroidBiometrics
  Notifications: AndroidNotifications
  MaterialYou: AndroidMaterialYou
  PhotoPicker: AndroidPhotoPicker
  WorkManager: AndroidWorkManager
  ForegroundService: AndroidForegroundService
  PredictiveBack: AndroidPredictiveBack
  PerAppLanguage: AndroidPerAppLanguage
  Widgets: AndroidWidgets
  PlayBilling: AndroidPlayBilling
  Firebase: AndroidFirebase
  NativeComponents: AndroidNativeComponents
} = {
  WebView: AndroidWebView,
  Permissions: new AndroidPermissions(),
  Biometrics: new AndroidBiometrics(),
  Notifications: new AndroidNotifications(),
  MaterialYou: new AndroidMaterialYou(),
  PhotoPicker: new AndroidPhotoPicker(),
  WorkManager: new AndroidWorkManager(),
  ForegroundService: new AndroidForegroundService(),
  PredictiveBack: new AndroidPredictiveBack(),
  PerAppLanguage: new AndroidPerAppLanguage(),
  Widgets: new AndroidWidgets(),
  PlayBilling: new AndroidPlayBilling(),
  Firebase: new AndroidFirebase(),
  NativeComponents: new AndroidNativeComponents(),
}

export default android
