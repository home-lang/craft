/**
 * Mobile API Tests
 *
 * Tests for cross-platform mobile functionality.
 */

import { describe, expect, it } from 'bun:test'
import type {
  DeviceInfo,
  DeviceCapabilities,
  HapticStyle,
  HapticNotificationType,
  PermissionType,
  PermissionStatus,
  CameraOptions,
  PhotoResult,
  BiometricType,
  Location,
  LocationOptions,
  ShareOptions,
  AppState,
  NotificationOptions
} from '../api/mobile'

describe('Mobile API Types', () => {
  describe('DeviceInfo', () => {
    it('should define device information structure', () => {
      const info: DeviceInfo = {
        platform: 'ios',
        osVersion: '17.0',
        model: 'iPhone 15 Pro',
        manufacturer: 'Apple',
        isSimulator: false,
        screenWidth: 393,
        screenHeight: 852,
        screenScale: 3,
        locale: 'en-US',
        timezone: 'America/New_York'
      }

      expect(info.platform).toBe('ios')
      expect(info.osVersion).toBe('17.0')
      expect(info.model).toBe('iPhone 15 Pro')
    })
  })

  describe('DeviceCapabilities', () => {
    it('should define device capabilities', () => {
      const capabilities: DeviceCapabilities = {
        hasCamera: true,
        hasBiometrics: true,
        biometricType: 'face',
        hasNfc: true,
        hasGps: true,
        hasAccelerometer: true,
        hasGyroscope: true,
        hasMagnetometer: true,
        hasBarometer: true,
        hasHaptics: true
      }

      expect(capabilities.hasCamera).toBe(true)
      expect(capabilities.biometricType).toBe('face')
    })
  })

  describe('HapticStyle', () => {
    it('should support haptic styles', () => {
      const styles: HapticStyle[] = ['light', 'medium', 'heavy', 'soft', 'rigid']
      expect(styles).toContain('light')
      expect(styles).toContain('heavy')
    })
  })

  describe('HapticNotificationType', () => {
    it('should support notification types', () => {
      const types: HapticNotificationType[] = ['success', 'warning', 'error']
      expect(types).toContain('success')
      expect(types).toContain('error')
    })
  })

  describe('PermissionType', () => {
    it('should define permission types', () => {
      const permissions: PermissionType[] = [
        'camera',
        'microphone',
        'photos',
        'location',
        'locationAlways',
        'contacts',
        'calendar',
        'reminders',
        'notifications',
        'bluetooth',
        'motion'
      ]

      expect(permissions).toContain('camera')
      expect(permissions).toContain('location')
      expect(permissions).toContain('notifications')
    })
  })

  describe('PermissionStatus', () => {
    it('should define permission statuses', () => {
      const statuses: PermissionStatus[] = ['granted', 'denied', 'undetermined', 'restricted', 'limited']
      expect(statuses).toContain('granted')
      expect(statuses).toContain('denied')
    })
  })

  describe('CameraOptions', () => {
    it('should define camera options', () => {
      const options: CameraOptions = {
        source: 'camera',
        quality: 0.8,
        maxWidth: 1920,
        maxHeight: 1080,
        allowsEditing: true,
        mediaType: 'photo',
        cameraType: 'back',
        saveToPhotos: false
      }

      expect(options.source).toBe('camera')
      expect(options.quality).toBe(0.8)
      expect(options.cameraType).toBe('back')
    })
  })

  describe('PhotoResult', () => {
    it('should define photo result structure', () => {
      const result: PhotoResult = {
        uri: 'file:///path/to/photo.jpg',
        width: 1920,
        height: 1080,
        type: 'image/jpeg',
        fileSize: 1024000,
        base64: undefined,
        exif: undefined
      }

      expect(result.uri).toContain('photo.jpg')
      expect(result.width).toBe(1920)
      expect(result.type).toBe('image/jpeg')
    })
  })

  describe('BiometricType', () => {
    it('should define biometric types', () => {
      const types: BiometricType[] = ['none', 'touch', 'face', 'iris']
      expect(types).toContain('touch')
      expect(types).toContain('face')
    })
  })

  describe('Location', () => {
    it('should define location structure', () => {
      const location: Location = {
        latitude: 37.7749,
        longitude: -122.4194,
        altitude: 10,
        accuracy: 5,
        altitudeAccuracy: 3,
        heading: 90,
        speed: 0,
        timestamp: Date.now()
      }

      expect(location.latitude).toBe(37.7749)
      expect(location.longitude).toBe(-122.4194)
      expect(location.accuracy).toBe(5)
    })
  })

  describe('LocationOptions', () => {
    it('should define location options', () => {
      const options: LocationOptions = {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 5000,
        distanceFilter: 10
      }

      expect(options.enableHighAccuracy).toBe(true)
      expect(options.timeout).toBe(10000)
    })
  })

  describe('ShareOptions', () => {
    it('should define share options', () => {
      const options: ShareOptions = {
        title: 'Share this',
        message: 'Check out this content',
        url: 'https://example.com',
        dialogTitle: 'Share via'
      }

      expect(options.title).toBe('Share this')
      expect(options.url).toBe('https://example.com')
    })
  })

  describe('AppState', () => {
    it('should define app states', () => {
      const states: AppState[] = ['active', 'inactive', 'background']
      expect(states).toContain('active')
      expect(states).toContain('background')
    })
  })

  describe('NotificationOptions', () => {
    it('should define notification options', () => {
      const options: NotificationOptions = {
        id: 'notification-1',
        title: 'New Message',
        body: 'You have a new message',
        sound: 'default',
        badge: 1,
        data: { messageId: '123' },
        categoryId: 'message',
        threadId: 'thread-1'
      }

      expect(options.id).toBe('notification-1')
      expect(options.title).toBe('New Message')
      expect(options.badge).toBe(1)
    })
  })
})
