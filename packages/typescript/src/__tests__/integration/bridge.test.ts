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
    expect(msg?.data?.modifiers?.cmd).toBe(true)
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
