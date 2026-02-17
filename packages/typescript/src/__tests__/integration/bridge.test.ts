/**
 * Bridge Integration Tests
 * Tests TypeScript ↔ Zig bridge communication patterns
 */

import { describe, it, expect, beforeEach, mock } from 'bun:test'

// ============================================================================
// Mock Bridge for Testing
// ============================================================================

interface BridgeMessage {
  type: string
  action: string
  data?: Record<string, unknown>
}

class MockNativeBridge {
  private messages: BridgeMessage[] = []
  private handlers = new Map<string, (data: unknown) => void>()

  /** Send message to mock native layer */
  postMessage(message: BridgeMessage): void {
    this.messages.push(message)
  }

  /** Get all sent messages */
  getMessages(): BridgeMessage[] {
    return [...this.messages]
  }

  /** Get last sent message */
  getLastMessage(): BridgeMessage | undefined {
    return this.messages[this.messages.length - 1]
  }

  /** Clear all messages */
  clear(): void {
    this.messages = []
  }

  /** Register handler for bridge type */
  on(type: string, handler: (data: unknown) => void): void {
    this.handlers.set(type, handler)
  }

  /** Simulate response from native */
  simulateResponse(type: string, data: unknown): void {
    const handler = this.handlers.get(type)
    if (handler) handler(data)
  }
}

// ============================================================================
// Window Bridge Message Tests
// ============================================================================

describe('Window Bridge Messages', () => {
  let bridge: MockNativeBridge

  beforeEach(() => {
    bridge = new MockNativeBridge()
  })

  it('should format show window message correctly', () => {
    bridge.postMessage({ type: 'window', action: 'show' })
    const msg = bridge.getLastMessage()
    expect(msg?.type).toBe('window')
    expect(msg?.action).toBe('show')
  })

  it('should format setSize message with dimensions', () => {
    bridge.postMessage({
      type: 'window',
      action: 'setSize',
      data: { width: 800, height: 600 },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('setSize')
    expect(msg?.data?.width).toBe(800)
    expect(msg?.data?.height).toBe(600)
  })

  it('should format setPosition message with coordinates', () => {
    bridge.postMessage({
      type: 'window',
      action: 'setPosition',
      data: { x: 100, y: 200 },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('setPosition')
    expect(msg?.data?.x).toBe(100)
    expect(msg?.data?.y).toBe(200)
  })

  it('should format setTitle message with string', () => {
    bridge.postMessage({
      type: 'window',
      action: 'setTitle',
      data: { title: 'My App Window' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('setTitle')
    expect(msg?.data?.title).toBe('My App Window')
  })

  it('should format setVibrancy message with material type', () => {
    const materials = ['sidebar', 'header', 'sheet', 'menu', 'popover', 'hud', 'titlebar', 'none']
    for (const material of materials) {
      bridge.postMessage({
        type: 'window',
        action: 'setVibrancy',
        data: { vibrancy: material },
      })
      const msg = bridge.getLastMessage()
      expect(msg?.data?.vibrancy).toBe(material)
    }
  })

  it('should format setOpacity message with float value', () => {
    bridge.postMessage({
      type: 'window',
      action: 'setOpacity',
      data: { opacity: 0.75 },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('setOpacity')
    expect(msg?.data?.opacity).toBe(0.75)
  })

  it('should format setBackgroundColor message with hex color', () => {
    bridge.postMessage({
      type: 'window',
      action: 'setBackgroundColor',
      data: { color: '#FF5733' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.data?.color).toBe('#FF5733')
  })

  it('should format setBackgroundColor message with RGBA', () => {
    bridge.postMessage({
      type: 'window',
      action: 'setBackgroundColor',
      data: { r: 0.5, g: 0.3, b: 0.8, a: 1.0 },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.data?.r).toBe(0.5)
    expect(msg?.data?.g).toBe(0.3)
    expect(msg?.data?.b).toBe(0.8)
    expect(msg?.data?.a).toBe(1.0)
  })

  it('should format setMinSize message', () => {
    bridge.postMessage({
      type: 'window',
      action: 'setMinSize',
      data: { width: 400, height: 300 },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('setMinSize')
    expect(msg?.data?.width).toBe(400)
  })

  it('should format setMaxSize message', () => {
    bridge.postMessage({
      type: 'window',
      action: 'setMaxSize',
      data: { width: 1920, height: 1080 },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('setMaxSize')
    expect(msg?.data?.width).toBe(1920)
  })

  it('should format boolean actions correctly', () => {
    const booleanActions = [
      { action: 'setAlwaysOnTop', key: 'alwaysOnTop' },
      { action: 'setResizable', key: 'resizable' },
      { action: 'setMovable', key: 'movable' },
      { action: 'setHasShadow', key: 'hasShadow' },
    ]

    for (const { action, key } of booleanActions) {
      bridge.postMessage({
        type: 'window',
        action,
        data: { [key]: true },
      })
      expect(bridge.getLastMessage()?.data?.[key]).toBe(true)

      bridge.postMessage({
        type: 'window',
        action,
        data: { [key]: false },
      })
      expect(bridge.getLastMessage()?.data?.[key]).toBe(false)
    }
  })

  it('should format setAspectRatio message with ratio', () => {
    bridge.postMessage({
      type: 'window',
      action: 'setAspectRatio',
      data: { width: 16, height: 9 },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('setAspectRatio')
    expect(msg?.data?.width).toBe(16)
    expect(msg?.data?.height).toBe(9)
  })

  it('should format setAspectRatio message with single ratio value', () => {
    bridge.postMessage({
      type: 'window',
      action: 'setAspectRatio',
      data: { ratio: 1.777 },
    })
    expect(bridge.getLastMessage()?.data?.ratio).toBe(1.777)
  })

  it('should format flashFrame message', () => {
    bridge.postMessage({
      type: 'window',
      action: 'flashFrame',
      data: { flash: true },
    })
    expect(bridge.getLastMessage()?.action).toBe('flashFrame')
    expect(bridge.getLastMessage()?.data?.flash).toBe(true)
  })

  it('should format setProgressBar message with progress value', () => {
    bridge.postMessage({
      type: 'window',
      action: 'setProgressBar',
      data: { progress: 0.5 },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('setProgressBar')
    expect(msg?.data?.progress).toBe(0.5)
  })

  it('should format setProgressBar message to hide with -1', () => {
    bridge.postMessage({
      type: 'window',
      action: 'setProgressBar',
      data: { progress: -1 },
    })
    expect(bridge.getLastMessage()?.data?.progress).toBe(-1)
  })
})

// ============================================================================
// Tray Bridge Message Tests
// ============================================================================

describe('Tray Bridge Messages', () => {
  let bridge: MockNativeBridge

  beforeEach(() => {
    bridge = new MockNativeBridge()
  })

  it('should format setTitle message', () => {
    bridge.postMessage({
      type: 'tray',
      action: 'setTitle',
      data: { title: 'My App' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.type).toBe('tray')
    expect(msg?.action).toBe('setTitle')
  })

  it('should format setTooltip message', () => {
    bridge.postMessage({
      type: 'tray',
      action: 'setTooltip',
      data: { tooltip: 'Click to open' },
    })
    expect(bridge.getLastMessage()?.data?.tooltip).toBe('Click to open')
  })

  it('should format setIcon message with SF Symbol name', () => {
    bridge.postMessage({
      type: 'tray',
      action: 'setIcon',
      data: { icon: 'star.fill' },
    })
    expect(bridge.getLastMessage()?.data?.icon).toBe('star.fill')
  })

  it('should format hide/show messages', () => {
    bridge.postMessage({ type: 'tray', action: 'hide' })
    expect(bridge.getLastMessage()?.action).toBe('hide')

    bridge.postMessage({ type: 'tray', action: 'show' })
    expect(bridge.getLastMessage()?.action).toBe('show')
  })

  it('should format setMenu message with items', () => {
    const menuItems = [
      { id: 'open', label: 'Open', shortcut: 'cmd+o' },
      { id: 'sep1', type: 'separator' },
      { id: 'quit', label: 'Quit', shortcut: 'cmd+q' },
    ]
    bridge.postMessage({
      type: 'tray',
      action: 'setMenu',
      data: { items: menuItems },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.data?.items).toHaveLength(3)
  })

  it('should format setBadge message with text', () => {
    bridge.postMessage({
      type: 'tray',
      action: 'setBadge',
      data: { badge: '42' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('setBadge')
    expect(msg?.data?.badge).toBe('42')
  })

  it('should format setBadge message to clear', () => {
    bridge.postMessage({
      type: 'tray',
      action: 'setBadge',
      data: { badge: '' },
    })
    expect(bridge.getLastMessage()?.data?.badge).toBe('')
  })
})

// ============================================================================
// Dialog Bridge Message Tests
// ============================================================================

describe('Dialog Bridge Messages', () => {
  let bridge: MockNativeBridge

  beforeEach(() => {
    bridge = new MockNativeBridge()
  })

  it('should format openFile message', () => {
    bridge.postMessage({
      type: 'dialog',
      action: 'openFile',
      data: { title: 'Open File', filters: [{ name: 'Images', extensions: ['png', 'jpg'] }] },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('openFile')
    expect(msg?.data?.title).toBe('Open File')
  })

  it('should format saveFile message with default name', () => {
    bridge.postMessage({
      type: 'dialog',
      action: 'saveFile',
      data: { title: 'Save As', defaultName: 'document.txt' },
    })
    expect(bridge.getLastMessage()?.data?.defaultName).toBe('document.txt')
  })

  it('should format showAlert message', () => {
    bridge.postMessage({
      type: 'dialog',
      action: 'showAlert',
      data: { title: 'Warning', message: 'Are you sure?', style: 'warning' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.data?.title).toBe('Warning')
    expect(msg?.data?.style).toBe('warning')
  })

  it('should format showConfirm message', () => {
    bridge.postMessage({
      type: 'dialog',
      action: 'showConfirm',
      data: { title: 'Confirm', message: 'Delete this item?' },
    })
    expect(bridge.getLastMessage()?.action).toBe('showConfirm')
  })
})

// ============================================================================
// Clipboard Bridge Message Tests
// ============================================================================

describe('Clipboard Bridge Messages', () => {
  let bridge: MockNativeBridge

  beforeEach(() => {
    bridge = new MockNativeBridge()
  })

  it('should format writeText message', () => {
    bridge.postMessage({
      type: 'clipboard',
      action: 'writeText',
      data: { text: 'Hello, World!' },
    })
    expect(bridge.getLastMessage()?.data?.text).toBe('Hello, World!')
  })

  it('should format readText message', () => {
    bridge.postMessage({
      type: 'clipboard',
      action: 'readText',
    })
    expect(bridge.getLastMessage()?.action).toBe('readText')
  })

  it('should format writeHTML message', () => {
    bridge.postMessage({
      type: 'clipboard',
      action: 'writeHTML',
      data: { html: '<h1>Hello</h1>' },
    })
    expect(bridge.getLastMessage()?.data?.html).toBe('<h1>Hello</h1>')
  })

  it('should format clear message', () => {
    bridge.postMessage({
      type: 'clipboard',
      action: 'clear',
    })
    expect(bridge.getLastMessage()?.action).toBe('clear')
  })

  it('should format hasText/hasHTML/hasImage messages', () => {
    for (const action of ['hasText', 'hasHTML', 'hasImage']) {
      bridge.postMessage({ type: 'clipboard', action })
      expect(bridge.getLastMessage()?.action).toBe(action)
    }
  })
})

// ============================================================================
// Error Response Tests
// ============================================================================

describe('Bridge Error Responses', () => {
  let bridge: MockNativeBridge

  beforeEach(() => {
    bridge = new MockNativeBridge()
  })

  it('should handle error response format', () => {
    const errorResponse = {
      error: true,
      code: 'WINDOW_HANDLE_NOT_SET',
      action: 'setSize',
      message: 'Window handle is not initialized',
    }

    bridge.on('error', (data) => {
      expect(data).toEqual(errorResponse)
    })

    bridge.simulateResponse('error', errorResponse)
  })

  it('should handle common error codes', () => {
    const errorCodes = [
      'WINDOW_HANDLE_NOT_SET',
      'WEBVIEW_HANDLE_NOT_SET',
      'TRAY_HANDLE_NOT_SET',
      'UNKNOWN_ACTION',
      'MISSING_DATA',
      'INVALID_JSON',
      'INVALID_PARAMETER',
      'PLATFORM_NOT_SUPPORTED',
      'NATIVE_CALL_FAILED',
      'ALLOCATION_FAILED',
      'CANCELLED',
      'NOT_FOUND',
      'PERMISSION_DENIED',
      'TIMEOUT',
    ]

    for (const code of errorCodes) {
      const error = { error: true, code, action: 'test', message: `Error: ${code}` }
      expect(error.code).toBe(code)
    }
  })
})

// ============================================================================
// JSON Serialization Tests
// ============================================================================

describe('JSON Serialization', () => {
  it('should serialize window size correctly', () => {
    const data = { width: 800, height: 600 }
    const json = JSON.stringify(data)
    expect(json).toBe('{"width":800,"height":600}')
  })

  it('should serialize position with negative values', () => {
    const data = { x: -100, y: -200 }
    const json = JSON.stringify(data)
    expect(json).toBe('{"x":-100,"y":-200}')
  })

  it('should serialize float values', () => {
    const data = { opacity: 0.75 }
    const json = JSON.stringify(data)
    expect(json).toBe('{"opacity":0.75}')
  })

  it('should serialize boolean values', () => {
    const data = { enabled: true, disabled: false }
    const json = JSON.stringify(data)
    expect(json).toBe('{"enabled":true,"disabled":false}')
  })

  it('should serialize special characters in strings', () => {
    const data = { title: 'Hello "World"' }
    const json = JSON.stringify(data)
    expect(json).toBe('{"title":"Hello \\"World\\""}')
  })

  it('should serialize Unicode characters', () => {
    const data = { emoji: '🍅' }
    const json = JSON.stringify(data)
    const parsed = JSON.parse(json)
    expect(parsed.emoji).toBe('🍅')
  })

  it('should serialize nested objects', () => {
    const data = {
      window: { size: { width: 800, height: 600 }, position: { x: 100, y: 100 } },
    }
    const json = JSON.stringify(data)
    const parsed = JSON.parse(json)
    expect(parsed.window.size.width).toBe(800)
    expect(parsed.window.position.x).toBe(100)
  })

  it('should serialize arrays', () => {
    const data = { items: ['a', 'b', 'c'] }
    const json = JSON.stringify(data)
    expect(json).toBe('{"items":["a","b","c"]}')
  })
})

// ============================================================================
// Notification Bridge Message Tests
// ============================================================================

describe('Notification Bridge Messages', () => {
  let bridge: MockNativeBridge

  beforeEach(() => {
    bridge = new MockNativeBridge()
  })

  it('should format show notification message', () => {
    bridge.postMessage({
      type: 'notification',
      action: 'show',
      data: { id: 'notif1', title: 'Hello', body: 'World', sound: true },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.type).toBe('notification')
    expect(msg?.action).toBe('show')
    expect(msg?.data?.title).toBe('Hello')
    expect(msg?.data?.body).toBe('World')
  })

  it('should format schedule notification message', () => {
    bridge.postMessage({
      type: 'notification',
      action: 'schedule',
      data: { id: 'reminder', title: 'Reminder', body: 'Time to take a break', delay: 60 },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('schedule')
    expect(msg?.data?.delay).toBe(60)
  })

  it('should format cancel notification message', () => {
    bridge.postMessage({
      type: 'notification',
      action: 'cancel',
      data: { id: 'reminder' },
    })
    expect(bridge.getLastMessage()?.action).toBe('cancel')
    expect(bridge.getLastMessage()?.data?.id).toBe('reminder')
  })

  it('should format cancelAll notification message', () => {
    bridge.postMessage({ type: 'notification', action: 'cancelAll' })
    expect(bridge.getLastMessage()?.action).toBe('cancelAll')
  })

  it('should format setBadge notification message', () => {
    bridge.postMessage({
      type: 'notification',
      action: 'setBadge',
      data: { count: 5 },
    })
    expect(bridge.getLastMessage()?.data?.count).toBe(5)
  })

  it('should format clearBadge notification message', () => {
    bridge.postMessage({ type: 'notification', action: 'clearBadge' })
    expect(bridge.getLastMessage()?.action).toBe('clearBadge')
  })

  it('should format requestPermission notification message', () => {
    bridge.postMessage({ type: 'notification', action: 'requestPermission' })
    expect(bridge.getLastMessage()?.action).toBe('requestPermission')
  })
})

// ============================================================================
// Shortcuts Bridge Message Tests
// ============================================================================

describe('Shortcuts Bridge Messages', () => {
  let bridge: MockNativeBridge

  beforeEach(() => {
    bridge = new MockNativeBridge()
  })

  it('should format register shortcut message', () => {
    bridge.postMessage({
      type: 'shortcuts',
      action: 'register',
      data: {
        id: 'toggle',
        key: 'Space',
        modifiers: { cmd: true, shift: true },
        callback: 'onToggle',
      },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.type).toBe('shortcuts')
    expect(msg?.action).toBe('register')
    expect(msg?.data?.key).toBe('Space')
    expect((msg?.data?.modifiers as Record<string, unknown>)?.cmd).toBe(true)
  })

  it('should format unregister shortcut message', () => {
    bridge.postMessage({
      type: 'shortcuts',
      action: 'unregister',
      data: { id: 'toggle' },
    })
    expect(bridge.getLastMessage()?.action).toBe('unregister')
    expect(bridge.getLastMessage()?.data?.id).toBe('toggle')
  })

  it('should format unregisterAll shortcut message', () => {
    bridge.postMessage({ type: 'shortcuts', action: 'unregisterAll' })
    expect(bridge.getLastMessage()?.action).toBe('unregisterAll')
  })

  it('should format enable shortcut message', () => {
    bridge.postMessage({
      type: 'shortcuts',
      action: 'enable',
      data: { id: 'toggle' },
    })
    expect(bridge.getLastMessage()?.action).toBe('enable')
  })

  it('should format disable shortcut message', () => {
    bridge.postMessage({
      type: 'shortcuts',
      action: 'disable',
      data: { id: 'toggle' },
    })
    expect(bridge.getLastMessage()?.action).toBe('disable')
  })

  it('should format list shortcuts message', () => {
    bridge.postMessage({ type: 'shortcuts', action: 'list' })
    expect(bridge.getLastMessage()?.action).toBe('list')
  })

  it('should format isRegistered shortcut message', () => {
    bridge.postMessage({
      type: 'shortcuts',
      action: 'isRegistered',
      data: { id: 'toggle' },
    })
    expect(bridge.getLastMessage()?.action).toBe('isRegistered')
  })
})

// ============================================================================
// Menu Bridge Message Tests
// ============================================================================

describe('Menu Bridge Messages', () => {
  let bridge: MockNativeBridge

  beforeEach(() => {
    bridge = new MockNativeBridge()
  })

  it('should format setAppMenu message with items', () => {
    const menuItems = [
      {
        id: 'file',
        label: 'File',
        submenu: [
          { id: 'new', label: 'New', shortcut: 'cmd+n' },
          { id: 'open', label: 'Open', shortcut: 'cmd+o' },
          { id: 'sep1', type: 'separator' },
          { id: 'quit', label: 'Quit', shortcut: 'cmd+q' },
        ],
      },
    ]
    bridge.postMessage({
      type: 'menu',
      action: 'setAppMenu',
      data: { items: menuItems },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.type).toBe('menu')
    expect(msg?.action).toBe('setAppMenu')
    expect(msg?.data?.items).toHaveLength(1)
  })

  it('should format setDockMenu message', () => {
    const dockItems = [
      { id: 'show', label: 'Show Window' },
      { id: 'hide', label: 'Hide Window' },
    ]
    bridge.postMessage({
      type: 'menu',
      action: 'setDockMenu',
      data: { items: dockItems },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('setDockMenu')
    expect(msg?.data?.items).toHaveLength(2)
  })

  it('should format clearDockMenu message', () => {
    bridge.postMessage({ type: 'menu', action: 'clearDockMenu' })
    expect(bridge.getLastMessage()?.action).toBe('clearDockMenu')
  })

  it('should format enableMenuItem message', () => {
    bridge.postMessage({
      type: 'menu',
      action: 'enableMenuItem',
      data: { id: 'save' },
    })
    expect(bridge.getLastMessage()?.action).toBe('enableMenuItem')
    expect(bridge.getLastMessage()?.data?.id).toBe('save')
  })

  it('should format disableMenuItem message', () => {
    bridge.postMessage({
      type: 'menu',
      action: 'disableMenuItem',
      data: { id: 'save' },
    })
    expect(bridge.getLastMessage()?.action).toBe('disableMenuItem')
  })

  it('should format checkMenuItem message', () => {
    bridge.postMessage({
      type: 'menu',
      action: 'checkMenuItem',
      data: { id: 'autoSave' },
    })
    expect(bridge.getLastMessage()?.action).toBe('checkMenuItem')
    expect(bridge.getLastMessage()?.data?.id).toBe('autoSave')
  })

  it('should format uncheckMenuItem message', () => {
    bridge.postMessage({
      type: 'menu',
      action: 'uncheckMenuItem',
      data: { id: 'autoSave' },
    })
    expect(bridge.getLastMessage()?.action).toBe('uncheckMenuItem')
  })

  it('should format setMenuItemLabel message', () => {
    bridge.postMessage({
      type: 'menu',
      action: 'setMenuItemLabel',
      data: { id: 'status', label: 'Running...' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('setMenuItemLabel')
    expect(msg?.data?.label).toBe('Running...')
  })

  it('should format menu items with keyboard shortcuts', () => {
    bridge.postMessage({
      type: 'menu',
      action: 'setAppMenu',
      data: {
        items: [
          { id: 'copy', label: 'Copy', shortcut: 'cmd+c' },
          { id: 'paste', label: 'Paste', shortcut: 'cmd+v' },
          { id: 'selectAll', label: 'Select All', shortcut: 'cmd+a' },
          { id: 'find', label: 'Find', shortcut: 'cmd+shift+f' },
        ],
      },
    })
    const items = bridge.getLastMessage()?.data?.items as { shortcut: string }[]
    expect(items[0].shortcut).toBe('cmd+c')
    expect(items[3].shortcut).toBe('cmd+shift+f')
  })

  it('should format menu items with nested submenus', () => {
    const menuItems = [
      {
        id: 'edit',
        label: 'Edit',
        submenu: [
          {
            id: 'transform',
            label: 'Transform',
            submenu: [
              { id: 'uppercase', label: 'Make Uppercase' },
              { id: 'lowercase', label: 'Make Lowercase' },
            ],
          },
        ],
      },
    ]
    bridge.postMessage({
      type: 'menu',
      action: 'setAppMenu',
      data: { items: menuItems },
    })
    const items = bridge.getLastMessage()?.data?.items as { submenu: { submenu: unknown[] }[] }[]
    expect(items[0].submenu[0].submenu).toHaveLength(2)
  })
})

// ============================================================================
// Updater Bridge Message Tests
// ============================================================================

describe('Updater Bridge Messages', () => {
  let bridge: MockNativeBridge

  beforeEach(() => {
    bridge = new MockNativeBridge()
  })

  it('should format configure message', () => {
    bridge.postMessage({
      type: 'updater',
      action: 'configure',
      data: {
        feedURL: 'https://example.com/appcast.xml',
        automaticChecks: true,
        checkInterval: 86400,
      },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.type).toBe('updater')
    expect(msg?.action).toBe('configure')
    expect(msg?.data?.feedURL).toBe('https://example.com/appcast.xml')
    expect(msg?.data?.automaticChecks).toBe(true)
  })

  it('should format checkForUpdates message', () => {
    bridge.postMessage({ type: 'updater', action: 'checkForUpdates' })
    expect(bridge.getLastMessage()?.action).toBe('checkForUpdates')
  })

  it('should format checkForUpdatesInBackground message', () => {
    bridge.postMessage({ type: 'updater', action: 'checkForUpdatesInBackground' })
    expect(bridge.getLastMessage()?.action).toBe('checkForUpdatesInBackground')
  })

  it('should format setAutomaticChecks message', () => {
    bridge.postMessage({
      type: 'updater',
      action: 'setAutomaticChecks',
      data: { enabled: true },
    })
    expect(bridge.getLastMessage()?.data?.enabled).toBe(true)
  })

  it('should format setCheckInterval message', () => {
    bridge.postMessage({
      type: 'updater',
      action: 'setCheckInterval',
      data: { interval: 43200 },
    })
    expect(bridge.getLastMessage()?.data?.interval).toBe(43200)
  })

  it('should format setFeedURL message', () => {
    bridge.postMessage({
      type: 'updater',
      action: 'setFeedURL',
      data: { url: 'https://myapp.com/updates.xml' },
    })
    expect(bridge.getLastMessage()?.data?.url).toBe('https://myapp.com/updates.xml')
  })

  it('should format getLastUpdateCheckDate message', () => {
    bridge.postMessage({ type: 'updater', action: 'getLastUpdateCheckDate' })
    expect(bridge.getLastMessage()?.action).toBe('getLastUpdateCheckDate')
  })

  it('should format getUpdateInfo message', () => {
    bridge.postMessage({ type: 'updater', action: 'getUpdateInfo' })
    expect(bridge.getLastMessage()?.action).toBe('getUpdateInfo')
  })
})

// ============================================================================
// Touch Bar Bridge Message Tests
// ============================================================================

describe('Touch Bar Bridge Messages', () => {
  let bridge: MockNativeBridge

  beforeEach(() => {
    bridge = new MockNativeBridge()
  })

  it('should format setItems message with button items', () => {
    bridge.postMessage({
      type: 'touchbar',
      action: 'setItems',
      data: {
        items: [
          { id: 'play', type: 'button', label: 'Play', icon: 'play.fill' },
          { id: 'pause', type: 'button', label: 'Pause', icon: 'pause.fill' },
        ],
      },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.type).toBe('touchbar')
    expect(msg?.action).toBe('setItems')
    expect(msg?.data?.items).toHaveLength(2)
  })

  it('should format addItem message', () => {
    bridge.postMessage({
      type: 'touchbar',
      action: 'addItem',
      data: { id: 'stop', type: 'button', label: 'Stop', icon: 'stop.fill' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('addItem')
    expect(msg?.data?.id).toBe('stop')
  })

  it('should format removeItem message', () => {
    bridge.postMessage({
      type: 'touchbar',
      action: 'removeItem',
      data: { id: 'stop' },
    })
    expect(bridge.getLastMessage()?.data?.id).toBe('stop')
  })

  it('should format updateItem message', () => {
    bridge.postMessage({
      type: 'touchbar',
      action: 'updateItem',
      data: { id: 'play', label: 'Playing...', icon: 'pause.fill' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('updateItem')
    expect(msg?.data?.label).toBe('Playing...')
  })

  it('should format slider item with min/max/value', () => {
    bridge.postMessage({
      type: 'touchbar',
      action: 'addItem',
      data: { id: 'volume', type: 'slider', label: 'Volume', min: 0, max: 100, value: 50 },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.data?.type).toBe('slider')
    expect(msg?.data?.min).toBe(0)
    expect(msg?.data?.max).toBe(100)
    expect(msg?.data?.value).toBe(50)
  })

  it('should format setSliderValue message', () => {
    bridge.postMessage({
      type: 'touchbar',
      action: 'setSliderValue',
      data: { id: 'volume', value: 75 },
    })
    expect(bridge.getLastMessage()?.data?.value).toBe(75)
  })

  it('should format setItemEnabled message', () => {
    bridge.postMessage({
      type: 'touchbar',
      action: 'setItemEnabled',
      data: { id: 'save', enabled: false },
    })
    expect(bridge.getLastMessage()?.data?.enabled).toBe(false)
  })

  it('should format clear message', () => {
    bridge.postMessage({ type: 'touchbar', action: 'clear' })
    expect(bridge.getLastMessage()?.action).toBe('clear')
  })

  it('should format show/hide messages', () => {
    bridge.postMessage({ type: 'touchbar', action: 'show' })
    expect(bridge.getLastMessage()?.action).toBe('show')

    bridge.postMessage({ type: 'touchbar', action: 'hide' })
    expect(bridge.getLastMessage()?.action).toBe('hide')
  })

  it('should format color picker item', () => {
    bridge.postMessage({
      type: 'touchbar',
      action: 'addItem',
      data: { id: 'color', type: 'colorPicker', callback: 'onColorChange' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.data?.type).toBe('colorPicker')
    expect(msg?.data?.callback).toBe('onColorChange')
  })

  it('should format label item', () => {
    bridge.postMessage({
      type: 'touchbar',
      action: 'addItem',
      data: { id: 'status', type: 'label', label: 'Ready' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.data?.type).toBe('label')
    expect(msg?.data?.label).toBe('Ready')
  })
})

// ============================================================================
// File System Bridge Message Tests
// ============================================================================

describe('File System Bridge Messages', () => {
  let bridge: MockNativeBridge

  beforeEach(() => {
    bridge = new MockNativeBridge()
  })

  it('should format readFile message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'readFile',
      data: { path: '/path/to/file.txt', callbackId: 'cb1' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.type).toBe('fs')
    expect(msg?.action).toBe('readFile')
    expect(msg?.data?.path).toBe('/path/to/file.txt')
  })

  it('should format writeFile message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'writeFile',
      data: { path: '/path/to/file.txt', content: 'Hello World' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('writeFile')
    expect(msg?.data?.content).toBe('Hello World')
  })

  it('should format appendFile message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'appendFile',
      data: { path: '/path/to/log.txt', content: 'New log entry\n' },
    })
    expect(bridge.getLastMessage()?.action).toBe('appendFile')
  })

  it('should format deleteFile message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'deleteFile',
      data: { path: '/path/to/file.txt' },
    })
    expect(bridge.getLastMessage()?.action).toBe('deleteFile')
    expect(bridge.getLastMessage()?.data?.path).toBe('/path/to/file.txt')
  })

  it('should format exists message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'exists',
      data: { path: '/path/to/check', callbackId: 'cb2' },
    })
    expect(bridge.getLastMessage()?.action).toBe('exists')
  })

  it('should format stat message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'stat',
      data: { path: '/path/to/file', callbackId: 'cb3' },
    })
    expect(bridge.getLastMessage()?.action).toBe('stat')
  })

  it('should format readDir message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'readDir',
      data: { path: '/path/to/dir', callbackId: 'cb4' },
    })
    expect(bridge.getLastMessage()?.action).toBe('readDir')
  })

  it('should format mkdir message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'mkdir',
      data: { path: '/path/to/new/dir' },
    })
    expect(bridge.getLastMessage()?.action).toBe('mkdir')
  })

  it('should format rmdir message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'rmdir',
      data: { path: '/path/to/dir' },
    })
    expect(bridge.getLastMessage()?.action).toBe('rmdir')
  })

  it('should format copy message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'copy',
      data: { src: '/path/from/file.txt', dest: '/path/to/file.txt' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('copy')
    expect(msg?.data?.src).toBe('/path/from/file.txt')
    expect(msg?.data?.dest).toBe('/path/to/file.txt')
  })

  it('should format move message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'move',
      data: { src: '/old/path.txt', dest: '/new/path.txt' },
    })
    expect(bridge.getLastMessage()?.action).toBe('move')
  })

  it('should format watch message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'watch',
      data: { id: 'watcher1', path: '/path/to/watch' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('watch')
    expect(msg?.data?.id).toBe('watcher1')
  })

  it('should format unwatch message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'unwatch',
      data: { id: 'watcher1' },
    })
    expect(bridge.getLastMessage()?.action).toBe('unwatch')
  })

  it('should format getHomeDir message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'getHomeDir',
      data: { callbackId: 'cb5' },
    })
    expect(bridge.getLastMessage()?.action).toBe('getHomeDir')
  })

  it('should format getTempDir message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'getTempDir',
      data: { callbackId: 'cb6' },
    })
    expect(bridge.getLastMessage()?.action).toBe('getTempDir')
  })

  it('should format getAppDataDir message', () => {
    bridge.postMessage({
      type: 'fs',
      action: 'getAppDataDir',
      data: { callbackId: 'cb7' },
    })
    expect(bridge.getLastMessage()?.action).toBe('getAppDataDir')
  })
})

// ============================================================================
// Shell Commands Bridge Message Tests
// ============================================================================

describe('Shell Commands Bridge Messages', () => {
  let bridge: MockNativeBridge

  beforeEach(() => {
    bridge = new MockNativeBridge()
  })

  it('should format exec message', () => {
    bridge.postMessage({
      type: 'shell',
      action: 'exec',
      data: { command: 'ls -la', cwd: '/home', callbackId: 'cb1' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.type).toBe('shell')
    expect(msg?.action).toBe('exec')
    expect(msg?.data?.command).toBe('ls -la')
    expect(msg?.data?.cwd).toBe('/home')
  })

  it('should format spawn message', () => {
    bridge.postMessage({
      type: 'shell',
      action: 'spawn',
      data: { id: 'proc1', command: 'node server.js', cwd: '/app' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('spawn')
    expect(msg?.data?.id).toBe('proc1')
    expect(msg?.data?.command).toBe('node server.js')
  })

  it('should format kill message', () => {
    bridge.postMessage({
      type: 'shell',
      action: 'kill',
      data: { id: 'proc1' },
    })
    expect(bridge.getLastMessage()?.action).toBe('kill')
    expect(bridge.getLastMessage()?.data?.id).toBe('proc1')
  })

  it('should format openUrl message', () => {
    bridge.postMessage({
      type: 'shell',
      action: 'openUrl',
      data: { url: 'https://example.com' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('openUrl')
    expect(msg?.data?.url).toBe('https://example.com')
  })

  it('should format openPath message', () => {
    bridge.postMessage({
      type: 'shell',
      action: 'openPath',
      data: { path: '/path/to/file.pdf' },
    })
    expect(bridge.getLastMessage()?.action).toBe('openPath')
    expect(bridge.getLastMessage()?.data?.path).toBe('/path/to/file.pdf')
  })

  it('should format showInFinder message', () => {
    bridge.postMessage({
      type: 'shell',
      action: 'showInFinder',
      data: { path: '/path/to/reveal' },
    })
    expect(bridge.getLastMessage()?.action).toBe('showInFinder')
  })

  it('should format getEnv message', () => {
    bridge.postMessage({
      type: 'shell',
      action: 'getEnv',
      data: { name: 'PATH', callbackId: 'cb2' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('getEnv')
    expect(msg?.data?.name).toBe('PATH')
  })

  it('should format setEnv message', () => {
    bridge.postMessage({
      type: 'shell',
      action: 'setEnv',
      data: { name: 'MY_VAR', value: 'my_value' },
    })
    const msg = bridge.getLastMessage()
    expect(msg?.action).toBe('setEnv')
    expect(msg?.data?.name).toBe('MY_VAR')
    expect(msg?.data?.value).toBe('my_value')
  })
})

// ============================================================================
// Message Queue Tests
// ============================================================================

describe('Message Queue', () => {
  let bridge: MockNativeBridge

  beforeEach(() => {
    bridge = new MockNativeBridge()
  })

  it('should queue multiple messages', () => {
    bridge.postMessage({ type: 'window', action: 'show' })
    bridge.postMessage({ type: 'window', action: 'setSize', data: { width: 800, height: 600 } })
    bridge.postMessage({ type: 'window', action: 'center' })

    const messages = bridge.getMessages()
    expect(messages).toHaveLength(3)
    expect(messages[0].action).toBe('show')
    expect(messages[1].action).toBe('setSize')
    expect(messages[2].action).toBe('center')
  })

  it('should clear message queue', () => {
    bridge.postMessage({ type: 'window', action: 'show' })
    bridge.postMessage({ type: 'window', action: 'hide' })
    expect(bridge.getMessages()).toHaveLength(2)

    bridge.clear()
    expect(bridge.getMessages()).toHaveLength(0)
  })
})
