/**
 * @fileoverview Craft Mobile API
 * @description Unified cross-platform mobile API for iOS and Android.
 * Provides consistent access to device features, sensors, and native capabilities.
 * @module @craft/api/mobile
 *
 * @example
 * ```typescript
 * import { device, haptics, permissions, camera, biometrics, location, share } from '@craft/api/mobile'
 *
 * // Get device info
 * const info = await device.getInfo()
 * console.log(`Running on ${info.platform} ${info.osVersion}`)
 *
 * // Request permissions
 * const granted = await permissions.request('camera')
 *
 * // Trigger haptic feedback
 * await haptics.impact('medium')
 *
 * // Take a photo
 * const photo = await camera.takePicture()
 * ```
 */

// ============================================================================
// Device Info API
// ============================================================================

/**
 * Device information.
 */
export interface DeviceInfo {
  /** Platform: 'ios' | 'android' | 'macos' | 'windows' | 'linux' */
  platform: 'ios' | 'android' | 'macos' | 'windows' | 'linux'
  /** OS version string (e.g., "17.0", "14") */
  osVersion: string
  /** Device model (e.g., "iPhone 15 Pro", "Pixel 8") */
  model: string
  /** Device manufacturer */
  manufacturer: string
  /** Unique device identifier */
  deviceId: string
  /** Whether device is a tablet */
  isTablet: boolean
  /** Screen dimensions */
  screen: {
    width: number
    height: number
    scale: number
  }
  /** Battery info */
  battery: {
    level: number
    isCharging: boolean
  }
  /** Network status */
  network: {
    type: 'wifi' | 'cellular' | 'ethernet' | 'none'
    isConnected: boolean
  }
}

/**
 * Device capabilities.
 */
export interface DeviceCapabilities {
  /** Has camera */
  camera: boolean
  /** Has biometric authentication */
  biometrics: boolean
  /** Has NFC */
  nfc: boolean
  /** Has Bluetooth */
  bluetooth: boolean
  /** Has GPS */
  gps: boolean
  /** Has accelerometer */
  accelerometer: boolean
  /** Has gyroscope */
  gyroscope: boolean
  /** Has haptic feedback */
  haptics: boolean
  /** Has AR support */
  ar: boolean
  /** Has Face ID (iOS) or face unlock */
  faceId: boolean
  /** Has Touch ID (iOS) or fingerprint */
  touchId: boolean
}

/**
 * Device information and capabilities API.
 *
 * @example
 * ```typescript
 * // Get device info
 * const info = await device.getInfo()
 * console.log(`Platform: ${info.platform}`)
 * console.log(`Model: ${info.model}`)
 * console.log(`Battery: ${info.battery.level}%`)
 *
 * // Check capabilities
 * const caps = await device.getCapabilities()
 * if (caps.biometrics) {
 *   // Enable biometric login
 * }
 *
 * // Check if running on mobile
 * if (device.isMobile()) {
 *   // Show mobile-specific UI
 * }
 * ```
 */
export const device = {
  /**
   * Get comprehensive device information.
   *
   * @returns Promise resolving to DeviceInfo
   */
  async getInfo(): Promise<DeviceInfo> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.device) {
      return craft.device.getInfo()
    }
    // Return web defaults
    return {
      platform: detectPlatform(),
      osVersion: 'unknown',
      model: 'unknown',
      manufacturer: 'unknown',
      deviceId: 'web-' + Math.random().toString(36).slice(2),
      isTablet: false,
      screen: {
        width: typeof window !== 'undefined' ? window.innerWidth || 0 : 0,
        height: typeof window !== 'undefined' ? window.innerHeight || 0 : 0,
        scale: typeof window !== 'undefined' ? window.devicePixelRatio || 1 : 1
      },
      battery: { level: 100, isCharging: false },
      network: { type: 'wifi', isConnected: typeof navigator !== 'undefined' ? navigator.onLine ?? true : true }
    }
  },

  /**
   * Get device capabilities.
   *
   * @returns Promise resolving to DeviceCapabilities
   */
  async getCapabilities(): Promise<DeviceCapabilities> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.device) {
      return craft.device.getCapabilities()
    }
    return {
      camera: true,
      biometrics: false,
      nfc: false,
      bluetooth: false,
      gps: 'geolocation' in navigator,
      accelerometer: false,
      gyroscope: false,
      haptics: 'vibrate' in navigator,
      ar: false,
      faceId: false,
      touchId: false
    }
  },

  /**
   * Check if running on a mobile device.
   */
  isMobile(): boolean {
    const platform = detectPlatform()
    return platform === 'ios' || platform === 'android'
  },

  /**
   * Check if running on iOS.
   */
  isIOS(): boolean {
    return detectPlatform() === 'ios'
  },

  /**
   * Check if running on Android.
   */
  isAndroid(): boolean {
    return detectPlatform() === 'android'
  },

  /**
   * Get current locale.
   */
  getLocale(): string {
    return navigator?.language || 'en-US'
  },

  /**
   * Get timezone.
   */
  getTimezone(): string {
    return Intl.DateTimeFormat().resolvedOptions().timeZone
  }
}

// ============================================================================
// Haptics API
// ============================================================================

/**
 * Haptic feedback style.
 */
export type HapticStyle = 'light' | 'medium' | 'heavy' | 'soft' | 'rigid'

/**
 * Haptic notification type.
 */
export type HapticNotificationType = 'success' | 'warning' | 'error'

/**
 * Haptic feedback API.
 * Provides tactile feedback on supported devices.
 *
 * @example
 * ```typescript
 * // Impact feedback
 * await haptics.impact('medium')
 *
 * // Notification feedback
 * await haptics.notification('success')
 *
 * // Selection feedback (for UI selection changes)
 * await haptics.selection()
 *
 * // Custom vibration pattern (Android)
 * await haptics.vibrate([100, 50, 100])
 * ```
 */
export const haptics = {
  /**
   * Trigger impact haptic feedback.
   *
   * @param style - Impact style intensity
   */
  async impact(style: HapticStyle = 'medium'): Promise<void> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.haptics) {
      return craft.haptics.impact(style)
    }
    // Web fallback using Vibration API
    if ('vibrate' in navigator) {
      const duration = { light: 10, medium: 20, heavy: 30, soft: 5, rigid: 25 }[style]
      navigator.vibrate(duration)
    }
  },

  /**
   * Trigger notification haptic feedback.
   *
   * @param type - Notification type
   */
  async notification(type: HapticNotificationType = 'success'): Promise<void> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.haptics) {
      return craft.haptics.notification(type)
    }
    if ('vibrate' in navigator) {
      const patterns = {
        success: [10, 30, 10],
        warning: [30, 30, 30],
        error: [50, 50, 50, 50, 50]
      }
      navigator.vibrate(patterns[type])
    }
  },

  /**
   * Trigger selection haptic feedback.
   * Use when a selection changes (e.g., picker value change).
   */
  async selection(): Promise<void> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.haptics) {
      return craft.haptics.selection()
    }
    if ('vibrate' in navigator) {
      navigator.vibrate(5)
    }
  },

  /**
   * Vibrate with a custom pattern.
   *
   * @param pattern - Array of durations in ms [vibrate, pause, vibrate, ...]
   */
  async vibrate(pattern: number[]): Promise<void> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.haptics) {
      return craft.haptics.vibrate(pattern)
    }
    if ('vibrate' in navigator) {
      navigator.vibrate(pattern)
    }
  }
}

// ============================================================================
// Permissions API
// ============================================================================

/**
 * Permission types.
 */
export type PermissionType =
  | 'camera'
  | 'microphone'
  | 'photos'
  | 'location'
  | 'locationAlways'
  | 'notifications'
  | 'contacts'
  | 'calendar'
  | 'reminders'
  | 'bluetooth'
  | 'motion'
  | 'health'

/**
 * Permission status.
 */
export type PermissionStatus = 'granted' | 'denied' | 'undetermined' | 'restricted'

/**
 * Permissions API.
 * Request and check native permissions.
 *
 * @example
 * ```typescript
 * // Check permission status
 * const status = await permissions.check('camera')
 *
 * // Request permission
 * if (status !== 'granted') {
 *   const newStatus = await permissions.request('camera')
 *   if (newStatus === 'granted') {
 *     // Permission granted, proceed
 *   }
 * }
 *
 * // Check multiple permissions
 * const statuses = await permissions.checkMultiple(['camera', 'microphone'])
 *
 * // Request multiple permissions
 * const results = await permissions.requestMultiple(['camera', 'microphone', 'photos'])
 * ```
 */
export const permissions = {
  /**
   * Check the status of a permission.
   *
   * @param permission - Permission to check
   * @returns Promise resolving to PermissionStatus
   */
  async check(permission: PermissionType): Promise<PermissionStatus> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.permissions) {
      return craft.permissions.check(permission)
    }
    // Web fallback using Permissions API
    try {
      const webPermission = mapToWebPermission(permission)
      if (webPermission && navigator.permissions) {
        const result = await navigator.permissions.query({ name: webPermission as PermissionName })
        return mapWebPermissionStatus(result.state)
      }
    } catch {
      // Permissions API not supported
    }
    return 'undetermined'
  },

  /**
   * Request a permission.
   *
   * @param permission - Permission to request
   * @returns Promise resolving to new PermissionStatus
   */
  async request(permission: PermissionType): Promise<PermissionStatus> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.permissions) {
      return craft.permissions.request(permission)
    }
    // Web fallback - trigger permission request through relevant API
    try {
      if (permission === 'camera' || permission === 'microphone') {
        const constraints: MediaStreamConstraints = {}
        if (permission === 'camera') constraints.video = true
        if (permission === 'microphone') constraints.audio = true
        const stream = await navigator.mediaDevices.getUserMedia(constraints)
        stream.getTracks().forEach(track => track.stop())
        return 'granted'
      }
      if (permission === 'location') {
        return new Promise((resolve) => {
          navigator.geolocation.getCurrentPosition(
            () => resolve('granted'),
            () => resolve('denied')
          )
        })
      }
      if (permission === 'notifications') {
        const result = await Notification.requestPermission()
        return result === 'granted' ? 'granted' : 'denied'
      }
    } catch {
      return 'denied'
    }
    return 'undetermined'
  },

  /**
   * Check multiple permissions.
   *
   * @param permissionList - Array of permissions to check
   * @returns Promise resolving to object mapping permissions to statuses
   */
  async checkMultiple(permissionList: PermissionType[]): Promise<Record<PermissionType, PermissionStatus>> {
    const results: Record<string, PermissionStatus> = {}
    for (const perm of permissionList) {
      results[perm] = await this.check(perm)
    }
    return results as Record<PermissionType, PermissionStatus>
  },

  /**
   * Request multiple permissions.
   *
   * @param permissionList - Array of permissions to request
   * @returns Promise resolving to object mapping permissions to statuses
   */
  async requestMultiple(permissionList: PermissionType[]): Promise<Record<PermissionType, PermissionStatus>> {
    const results: Record<string, PermissionStatus> = {}
    for (const perm of permissionList) {
      results[perm] = await this.request(perm)
    }
    return results as Record<PermissionType, PermissionStatus>
  },

  /**
   * Open app settings (to change permissions manually).
   */
  async openSettings(): Promise<void> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.permissions) {
      return craft.permissions.openSettings()
    }
  }
}

// ============================================================================
// Camera API
// ============================================================================

/**
 * Camera options.
 */
export interface CameraOptions {
  /** Camera to use: 'front' | 'back' */
  camera?: 'front' | 'back'
  /** Photo quality: 0-100 */
  quality?: number
  /** Max width in pixels */
  maxWidth?: number
  /** Max height in pixels */
  maxHeight?: number
  /** Save to camera roll */
  saveToGallery?: boolean
}

/**
 * Photo result.
 */
export interface PhotoResult {
  /** Base64 encoded image data */
  base64: string
  /** Image URI/path */
  uri: string
  /** Image width */
  width: number
  /** Image height */
  height: number
  /** MIME type */
  mimeType: string
}

/**
 * Camera and image picker API.
 *
 * @example
 * ```typescript
 * // Take a photo
 * const photo = await camera.takePicture({ camera: 'back', quality: 80 })
 *
 * // Pick from gallery
 * const image = await camera.pickImage()
 *
 * // Pick multiple images
 * const images = await camera.pickMultiple({ maxCount: 5 })
 * ```
 */
export const camera = {
  /**
   * Take a photo with the device camera.
   *
   * @param options - Camera options
   * @returns Promise resolving to PhotoResult
   */
  async takePicture(options: CameraOptions = {}): Promise<PhotoResult> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.camera) {
      return craft.camera.takePicture(options)
    }
    throw new Error('Camera API not available. Must run in Craft environment.')
  },

  /**
   * Pick an image from the gallery.
   *
   * @returns Promise resolving to PhotoResult
   */
  async pickImage(): Promise<PhotoResult> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.camera) {
      return craft.camera.pickImage()
    }
    // Web fallback using file input
    return new Promise((resolve, reject) => {
      const input = document.createElement('input')
      input.type = 'file'
      input.accept = 'image/*'
      input.onchange = async () => {
        const file = input.files?.[0]
        if (file) {
          const reader = new FileReader()
          reader.onload = () => {
            const base64 = (reader.result as string).split(',')[1]
            resolve({
              base64,
              uri: URL.createObjectURL(file),
              width: 0,
              height: 0,
              mimeType: file.type
            })
          }
          reader.onerror = () => reject(new Error('Failed to read file'))
          reader.readAsDataURL(file)
        } else {
          reject(new Error('No file selected'))
        }
      }
      input.click()
    })
  },

  /**
   * Pick multiple images from the gallery.
   *
   * @param options - Options including maxCount
   * @returns Promise resolving to array of PhotoResults
   */
  async pickMultiple(options: { maxCount?: number } = {}): Promise<PhotoResult[]> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.camera) {
      return craft.camera.pickMultiple(options)
    }
    throw new Error('Camera API not available. Must run in Craft environment.')
  },

  /**
   * Check if camera is available.
   */
  async isAvailable(): Promise<boolean> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.camera) {
      return craft.camera.isAvailable()
    }
    try {
      const devices = await navigator.mediaDevices.enumerateDevices()
      return devices.some(d => d.kind === 'videoinput')
    } catch {
      return false
    }
  }
}

// ============================================================================
// Biometrics API
// ============================================================================

/**
 * Biometric type.
 */
export type BiometricType = 'faceId' | 'touchId' | 'fingerprint' | 'face' | 'iris'

/**
 * Biometric authentication API.
 *
 * @example
 * ```typescript
 * // Check availability
 * const available = await biometrics.isAvailable()
 * const type = await biometrics.getBiometricType()
 *
 * // Authenticate
 * try {
 *   const success = await biometrics.authenticate('Verify your identity')
 *   if (success) {
 *     // Proceed with authenticated action
 *   }
 * } catch (error) {
 *   console.log('Authentication failed:', error)
 * }
 * ```
 */
export const biometrics = {
  /**
   * Check if biometric authentication is available.
   */
  async isAvailable(): Promise<boolean> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.biometrics) {
      return craft.biometrics.isAvailable()
    }
    return false
  },

  /**
   * Get the type of biometric authentication available.
   */
  async getBiometricType(): Promise<BiometricType | null> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.biometrics) {
      return craft.biometrics.getBiometricType()
    }
    return null
  },

  /**
   * Authenticate using biometrics.
   *
   * @param reason - Reason shown to user for authentication
   * @returns Promise resolving to true if authenticated
   * @throws Error if authentication fails or is cancelled
   */
  async authenticate(reason: string): Promise<boolean> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.biometrics) {
      return craft.biometrics.authenticate(reason)
    }
    throw new Error('Biometrics not available')
  }
}

// ============================================================================
// Secure Storage API
// ============================================================================

/**
 * Secure storage API for sensitive data.
 * Uses Keychain (iOS) or Keystore (Android).
 *
 * @example
 * ```typescript
 * // Store sensitive data
 * await secureStorage.set('authToken', 'secret-token-123')
 * await secureStorage.set('userCredentials', JSON.stringify({ user: 'john', pass: '***' }))
 *
 * // Retrieve data
 * const token = await secureStorage.get('authToken')
 *
 * // Delete data
 * await secureStorage.delete('authToken')
 *
 * // Clear all secure storage
 * await secureStorage.clear()
 * ```
 */
export const secureStorage = {
  /**
   * Store a value securely.
   *
   * @param key - Storage key
   * @param value - Value to store
   */
  async set(key: string, value: string): Promise<void> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.secureStorage) {
      return craft.secureStorage.set(key, value)
    }
    // Fallback to localStorage (not secure, but functional for development)
    localStorage.setItem(`secure_${key}`, value)
  },

  /**
   * Retrieve a securely stored value.
   *
   * @param key - Storage key
   * @returns Promise resolving to value or null
   */
  async get(key: string): Promise<string | null> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.secureStorage) {
      return craft.secureStorage.get(key)
    }
    return localStorage.getItem(`secure_${key}`)
  },

  /**
   * Delete a securely stored value.
   *
   * @param key - Storage key
   */
  async delete(key: string): Promise<void> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.secureStorage) {
      return craft.secureStorage.delete(key)
    }
    localStorage.removeItem(`secure_${key}`)
  },

  /**
   * Clear all securely stored values.
   */
  async clear(): Promise<void> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.secureStorage) {
      return craft.secureStorage.clear()
    }
    Object.keys(localStorage)
      .filter(k => k.startsWith('secure_'))
      .forEach(k => localStorage.removeItem(k))
  }
}

// ============================================================================
// Location API
// ============================================================================

/**
 * Location coordinates.
 */
export interface Location {
  latitude: number
  longitude: number
  altitude?: number
  accuracy: number
  heading?: number
  speed?: number
  timestamp: number
}

/**
 * Location options.
 */
export interface LocationOptions {
  /** Enable high accuracy (uses more battery) */
  enableHighAccuracy?: boolean
  /** Timeout in milliseconds */
  timeout?: number
  /** Maximum age of cached position in milliseconds */
  maximumAge?: number
}

/**
 * Location API.
 *
 * @example
 * ```typescript
 * // Get current location
 * const loc = await location.getCurrentPosition()
 * console.log(`Lat: ${loc.latitude}, Lng: ${loc.longitude}`)
 *
 * // Watch location changes
 * const watchId = location.watchPosition((loc) => {
 *   console.log('New position:', loc)
 * })
 *
 * // Stop watching
 * location.clearWatch(watchId)
 * ```
 */
export const location = {
  /**
   * Get current position.
   *
   * @param options - Location options
   * @returns Promise resolving to Location
   */
  async getCurrentPosition(options: LocationOptions = {}): Promise<Location> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.location) {
      return craft.location.getCurrentPosition(options)
    }
    return new Promise((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(
        (pos) => resolve({
          latitude: pos.coords.latitude,
          longitude: pos.coords.longitude,
          altitude: pos.coords.altitude ?? undefined,
          accuracy: pos.coords.accuracy,
          heading: pos.coords.heading ?? undefined,
          speed: pos.coords.speed ?? undefined,
          timestamp: pos.timestamp
        }),
        reject,
        {
          enableHighAccuracy: options.enableHighAccuracy,
          timeout: options.timeout,
          maximumAge: options.maximumAge
        }
      )
    })
  },

  /**
   * Watch position changes.
   *
   * @param callback - Function called on position change
   * @param options - Location options
   * @returns Watch ID to use with clearWatch
   */
  watchPosition(callback: (location: Location) => void, options: LocationOptions = {}): number {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.location) {
      return craft.location.watchPosition(callback, options)
    }
    return navigator.geolocation.watchPosition(
      (pos) => callback({
        latitude: pos.coords.latitude,
        longitude: pos.coords.longitude,
        altitude: pos.coords.altitude ?? undefined,
        accuracy: pos.coords.accuracy,
        heading: pos.coords.heading ?? undefined,
        speed: pos.coords.speed ?? undefined,
        timestamp: pos.timestamp
      }),
      console.error,
      {
        enableHighAccuracy: options.enableHighAccuracy,
        timeout: options.timeout,
        maximumAge: options.maximumAge
      }
    )
  },

  /**
   * Stop watching position.
   *
   * @param watchId - Watch ID returned from watchPosition
   */
  clearWatch(watchId: number): void {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.location) {
      return craft.location.clearWatch(watchId)
    }
    navigator.geolocation.clearWatch(watchId)
  }
}

// ============================================================================
// Share API
// ============================================================================

/**
 * Share options.
 */
export interface ShareOptions {
  /** Text to share */
  text?: string
  /** URL to share */
  url?: string
  /** Title for the share */
  title?: string
  /** File paths/URIs to share */
  files?: string[]
}

/**
 * Share API.
 *
 * @example
 * ```typescript
 * // Share text
 * await share.share({ text: 'Check out this app!' })
 *
 * // Share URL
 * await share.share({ url: 'https://example.com', title: 'Cool Website' })
 *
 * // Share file
 * await share.share({ files: ['/path/to/image.png'] })
 * ```
 */
export const share = {
  /**
   * Open native share dialog.
   *
   * @param options - Share options
   */
  async share(options: ShareOptions): Promise<void> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.share) {
      return craft.share.share(options)
    }
    // Web Share API fallback
    if (navigator.share) {
      await navigator.share({
        title: options.title,
        text: options.text,
        url: options.url
      })
    } else {
      throw new Error('Share API not available')
    }
  },

  /**
   * Check if sharing is available.
   */
  isAvailable(): boolean {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.share) {
      return true
    }
    return 'share' in navigator
  }
}

// ============================================================================
// App Lifecycle API
// ============================================================================

/**
 * App state.
 */
export type AppState = 'active' | 'inactive' | 'background'

/**
 * App lifecycle events API.
 *
 * @example
 * ```typescript
 * // Listen for app state changes
 * const removeListener = lifecycle.onStateChange((state) => {
 *   if (state === 'background') {
 *     // Save data, pause tasks
 *   } else if (state === 'active') {
 *     // Refresh data
 *   }
 * })
 *
 * // Get current state
 * const state = lifecycle.getState()
 *
 * // Remove listener
 * removeListener()
 * ```
 */
export const lifecycle = {
  /**
   * Get current app state.
   */
  getState(): AppState {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.lifecycle) {
      return craft.lifecycle.getState()
    }
    return document.visibilityState === 'visible' ? 'active' : 'background'
  },

  /**
   * Listen for app state changes.
   *
   * @param callback - Function called when state changes
   * @returns Function to remove listener
   */
  onStateChange(callback: (state: AppState) => void): () => void {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.lifecycle) {
      return craft.lifecycle.onStateChange(callback)
    }
    const handler = () => {
      callback(document.visibilityState === 'visible' ? 'active' : 'background')
    }
    document.addEventListener('visibilitychange', handler)
    return () => document.removeEventListener('visibilitychange', handler)
  }
}

// ============================================================================
// Notifications API
// ============================================================================

/**
 * Notification options.
 */
export interface NotificationOptions {
  /** Notification title */
  title: string
  /** Notification body */
  body?: string
  /** Badge count (iOS) */
  badge?: number
  /** Sound name */
  sound?: string
  /** Custom data payload */
  data?: Record<string, unknown>
  /** Schedule for future (timestamp) */
  scheduleAt?: number
}

/**
 * Local notifications API.
 *
 * @example
 * ```typescript
 * // Show immediate notification
 * await notifications.show({
 *   title: 'Hello!',
 *   body: 'This is a notification'
 * })
 *
 * // Schedule notification
 * await notifications.schedule({
 *   title: 'Reminder',
 *   body: 'Time to take a break',
 *   scheduleAt: Date.now() + 3600000 // 1 hour from now
 * })
 *
 * // Cancel all notifications
 * await notifications.cancelAll()
 * ```
 */
export const notifications = {
  /**
   * Show a local notification immediately.
   *
   * @param options - Notification options
   */
  async show(options: NotificationOptions): Promise<void> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.notifications) {
      return craft.notifications.show(options)
    }
    // Web Notifications API fallback
    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification(options.title, { body: options.body })
    }
  },

  /**
   * Schedule a notification for the future.
   *
   * @param options - Notification options with scheduleAt
   */
  async schedule(options: NotificationOptions): Promise<void> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.notifications) {
      return craft.notifications.schedule(options)
    }
    throw new Error('Scheduled notifications not available in web')
  },

  /**
   * Cancel all scheduled notifications.
   */
  async cancelAll(): Promise<void> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.notifications) {
      return craft.notifications.cancelAll()
    }
  },

  /**
   * Set app badge count (iOS).
   *
   * @param count - Badge count (0 to clear)
   */
  async setBadge(count: number): Promise<void> {
    const craft = getCraftMobile()
    if (typeof window !== 'undefined' && craft?.notifications) {
      return craft.notifications.setBadge(count)
    }
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

function detectPlatform(): DeviceInfo['platform'] {
  if (typeof window === 'undefined') return 'linux'
  const ua = navigator.userAgent.toLowerCase()
  if (/iphone|ipad|ipod/.test(ua)) return 'ios'
  if (/android/.test(ua)) return 'android'
  if (/macintosh|mac os x/.test(ua)) return 'macos'
  if (/windows/.test(ua)) return 'windows'
  return 'linux'
}

function mapToWebPermission(permission: PermissionType): string | null {
  const mapping: Record<string, string> = {
    camera: 'camera',
    microphone: 'microphone',
    location: 'geolocation',
    notifications: 'notifications'
  }
  return mapping[permission] || null
}

function mapWebPermissionStatus(state: PermissionState): PermissionStatus {
  const mapping: Record<PermissionState, PermissionStatus> = {
    granted: 'granted',
    denied: 'denied',
    prompt: 'undetermined'
  }
  return mapping[state]
}

// Mobile bridge type for window.craft with mobile-specific properties
interface CraftMobileBridge {
  device?: {
    getInfo(): Promise<DeviceInfo>
    getCapabilities(): Promise<DeviceCapabilities>
  }
  haptics?: {
    impact(style: HapticStyle): Promise<void>
    notification(type: HapticNotificationType): Promise<void>
    selection(): Promise<void>
    vibrate(pattern: number[]): Promise<void>
  }
  permissions?: {
    check(permission: PermissionType): Promise<PermissionStatus>
    request(permission: PermissionType): Promise<PermissionStatus>
    openSettings(): Promise<void>
  }
  camera?: {
    takePicture(options: CameraOptions): Promise<PhotoResult>
    pickImage(): Promise<PhotoResult>
    pickMultiple(options: { maxCount?: number }): Promise<PhotoResult[]>
    isAvailable(): Promise<boolean>
  }
  biometrics?: {
    isAvailable(): Promise<boolean>
    getBiometricType(): Promise<BiometricType | null>
    authenticate(reason: string): Promise<boolean>
  }
  secureStorage?: {
    set(key: string, value: string): Promise<void>
    get(key: string): Promise<string | null>
    delete(key: string): Promise<void>
    clear(): Promise<void>
  }
  location?: {
    getCurrentPosition(options: LocationOptions): Promise<Location>
    watchPosition(callback: (location: Location) => void, options: LocationOptions): number
    clearWatch(watchId: number): void
  }
  share?: {
    share(options: ShareOptions): Promise<void>
  }
  lifecycle?: {
    getState(): AppState
    onStateChange(callback: (state: AppState) => void): () => void
  }
  notifications?: {
    show(options: NotificationOptions): Promise<void>
    schedule(options: NotificationOptions): Promise<void>
    cancelAll(): Promise<void>
    setBadge(count: number): Promise<void>
  }
}

/**
 * Helper to access window.craft with mobile-specific type extensions.
 * This avoids conflicts with the CraftBridgeAPI declaration in types.ts.
 */
function getCraftMobile(): CraftMobileBridge | undefined {
  if (typeof window !== 'undefined') {
    return (window as any).craft as CraftMobileBridge | undefined
  }
  return undefined
}

const mobile: {
  device: typeof device
  haptics: typeof haptics
  permissions: typeof permissions
  camera: typeof camera
  biometrics: typeof biometrics
  secureStorage: typeof secureStorage
  location: typeof location
  share: typeof share
  lifecycle: typeof lifecycle
  notifications: typeof notifications
} = {
  device: device,
  haptics: haptics,
  permissions: permissions,
  camera: camera,
  biometrics: biometrics,
  secureStorage: secureStorage,
  location: location,
  share: share,
  lifecycle: lifecycle,
  notifications: notifications
}

export default mobile
