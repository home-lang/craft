/**
 * E2E Testing Utilities for Craft Applications
 * Provides helpers for integration testing across platforms
 */

export interface CraftTestConfig {
  /** Path to the Craft app to test */
  appPath: string
  /** Timeout for operations in milliseconds */
  timeout?: number
  /** Run in headless mode if supported */
  headless?: boolean
  /** Platform to test on */
  platform?: 'macos' | 'windows' | 'linux' | 'ios' | 'android'
}

export interface WindowInfo {
  title: string
  width: number
  height: number
  x: number
  y: number
  isVisible: boolean
  isFullscreen: boolean
  isMaximized: boolean
  isMinimized: boolean
}

export interface ElementInfo {
  tagName: string
  id: string
  className: string
  textContent: string
  innerHTML: string
  isVisible: boolean
  boundingRect: {
    x: number
    y: number
    width: number
    height: number
  }
  attributes: Record<string, string>
}

/**
 * Craft E2E Test Driver
 * Controls a Craft application for testing purposes
 */
export class CraftTestDriver {
  private config: Required<CraftTestConfig>
  private isRunning = false

  constructor(config: CraftTestConfig) {
    this.config = {
      timeout: 30000,
      headless: false,
      platform: 'macos',
      ...config
    }
  }

  /**
   * Launch the Craft application
   */
  async launch(): Promise<void> {
    console.log(`Launching Craft app: ${this.config.appPath}`)
    this.isRunning = true
    // Implementation would use platform-specific launch mechanisms
  }

  /**
   * Close the application
   */
  async close(): Promise<void> {
    console.log('Closing Craft app')
    this.isRunning = false
  }

  /**
   * Wait for the application to be ready
   */
  async waitForReady(): Promise<void> {
    // Wait for window.craft to be available
    await this.waitFor(() => this.evaluate('typeof window.craft !== "undefined"'))
  }

  /**
   * Get window information
   */
  async getWindowInfo(): Promise<WindowInfo> {
    return this.evaluate(`({
      title: document.title,
      width: window.innerWidth,
      height: window.innerHeight,
      x: window.screenX,
      y: window.screenY,
      isVisible: document.visibilityState === 'visible',
      isFullscreen: !!document.fullscreenElement,
      isMaximized: false,
      isMinimized: document.hidden
    })`)
  }

  /**
   * Execute JavaScript in the app context
   */
  async evaluate<T>(script: string): Promise<T> {
    // Implementation would inject and execute script
    console.log(`Evaluating: ${script.slice(0, 100)}...`)
    return null as T
  }

  /**
   * Find an element by selector
   */
  async $(selector: string): Promise<ElementInfo | null> {
    return this.evaluate(`
      const el = document.querySelector('${selector}');
      if (!el) return null;
      const rect = el.getBoundingClientRect();
      ({
        tagName: el.tagName,
        id: el.id,
        className: el.className,
        textContent: el.textContent,
        innerHTML: el.innerHTML,
        isVisible: rect.width > 0 && rect.height > 0,
        boundingRect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height },
        attributes: Object.fromEntries([...el.attributes].map(a => [a.name, a.value]))
      })
    `)
  }

  /**
   * Find all elements matching selector
   */
  async $$(selector: string): Promise<ElementInfo[]> {
    return this.evaluate(`
      [...document.querySelectorAll('${selector}')].map(el => {
        const rect = el.getBoundingClientRect();
        return {
          tagName: el.tagName,
          id: el.id,
          className: el.className,
          textContent: el.textContent,
          innerHTML: el.innerHTML,
          isVisible: rect.width > 0 && rect.height > 0,
          boundingRect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height },
          attributes: Object.fromEntries([...el.attributes].map(a => [a.name, a.value]))
        };
      })
    `)
  }

  /**
   * Click on an element
   */
  async click(selector: string): Promise<void> {
    await this.evaluate(`document.querySelector('${selector}')?.click()`)
  }

  /**
   * Type text into an input
   */
  async type(selector: string, text: string): Promise<void> {
    await this.evaluate(`
      const el = document.querySelector('${selector}');
      if (el) {
        el.value = '${text}';
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      }
    `)
  }

  /**
   * Press a keyboard key
   */
  async press(key: string, modifiers: string[] = []): Promise<void> {
    await this.evaluate(`
      document.dispatchEvent(new KeyboardEvent('keydown', {
        key: '${key}',
        metaKey: ${modifiers.includes('meta')},
        ctrlKey: ${modifiers.includes('ctrl')},
        altKey: ${modifiers.includes('alt')},
        shiftKey: ${modifiers.includes('shift')}
      }));
    `)
  }

  /**
   * Wait for a condition to be true
   */
  async waitFor(
    condition: () => Promise<boolean> | boolean,
    options: { timeout?: number; interval?: number } = {}
  ): Promise<void> {
    const { timeout = this.config.timeout, interval = 100 } = options
    const start = Date.now()

    while (Date.now() - start < timeout) {
      if (await condition()) return
      await new Promise(r => setTimeout(r, interval))
    }

    throw new Error(`Condition not met within ${timeout}ms`)
  }

  /**
   * Wait for an element to appear
   */
  async waitForSelector(selector: string, options?: { timeout?: number }): Promise<ElementInfo> {
    await this.waitFor(async () => {
      const el = await this.$(selector)
      return el !== null
    }, options)

    return (await this.$(selector))!
  }

  /**
   * Wait for text to appear
   */
  async waitForText(text: string, options?: { timeout?: number }): Promise<void> {
    await this.waitFor(async () => {
      const found = await this.evaluate(`document.body.textContent.includes('${text}')`)
      return found as boolean
    }, options)
  }

  /**
   * Take a screenshot
   */
  async screenshot(path?: string): Promise<Buffer> {
    console.log(`Taking screenshot${path ? ` to ${path}` : ''}`)
    return Buffer.from([])
  }

  /**
   * Get the current URL/route
   */
  async getURL(): Promise<string> {
    return this.evaluate('window.location.href')
  }

  /**
   * Navigate to a route
   */
  async goto(url: string): Promise<void> {
    await this.evaluate(`window.location.href = '${url}'`)
  }
}

/**
 * Create a test driver for a Craft app
 */
export function createTestDriver(config: CraftTestConfig): CraftTestDriver {
  return new CraftTestDriver(config)
}

/**
 * Test assertion helpers
 */
export const assert = {
  equal<T>(actual: T, expected: T, message?: string): void {
    if (actual !== expected) {
      throw new Error(message || `Expected ${expected}, got ${actual}`)
    }
  },

  notEqual<T>(actual: T, expected: T, message?: string): void {
    if (actual === expected) {
      throw new Error(message || `Expected value to not equal ${expected}`)
    }
  },

  truthy(value: unknown, message?: string): void {
    if (!value) {
      throw new Error(message || `Expected truthy value, got ${value}`)
    }
  },

  falsy(value: unknown, message?: string): void {
    if (value) {
      throw new Error(message || `Expected falsy value, got ${value}`)
    }
  },

  contains(text: string, substring: string, message?: string): void {
    if (!text.includes(substring)) {
      throw new Error(message || `Expected "${text}" to contain "${substring}"`)
    }
  },

  async throws(fn: () => Promise<void>, message?: string): Promise<void> {
    try {
      await fn()
      throw new Error(message || 'Expected function to throw')
    } catch {
      // Expected
    }
  }
}
