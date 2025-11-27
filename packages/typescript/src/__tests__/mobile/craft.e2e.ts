/**
 * Craft Mobile E2E Tests
 * Detox tests for iOS and Android
 */

// Mock Detox types for testing
interface DetoxDevice {
  launchApp(options?: { newInstance?: boolean; permissions?: Record<string, string> }): Promise<void>
  reloadReactNative(): Promise<void>
  installApp(): Promise<void>
  uninstallApp(): Promise<void>
  openURL(url: string): Promise<void>
  sendToHome(): Promise<void>
  shake(): Promise<void>
  setLocation(lat: number, lon: number): Promise<void>
  setURLBlacklist(urls: string[]): Promise<void>
  enableSynchronization(): Promise<void>
  disableSynchronization(): Promise<void>
  takeScreenshot(name: string): Promise<string>
  getPlatform(): 'ios' | 'android'
}

interface DetoxElement {
  tap(): Promise<void>
  longPress(duration?: number): Promise<void>
  multiTap(times: number): Promise<void>
  tapAtPoint(point: { x: number; y: number }): Promise<void>
  typeText(text: string): Promise<void>
  replaceText(text: string): Promise<void>
  clearText(): Promise<void>
  scroll(pixels: number, direction: 'up' | 'down' | 'left' | 'right'): Promise<void>
  scrollTo(edge: 'top' | 'bottom' | 'left' | 'right'): Promise<void>
  swipe(direction: 'up' | 'down' | 'left' | 'right', speed?: 'fast' | 'slow', percentage?: number): Promise<void>
  pinch(scale: number, speed?: 'fast' | 'slow', angle?: number): Promise<void>
  atIndex(index: number): DetoxElement
}

interface DetoxMatcher {
  (testID: string): DetoxElement
  text(text: string): DetoxElement
  label(label: string): DetoxElement
  type(nativeType: string): DetoxElement
  traits(traits: string[]): DetoxElement
}

interface DetoxExpect {
  (element: DetoxElement): {
    toBeVisible(): Promise<void>
    toBeNotVisible(): Promise<void>
    toExist(): Promise<void>
    toNotExist(): Promise<void>
    toHaveText(text: string): Promise<void>
    toHaveLabel(label: string): Promise<void>
    toHaveId(id: string): Promise<void>
    toHaveValue(value: string): Promise<void>
    toBeFocused(): Promise<void>
    toHaveToggleValue(value: boolean): Promise<void>
    toHaveSliderPosition(normalizedPosition: number, tolerance?: number): Promise<void>
  }
}

interface DetoxWaitFor {
  (element: DetoxElement): {
    toBeVisible(): { withTimeout(ms: number): Promise<void> }
    toBeNotVisible(): { withTimeout(ms: number): Promise<void> }
    toExist(): { withTimeout(ms: number): Promise<void> }
    toNotExist(): { withTimeout(ms: number): Promise<void> }
  }
}

// Declare global Detox functions
declare const device: DetoxDevice
declare const element: DetoxMatcher
declare const expect: DetoxExpect
declare const waitFor: DetoxWaitFor
declare const by: {
  id(testID: string): any
  text(text: string): any
  label(label: string): any
  type(nativeType: string): any
  traits(traits: string[]): any
}

// Test utilities
export class CraftTestUtils {
  /**
   * Wait for app to be ready
   */
  static async waitForAppReady(timeout = 10000): Promise<void> {
    await waitFor(element(by.id('app-root'))).toBeVisible().withTimeout(timeout)
  }

  /**
   * Login helper
   */
  static async login(username: string, password: string): Promise<void> {
    await element(by.id('username-input')).typeText(username)
    await element(by.id('password-input')).typeText(password)
    await element(by.id('login-button')).tap()
    await waitFor(element(by.id('home-screen'))).toBeVisible().withTimeout(5000)
  }

  /**
   * Navigate to screen
   */
  static async navigateTo(screenId: string): Promise<void> {
    await element(by.id(`nav-${screenId}`)).tap()
    await waitFor(element(by.id(`${screenId}-screen`))).toBeVisible().withTimeout(3000)
  }

  /**
   * Take screenshot with timestamp
   */
  static async screenshot(name: string): Promise<string> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    return device.takeScreenshot(`${name}-${timestamp}`)
  }

  /**
   * Check if running on iOS
   */
  static isIOS(): boolean {
    return device.getPlatform() === 'ios'
  }

  /**
   * Check if running on Android
   */
  static isAndroid(): boolean {
    return device.getPlatform() === 'android'
  }
}

// ============================================
// App Launch Tests
// ============================================

describe('App Launch', () => {
  beforeAll(async () => {
    await device.launchApp()
  })

  beforeEach(async () => {
    await device.reloadReactNative()
  })

  it('should launch app successfully', async () => {
    await CraftTestUtils.waitForAppReady()
    await expect(element(by.id('app-root'))).toBeVisible()
  })

  it('should display splash screen briefly', async () => {
    await device.launchApp({ newInstance: true })
    // Splash should be visible initially
    await expect(element(by.id('splash-screen'))).toBeVisible()
    // Then transition to main app
    await waitFor(element(by.id('app-root'))).toBeVisible().withTimeout(5000)
  })

  it('should handle deep links', async () => {
    await device.openURL('craft://settings')
    await waitFor(element(by.id('settings-screen'))).toBeVisible().withTimeout(3000)
  })
})

// ============================================
// Navigation Tests
// ============================================

describe('Navigation', () => {
  beforeAll(async () => {
    await device.launchApp()
  })

  beforeEach(async () => {
    await device.reloadReactNative()
    await CraftTestUtils.waitForAppReady()
  })

  it('should navigate between tabs', async () => {
    await element(by.id('tab-home')).tap()
    await expect(element(by.id('home-screen'))).toBeVisible()

    await element(by.id('tab-settings')).tap()
    await expect(element(by.id('settings-screen'))).toBeVisible()

    await element(by.id('tab-profile')).tap()
    await expect(element(by.id('profile-screen'))).toBeVisible()
  })

  it('should handle back navigation', async () => {
    await element(by.id('tab-settings')).tap()
    await element(by.id('setting-item-account')).tap()
    await expect(element(by.id('account-screen'))).toBeVisible()

    await element(by.id('back-button')).tap()
    await expect(element(by.id('settings-screen'))).toBeVisible()
  })

  it('should handle hardware back button (Android)', async () => {
    if (!CraftTestUtils.isAndroid()) return

    await element(by.id('tab-settings')).tap()
    await element(by.id('setting-item-account')).tap()
    await expect(element(by.id('account-screen'))).toBeVisible()

    // Simulate hardware back
    await device.sendToHome()
    // App should still be in background, not crashed
  })

  it('should handle swipe gestures for navigation', async () => {
    await element(by.id('tab-home')).tap()
    await element(by.id('list-item-0')).tap()
    await expect(element(by.id('detail-screen'))).toBeVisible()

    // Swipe to go back (iOS)
    if (CraftTestUtils.isIOS()) {
      await element(by.id('detail-screen')).swipe('right', 'fast', 0.5)
      await expect(element(by.id('home-screen'))).toBeVisible()
    }
  })
})

// ============================================
// Form Input Tests
// ============================================

describe('Form Input', () => {
  beforeAll(async () => {
    await device.launchApp()
  })

  beforeEach(async () => {
    await device.reloadReactNative()
    await CraftTestUtils.waitForAppReady()
    await CraftTestUtils.navigateTo('form')
  })

  it('should type text in input field', async () => {
    await element(by.id('text-input')).typeText('Hello Craft')
    await expect(element(by.id('text-input'))).toHaveText('Hello Craft')
  })

  it('should clear text input', async () => {
    await element(by.id('text-input')).typeText('Some text')
    await element(by.id('text-input')).clearText()
    await expect(element(by.id('text-input'))).toHaveText('')
  })

  it('should replace text in input', async () => {
    await element(by.id('text-input')).typeText('Original')
    await element(by.id('text-input')).replaceText('Replaced')
    await expect(element(by.id('text-input'))).toHaveText('Replaced')
  })

  it('should handle numeric keyboard', async () => {
    await element(by.id('number-input')).tap()
    await element(by.id('number-input')).typeText('12345')
    await expect(element(by.id('number-input'))).toHaveText('12345')
  })

  it('should toggle switch', async () => {
    await element(by.id('toggle-switch')).tap()
    await expect(element(by.id('toggle-switch'))).toHaveToggleValue(true)

    await element(by.id('toggle-switch')).tap()
    await expect(element(by.id('toggle-switch'))).toHaveToggleValue(false)
  })

  it('should select from picker', async () => {
    await element(by.id('picker-button')).tap()
    await waitFor(element(by.id('picker-modal'))).toBeVisible().withTimeout(2000)
    await element(by.id('picker-option-2')).tap()
    await expect(element(by.id('picker-value'))).toHaveText('Option 2')
  })
})

// ============================================
// Scroll and List Tests
// ============================================

describe('Scroll and Lists', () => {
  beforeAll(async () => {
    await device.launchApp()
  })

  beforeEach(async () => {
    await device.reloadReactNative()
    await CraftTestUtils.waitForAppReady()
    await CraftTestUtils.navigateTo('list')
  })

  it('should scroll list vertically', async () => {
    await expect(element(by.id('list-item-0'))).toBeVisible()

    await element(by.id('scroll-list')).scroll(500, 'down')

    // Item at top should no longer be visible
    await expect(element(by.id('list-item-0'))).toBeNotVisible()
  })

  it('should scroll to bottom', async () => {
    await element(by.id('scroll-list')).scrollTo('bottom')
    await expect(element(by.id('list-item-last'))).toBeVisible()
  })

  it('should scroll to top', async () => {
    await element(by.id('scroll-list')).scrollTo('bottom')
    await element(by.id('scroll-list')).scrollTo('top')
    await expect(element(by.id('list-item-0'))).toBeVisible()
  })

  it('should pull to refresh', async () => {
    await element(by.id('scroll-list')).swipe('down', 'slow', 0.5)
    await waitFor(element(by.id('refresh-indicator'))).toBeVisible().withTimeout(1000)
    await waitFor(element(by.id('refresh-indicator'))).toBeNotVisible().withTimeout(5000)
  })

  it('should handle horizontal scroll', async () => {
    await CraftTestUtils.navigateTo('carousel')
    await expect(element(by.id('carousel-item-0'))).toBeVisible()

    await element(by.id('carousel')).swipe('left', 'fast')
    await expect(element(by.id('carousel-item-1'))).toBeVisible()
  })
})

// ============================================
// Modal and Dialog Tests
// ============================================

describe('Modals and Dialogs', () => {
  beforeAll(async () => {
    await device.launchApp()
  })

  beforeEach(async () => {
    await device.reloadReactNative()
    await CraftTestUtils.waitForAppReady()
  })

  it('should show and dismiss modal', async () => {
    await element(by.id('show-modal-button')).tap()
    await expect(element(by.id('modal-container'))).toBeVisible()

    await element(by.id('modal-close-button')).tap()
    await expect(element(by.id('modal-container'))).toBeNotVisible()
  })

  it('should show alert dialog', async () => {
    await element(by.id('show-alert-button')).tap()
    await expect(element(by.text('Alert Title'))).toBeVisible()
    await element(by.text('OK')).tap()
  })

  it('should show confirmation dialog', async () => {
    await element(by.id('show-confirm-button')).tap()
    await expect(element(by.text('Confirm Action'))).toBeVisible()

    await element(by.text('Cancel')).tap()
    await expect(element(by.text('Confirm Action'))).toBeNotVisible()

    await element(by.id('show-confirm-button')).tap()
    await element(by.text('Confirm')).tap()
    await expect(element(by.id('confirmed-message'))).toBeVisible()
  })

  it('should show bottom sheet', async () => {
    await element(by.id('show-bottom-sheet-button')).tap()
    await expect(element(by.id('bottom-sheet'))).toBeVisible()

    // Swipe down to dismiss
    await element(by.id('bottom-sheet')).swipe('down', 'fast')
    await expect(element(by.id('bottom-sheet'))).toBeNotVisible()
  })
})

// ============================================
// Gesture Tests
// ============================================

describe('Gestures', () => {
  beforeAll(async () => {
    await device.launchApp()
  })

  beforeEach(async () => {
    await device.reloadReactNative()
    await CraftTestUtils.waitForAppReady()
    await CraftTestUtils.navigateTo('gestures')
  })

  it('should handle tap', async () => {
    await element(by.id('tap-area')).tap()
    await expect(element(by.id('tap-result'))).toHaveText('Tapped!')
  })

  it('should handle long press', async () => {
    await element(by.id('longpress-area')).longPress(2000)
    await expect(element(by.id('longpress-result'))).toHaveText('Long Pressed!')
  })

  it('should handle double tap', async () => {
    await element(by.id('doubletap-area')).multiTap(2)
    await expect(element(by.id('doubletap-result'))).toHaveText('Double Tapped!')
  })

  it('should handle pinch zoom', async () => {
    await element(by.id('pinch-area')).pinch(2, 'slow')
    await expect(element(by.id('pinch-result'))).toHaveText('Zoomed In')

    await element(by.id('pinch-area')).pinch(0.5, 'slow')
    await expect(element(by.id('pinch-result'))).toHaveText('Zoomed Out')
  })

  it('should handle swipe', async () => {
    await element(by.id('swipe-area')).swipe('right')
    await expect(element(by.id('swipe-result'))).toHaveText('Swiped Right')

    await element(by.id('swipe-area')).swipe('left')
    await expect(element(by.id('swipe-result'))).toHaveText('Swiped Left')
  })
})

// ============================================
// Permission Tests
// ============================================

describe('Permissions', () => {
  it('should handle camera permission (iOS)', async () => {
    if (!CraftTestUtils.isIOS()) return

    await device.launchApp({
      permissions: { camera: 'YES' },
    })
    await CraftTestUtils.waitForAppReady()
    await CraftTestUtils.navigateTo('camera')

    await element(by.id('open-camera-button')).tap()
    await expect(element(by.id('camera-view'))).toBeVisible()
  })

  it('should handle location permission', async () => {
    await device.launchApp({
      permissions: { location: 'always' },
    })
    await CraftTestUtils.waitForAppReady()
    await CraftTestUtils.navigateTo('location')

    await element(by.id('get-location-button')).tap()
    await waitFor(element(by.id('location-result'))).toBeVisible().withTimeout(5000)
  })

  it('should handle notification permission', async () => {
    await device.launchApp({
      permissions: { notifications: 'YES' },
    })
    await CraftTestUtils.waitForAppReady()
    await CraftTestUtils.navigateTo('notifications')

    await element(by.id('send-notification-button')).tap()
    await expect(element(by.id('notification-sent'))).toBeVisible()
  })
})

// ============================================
// Performance Tests
// ============================================

describe('Performance', () => {
  beforeAll(async () => {
    await device.launchApp()
  })

  it('should load list of 100 items smoothly', async () => {
    await device.reloadReactNative()
    await CraftTestUtils.waitForAppReady()
    await CraftTestUtils.navigateTo('large-list')

    // Scroll through entire list
    for (let i = 0; i < 10; i++) {
      await element(by.id('large-list')).scroll(1000, 'down')
    }

    // Should still be responsive
    await element(by.id('large-list')).scrollTo('top')
    await expect(element(by.id('list-item-0'))).toBeVisible()
  })

  it('should handle rapid taps without lag', async () => {
    await device.reloadReactNative()
    await CraftTestUtils.waitForAppReady()
    await CraftTestUtils.navigateTo('counter')

    // Rapid tap counter
    for (let i = 0; i < 50; i++) {
      await element(by.id('increment-button')).tap()
    }

    await expect(element(by.id('counter-value'))).toHaveText('50')
  })
})

// ============================================
// Network Tests
// ============================================

describe('Network', () => {
  beforeAll(async () => {
    await device.launchApp()
  })

  beforeEach(async () => {
    await device.reloadReactNative()
    await CraftTestUtils.waitForAppReady()
    await CraftTestUtils.navigateTo('network')
  })

  it('should fetch data from API', async () => {
    await element(by.id('fetch-data-button')).tap()
    await waitFor(element(by.id('data-loaded'))).toBeVisible().withTimeout(10000)
  })

  it('should handle network error gracefully', async () => {
    // Blacklist API URL to simulate network failure
    await device.setURLBlacklist(['.*api.example.com.*'])

    await element(by.id('fetch-data-button')).tap()
    await waitFor(element(by.id('error-message'))).toBeVisible().withTimeout(5000)

    // Clear blacklist
    await device.setURLBlacklist([])
  })
})

export default {
  CraftTestUtils,
}
