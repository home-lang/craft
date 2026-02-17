/**
 * Craft iOS Bridge
 * Complete iOS native bridge with WebView, permissions, haptics, and platform APIs
 */

// Types
export interface IOSWebViewConfig {
  url?: string
  html?: string
  allowsBackForwardNavigationGestures?: boolean
  allowsInlineMediaPlayback?: boolean
  mediaTypesRequiringUserAction?: ('audio' | 'video' | 'all' | 'none')[]
  suppressesIncrementalRendering?: boolean
  allowsAirPlayForMediaPlayback?: boolean
  scrollEnabled?: boolean
  bounces?: boolean
  contentInsetAdjustmentBehavior?: 'automatic' | 'scrollableAxes' | 'never' | 'always'
}

export interface IOSPermission {
  type:
    | 'camera'
    | 'microphone'
    | 'photos'
    | 'location'
    | 'locationAlways'
    | 'contacts'
    | 'calendar'
    | 'reminders'
    | 'notifications'
    | 'bluetooth'
    | 'healthKit'
    | 'motion'
    | 'speechRecognition'
    | 'mediaLibrary'
    | 'siri'
    | 'faceID'
    | 'tracking'
  status: 'notDetermined' | 'restricted' | 'denied' | 'authorized' | 'authorizedWhenInUse' | 'provisional'
}

export interface IOSHapticFeedback {
  type: 'impact' | 'notification' | 'selection'
  style?: 'light' | 'medium' | 'heavy' | 'soft' | 'rigid'
  notificationType?: 'success' | 'warning' | 'error'
}

export interface IOSAppClipConfig {
  invocationURL: string
  experienceType: 'default' | 'locationBased'
  businessCategory?: string
  subtitle?: string
}

export interface IOSSharePlayActivity {
  activityIdentifier: string
  fallbackURL?: string
  title: string
  subtitle?: string
  image?: string
}

export interface IOSLiveActivity {
  activityId: string
  contentState: Record<string, unknown>
  staleDate?: Date
  relevanceScore?: number
}

export interface IOSFocusFilter {
  identifier: string
  name: string
  iconSystemName?: string
  parameters: Record<string, unknown>
}

export interface IOSAppIntent {
  identifier: string
  title: string
  description?: string
  parameters?: Array<{
    name: string
    type: 'string' | 'number' | 'boolean' | 'date' | 'url'
    required?: boolean
  }>
}

export interface IOSTipKitTip {
  identifier: string
  title: string
  message: string
  imageName?: string
  actions?: Array<{ identifier: string; title: string }>
}

export interface IOSStoreKitProduct {
  productId: string
  displayName: string
  description: string
  price: number
  displayPrice: string
  type: 'consumable' | 'nonConsumable' | 'autoRenewable' | 'nonRenewable'
}

export interface IOSCarPlayTemplate {
  type: 'list' | 'grid' | 'tab' | 'information' | 'pointOfInterest' | 'nowPlaying' | 'alert' | 'action'
  title: string
  items?: Array<{ title: string; subtitle?: string; image?: string; handler?: string }>
}

// iOS WebView Bridge
export class IOSWebView {
  private id: string
  private config: IOSWebViewConfig

  constructor(config: IOSWebViewConfig = {}) {
    this.id = `webview_${Date.now()}_${Math.random().toString(36).slice(2)}`
    this.config = config
  }

  /**
   * Create the WebView (calls Objective-C runtime)
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
  async loadURL(url: string): Promise<void> {
    await this.callNative('loadURL', { id: this.id, url })
  }

  /**
   * Load HTML content
   */
  async loadHTML(html: string, baseURL?: string): Promise<void> {
    await this.callNative('loadHTML', { id: this.id, html, baseURL })
  }

  /**
   * Evaluate JavaScript in the WebView
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
   * Reload the current page
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
   * Take a snapshot of the WebView
   */
  async takeSnapshot(): Promise<string> {
    return this.callNative('takeSnapshot', { id: this.id })
  }

  /**
   * Destroy the WebView
   */
  async destroy(): Promise<void> {
    await this.callNative('destroyWebView', { id: this.id })
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    // Bridge to native via window.webkit.messageHandlers or custom bridge
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}_${Math.random().toString(36).slice(2)}`
        ;(window as any)[callbackId] = (result: T, error?: string) => {
          delete (window as any)[callbackId]
          if (error) reject(new Error(error))
          else resolve(result)
        }
        ;(window as any).webkit.messageHandlers.craft.postMessage({
          method,
          params,
          callbackId,
        })
      })
    }
    // Fallback for non-iOS environments
    console.warn(`[IOSBridge] ${method} called but not in iOS WebView context`)
    return undefined as T
  }
}

// iOS Permissions
export class IOSPermissions {
  /**
   * Check permission status
   */
  async check(type: IOSPermission['type']): Promise<IOSPermission['status']> {
    return this.callNative('checkPermission', { type })
  }

  /**
   * Request permission
   */
  async request(type: IOSPermission['type']): Promise<IOSPermission['status']> {
    return this.callNative('requestPermission', { type })
  }

  /**
   * Open app settings
   */
  async openSettings(): Promise<void> {
    await this.callNative('openSettings', {})
  }

  /**
   * Check if can open settings
   */
  async canOpenSettings(): Promise<boolean> {
    return this.callNative('canOpenSettings', {})
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}_${Math.random().toString(36).slice(2)}`
        ;(window as any)[callbackId] = (result: T, error?: string) => {
          delete (window as any)[callbackId]
          if (error) reject(new Error(error))
          else resolve(result)
        }
        ;(window as any).webkit.messageHandlers.craft.postMessage({
          method,
          params,
          callbackId,
        })
      })
    }
    return 'authorized' as T // Default for non-iOS
  }
}

// iOS Haptics
export class IOSHaptics {
  /**
   * Trigger impact feedback
   */
  async impact(style: IOSHapticFeedback['style'] = 'medium'): Promise<void> {
    await this.callNative('triggerHaptic', { type: 'impact', style })
  }

  /**
   * Trigger notification feedback
   */
  async notification(type: IOSHapticFeedback['notificationType'] = 'success'): Promise<void> {
    await this.callNative('triggerHaptic', { type: 'notification', notificationType: type })
  }

  /**
   * Trigger selection feedback
   */
  async selection(): Promise<void> {
    await this.callNative('triggerHaptic', { type: 'selection' })
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve) => {
        ;(window as any).webkit.messageHandlers.craft.postMessage({ method, params })
        resolve(undefined as T)
      })
    }
    return undefined as T
  }
}

// iOS App Clips
export class IOSAppClips {
  /**
   * Configure App Clip experience
   */
  async configure(config: IOSAppClipConfig): Promise<void> {
    await this.callNative('configureAppClip', config)
  }

  /**
   * Get invocation URL
   */
  async getInvocationURL(): Promise<string | null> {
    return this.callNative('getAppClipInvocationURL', {})
  }

  /**
   * Check if running as App Clip
   */
  async isAppClip(): Promise<boolean> {
    return this.callNative('isAppClip', {})
  }

  /**
   * Request full app installation
   */
  async requestFullAppInstallation(): Promise<void> {
    await this.callNative('requestFullAppInstallation', {})
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: T, error?: string) => {
          delete (window as any)[callbackId]
          if (error) reject(new Error(error))
          else resolve(result)
        }
        ;(window as any).webkit.messageHandlers.craft.postMessage({ method, params, callbackId })
      })
    }
    return null as T
  }
}

// iOS SharePlay
export class IOSSharePlay {
  private activity: IOSSharePlayActivity | null = null

  /**
   * Start a SharePlay activity
   */
  async startActivity(activity: IOSSharePlayActivity): Promise<void> {
    this.activity = activity
    await this.callNative('startSharePlayActivity', activity)
  }

  /**
   * End the current SharePlay activity
   */
  async endActivity(): Promise<void> {
    if (this.activity) {
      await this.callNative('endSharePlayActivity', { activityId: this.activity.activityIdentifier })
      this.activity = null
    }
  }

  /**
   * Check if SharePlay is available
   */
  async isAvailable(): Promise<boolean> {
    return this.callNative('isSharePlayAvailable', {})
  }

  /**
   * Send message to participants
   */
  async sendMessage(data: unknown): Promise<void> {
    await this.callNative('sendSharePlayMessage', { data })
  }

  /**
   * Listen for messages
   */
  onMessage(callback: (data: unknown) => void): () => void {
    const handler = (event: CustomEvent) => callback(event.detail)
    window.addEventListener('shareplay-message' as any, handler)
    return () => window.removeEventListener('shareplay-message' as any, handler)
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: T, error?: string) => {
          delete (window as any)[callbackId]
          if (error) reject(new Error(error))
          else resolve(result)
        }
        ;(window as any).webkit.messageHandlers.craft.postMessage({ method, params, callbackId })
      })
    }
    return false as T
  }
}

// iOS Live Activities
export class IOSLiveActivities {
  /**
   * Start a Live Activity
   */
  async start(activity: Omit<IOSLiveActivity, 'activityId'>): Promise<string> {
    return this.callNative('startLiveActivity', activity)
  }

  /**
   * Update a Live Activity
   */
  async update(activityId: string, contentState: Record<string, unknown>): Promise<void> {
    await this.callNative('updateLiveActivity', { activityId, contentState })
  }

  /**
   * End a Live Activity
   */
  async end(activityId: string, dismissalPolicy?: 'immediate' | 'default' | 'after'): Promise<void> {
    await this.callNative('endLiveActivity', { activityId, dismissalPolicy })
  }

  /**
   * Get all active Live Activities
   */
  async getAll(): Promise<IOSLiveActivity[]> {
    return this.callNative('getAllLiveActivities', {})
  }

  /**
   * Check if Live Activities are supported
   */
  async areSupported(): Promise<boolean> {
    return this.callNative('areLiveActivitiesSupported', {})
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: T, error?: string) => {
          delete (window as any)[callbackId]
          if (error) reject(new Error(error))
          else resolve(result)
        }
        ;(window as any).webkit.messageHandlers.craft.postMessage({ method, params, callbackId })
      })
    }
    return [] as T
  }
}

// iOS Focus Filters
export class IOSFocusFilters {
  /**
   * Register a focus filter
   */
  async register(filter: IOSFocusFilter): Promise<void> {
    await this.callNative('registerFocusFilter', filter)
  }

  /**
   * Get current focus filter
   */
  async getCurrent(): Promise<IOSFocusFilter | null> {
    return this.callNative('getCurrentFocusFilter', {})
  }

  /**
   * Check if a focus is active
   */
  async isFocusActive(): Promise<boolean> {
    return this.callNative('isFocusActive', {})
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: T, error?: string) => {
          delete (window as any)[callbackId]
          if (error) reject(new Error(error))
          else resolve(result)
        }
        ;(window as any).webkit.messageHandlers.craft.postMessage({ method, params, callbackId })
      })
    }
    return null as T
  }
}

// iOS App Intents
export class IOSAppIntents {
  /**
   * Register an App Intent
   */
  async register(intent: IOSAppIntent): Promise<void> {
    await this.callNative('registerAppIntent', intent)
  }

  /**
   * Donate an intent (for suggestions)
   */
  async donate(intentIdentifier: string, parameters?: Record<string, unknown>): Promise<void> {
    await this.callNative('donateAppIntent', { intentIdentifier, parameters })
  }

  /**
   * Handle intent execution
   */
  onExecute(callback: (intent: IOSAppIntent, parameters: Record<string, unknown>) => Promise<unknown>): () => void {
    const handler = async (event: CustomEvent) => {
      const result = await callback(event.detail.intent, event.detail.parameters)
      if ((window as any).webkit?.messageHandlers?.craft) {
        ;(window as any).webkit.messageHandlers.craft.postMessage({
          method: 'appIntentResult',
          params: { intentId: event.detail.intentId, result },
        })
      }
    }
    window.addEventListener('app-intent-execute' as any, handler)
    return () => window.removeEventListener('app-intent-execute' as any, handler)
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: T, error?: string) => {
          delete (window as any)[callbackId]
          if (error) reject(new Error(error))
          else resolve(result)
        }
        ;(window as any).webkit.messageHandlers.craft.postMessage({ method, params, callbackId })
      })
    }
    return undefined as T
  }
}

// iOS TipKit
export class IOSTipKit {
  /**
   * Configure TipKit
   */
  async configure(options?: { displayFrequency?: 'immediate' | 'hourly' | 'daily' | 'weekly' | 'monthly' }): Promise<void> {
    await this.callNative('configureTipKit', options || {})
  }

  /**
   * Register a tip
   */
  async registerTip(tip: IOSTipKitTip): Promise<void> {
    await this.callNative('registerTip', tip)
  }

  /**
   * Show a tip
   */
  async showTip(identifier: string): Promise<void> {
    await this.callNative('showTip', { identifier })
  }

  /**
   * Invalidate a tip
   */
  async invalidateTip(identifier: string): Promise<void> {
    await this.callNative('invalidateTip', { identifier })
  }

  /**
   * Reset all tips
   */
  async resetAllTips(): Promise<void> {
    await this.callNative('resetAllTips', {})
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: T, error?: string) => {
          delete (window as any)[callbackId]
          if (error) reject(new Error(error))
          else resolve(result)
        }
        ;(window as any).webkit.messageHandlers.craft.postMessage({ method, params, callbackId })
      })
    }
    return undefined as T
  }
}

// iOS StoreKit 2
export class IOSStoreKit {
  /**
   * Get available products
   */
  async getProducts(productIds: string[]): Promise<IOSStoreKitProduct[]> {
    return this.callNative('getProducts', { productIds })
  }

  /**
   * Purchase a product
   */
  async purchase(productId: string): Promise<{ transactionId: string; status: 'purchased' | 'pending' | 'cancelled' }> {
    return this.callNative('purchaseProduct', { productId })
  }

  /**
   * Restore purchases
   */
  async restorePurchases(): Promise<Array<{ productId: string; transactionId: string }>> {
    return this.callNative('restorePurchases', {})
  }

  /**
   * Check entitlement
   */
  async checkEntitlement(productId: string): Promise<boolean> {
    return this.callNative('checkEntitlement', { productId })
  }

  /**
   * Get subscription status
   */
  async getSubscriptionStatus(productId: string): Promise<{
    isActive: boolean
    willRenew: boolean
    expirationDate?: string
    gracePeriodExpirationDate?: string
  } | null> {
    return this.callNative('getSubscriptionStatus', { productId })
  }

  /**
   * Present offer code redemption sheet
   */
  async presentOfferCodeRedemption(): Promise<void> {
    await this.callNative('presentOfferCodeRedemption', {})
  }

  /**
   * Listen for transaction updates
   */
  onTransactionUpdate(callback: (transaction: { productId: string; transactionId: string; status: string }) => void): () => void {
    const handler = (event: CustomEvent) => callback(event.detail)
    window.addEventListener('storekit-transaction' as any, handler)
    return () => window.removeEventListener('storekit-transaction' as any, handler)
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: T, error?: string) => {
          delete (window as any)[callbackId]
          if (error) reject(new Error(error))
          else resolve(result)
        }
        ;(window as any).webkit.messageHandlers.craft.postMessage({ method, params, callbackId })
      })
    }
    return [] as T
  }
}

// iOS CarPlay
export class IOSCarPlay {
  private connected = false

  /**
   * Check if CarPlay is connected
   */
  async isConnected(): Promise<boolean> {
    return this.callNative('isCarPlayConnected', {})
  }

  /**
   * Set root template
   */
  async setRootTemplate(template: IOSCarPlayTemplate): Promise<void> {
    await this.callNative('setCarPlayRootTemplate', template)
  }

  /**
   * Push a template
   */
  async pushTemplate(template: IOSCarPlayTemplate, animated = true): Promise<void> {
    await this.callNative('pushCarPlayTemplate', { template, animated })
  }

  /**
   * Pop the current template
   */
  async popTemplate(animated = true): Promise<void> {
    await this.callNative('popCarPlayTemplate', { animated })
  }

  /**
   * Present an alert
   */
  async presentAlert(title: string, message?: string, actions?: Array<{ title: string; style?: 'default' | 'cancel' | 'destructive' }>): Promise<number> {
    return this.callNative('presentCarPlayAlert', { title, message, actions })
  }

  /**
   * Update Now Playing info
   */
  async updateNowPlaying(info: {
    title: string
    artist?: string
    album?: string
    artwork?: string
    duration?: number
    elapsedTime?: number
    playbackRate?: number
  }): Promise<void> {
    await this.callNative('updateCarPlayNowPlaying', info)
  }

  /**
   * Listen for CarPlay connection changes
   */
  onConnectionChange(callback: (connected: boolean) => void): () => void {
    const handler = (event: CustomEvent) => {
      this.connected = event.detail.connected
      callback(event.detail.connected)
    }
    window.addEventListener('carplay-connection' as any, handler)
    return () => window.removeEventListener('carplay-connection' as any, handler)
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: T, error?: string) => {
          delete (window as any)[callbackId]
          if (error) reject(new Error(error))
          else resolve(result)
        }
        ;(window as any).webkit.messageHandlers.craft.postMessage({ method, params, callbackId })
      })
    }
    return false as T
  }
}

// iOS Native Components
export class IOSNativeComponents {
  /**
   * Create a native navigation controller
   */
  async createNavigationController(config: {
    title?: string
    largeTitleDisplayMode?: 'automatic' | 'always' | 'never'
    prefersLargeTitles?: boolean
    tintColor?: string
  }): Promise<string> {
    return this.callNative('createNavigationController', config)
  }

  /**
   * Create a native tab bar controller
   */
  async createTabBarController(tabs: Array<{
    title: string
    icon: string
    selectedIcon?: string
    badgeValue?: string
  }>): Promise<string> {
    return this.callNative('createTabBarController', { tabs })
  }

  /**
   * Create a native collection view
   */
  async createCollectionView(config: {
    layout: 'flow' | 'compositional' | 'list'
    itemSize?: { width: number; height: number }
    sectionInsets?: { top: number; left: number; bottom: number; right: number }
    minimumLineSpacing?: number
    minimumInteritemSpacing?: number
  }): Promise<string> {
    return this.callNative('createCollectionView', config)
  }

  /**
   * Show SwiftUI view
   */
  async showSwiftUIView(viewName: string, props?: Record<string, unknown>): Promise<void> {
    await this.callNative('showSwiftUIView', { viewName, props })
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: T, error?: string) => {
          delete (window as any)[callbackId]
          if (error) reject(new Error(error))
          else resolve(result)
        }
        ;(window as any).webkit.messageHandlers.craft.postMessage({ method, params, callbackId })
      })
    }
    return '' as T
  }
}

// iOS Push Notifications
export class IOSPushNotifications {
  /**
   * Register for remote notifications
   */
  async register(): Promise<string> {
    return this.callNative('registerForRemoteNotifications', {})
  }

  /**
   * Get APNs device token
   */
  async getDeviceToken(): Promise<string | null> {
    return this.callNative('getAPNsDeviceToken', {})
  }

  /**
   * Schedule a local notification
   */
  async scheduleLocal(notification: {
    identifier: string
    title: string
    body: string
    subtitle?: string
    badge?: number
    sound?: string | 'default'
    userInfo?: Record<string, unknown>
    trigger: { type: 'timeInterval'; seconds: number; repeats?: boolean } | { type: 'calendar'; dateComponents: Record<string, number>; repeats?: boolean } | { type: 'location'; latitude: number; longitude: number; radius: number; notifyOnEntry?: boolean; notifyOnExit?: boolean }
    categoryIdentifier?: string
    threadIdentifier?: string
    interruptionLevel?: 'passive' | 'active' | 'timeSensitive' | 'critical'
    relevanceScore?: number
  }): Promise<void> {
    await this.callNative('scheduleLocalNotification', notification)
  }

  /**
   * Cancel pending notifications
   */
  async cancelPending(identifiers: string[]): Promise<void> {
    await this.callNative('cancelPendingNotifications', { identifiers })
  }

  /**
   * Get pending notifications
   */
  async getPending(): Promise<Array<{ identifier: string; trigger: unknown }>> {
    return this.callNative('getPendingNotifications', {})
  }

  /**
   * Handle notification response
   */
  onNotificationResponse(callback: (response: { identifier: string; actionIdentifier: string; userInfo: Record<string, unknown> }) => void): () => void {
    const handler = (event: CustomEvent) => callback(event.detail)
    window.addEventListener('notification-response' as any, handler)
    return () => window.removeEventListener('notification-response' as any, handler)
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: T, error?: string) => {
          delete (window as any)[callbackId]
          if (error) reject(new Error(error))
          else resolve(result)
        }
        ;(window as any).webkit.messageHandlers.craft.postMessage({ method, params, callbackId })
      })
    }
    return null as T
  }
}

// iOS App Lifecycle
export class IOSAppLifecycle {
  /**
   * Get current app state
   */
  async getState(): Promise<'active' | 'inactive' | 'background'> {
    return this.callNative('getAppState', {})
  }

  /**
   * Register for state restoration
   */
  async registerStateRestoration(activityType: string): Promise<void> {
    await this.callNative('registerStateRestoration', { activityType })
  }

  /**
   * Save user activity for state restoration
   */
  async saveUserActivity(activityType: string, userInfo: Record<string, unknown>): Promise<void> {
    await this.callNative('saveUserActivity', { activityType, userInfo })
  }

  /**
   * Register background task
   */
  async registerBackgroundTask(identifier: string, handler: () => Promise<void>): Promise<void> {
    const wrappedHandler = async (event: CustomEvent) => {
      if (event.detail.identifier === identifier) {
        await handler()
        if ((window as any).webkit?.messageHandlers?.craft) {
          ;(window as any).webkit.messageHandlers.craft.postMessage({
            method: 'backgroundTaskComplete',
            params: { identifier },
          })
        }
      }
    }
    window.addEventListener('background-task' as any, wrappedHandler)
    await this.callNative('registerBackgroundTask', { identifier })
  }

  /**
   * Schedule background refresh
   */
  async scheduleBackgroundRefresh(identifier: string, earliestBeginDate?: Date): Promise<void> {
    await this.callNative('scheduleBackgroundRefresh', { identifier, earliestBeginDate: earliestBeginDate?.toISOString() })
  }

  /**
   * Listen for app state changes
   */
  onStateChange(callback: (state: 'active' | 'inactive' | 'background') => void): () => void {
    const handler = (event: CustomEvent) => callback(event.detail.state)
    window.addEventListener('app-state-change' as any, handler)
    return () => window.removeEventListener('app-state-change' as any, handler)
  }

  private async callNative<T>(method: string, params: Record<string, unknown> | object): Promise<T> {
    if (typeof window !== 'undefined' && (window as any).webkit?.messageHandlers?.craft) {
      return new Promise((resolve, reject) => {
        const callbackId = `cb_${Date.now()}`
        ;(window as any)[callbackId] = (result: T, error?: string) => {
          delete (window as any)[callbackId]
          if (error) reject(new Error(error))
          else resolve(result)
        }
        ;(window as any).webkit.messageHandlers.craft.postMessage({ method, params, callbackId })
      })
    }
    return 'active' as T
  }
}

// Export all iOS modules
export const ios: {
  WebView: typeof IOSWebView
  Permissions: IOSPermissions
  Haptics: IOSHaptics
  AppClips: IOSAppClips
  SharePlay: IOSSharePlay
  LiveActivities: IOSLiveActivities
  FocusFilters: IOSFocusFilters
  AppIntents: IOSAppIntents
  TipKit: IOSTipKit
  StoreKit: IOSStoreKit
  CarPlay: IOSCarPlay
  NativeComponents: IOSNativeComponents
  PushNotifications: IOSPushNotifications
  AppLifecycle: IOSAppLifecycle
} = {
  WebView: IOSWebView,
  Permissions: new IOSPermissions(),
  Haptics: new IOSHaptics(),
  AppClips: new IOSAppClips(),
  SharePlay: new IOSSharePlay(),
  LiveActivities: new IOSLiveActivities(),
  FocusFilters: new IOSFocusFilters(),
  AppIntents: new IOSAppIntents(),
  TipKit: new IOSTipKit(),
  StoreKit: new IOSStoreKit(),
  CarPlay: new IOSCarPlay(),
  NativeComponents: new IOSNativeComponents(),
  PushNotifications: new IOSPushNotifications(),
  AppLifecycle: new IOSAppLifecycle(),
}

export default ios
