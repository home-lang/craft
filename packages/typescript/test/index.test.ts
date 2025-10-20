import { describe, expect, it, beforeEach } from 'bun:test'
import { ZyteApp, createApp, type WindowOptions, type AppConfig } from '../src/index'

describe('ZyteApp', () => {
  describe('constructor', () => {
    it('should create app with default config', () => {
      const app = new ZyteApp()
      expect(app).toBeInstanceOf(ZyteApp)
    })

    it('should accept custom window options', () => {
      const config: AppConfig = {
        window: {
          title: 'Test App',
          width: 1024,
          height: 768,
        },
      }
      const app = new ZyteApp(config)
      expect(app).toBeInstanceOf(ZyteApp)
    })

    it('should merge custom options with defaults', () => {
      const config: AppConfig = {
        window: {
          title: 'Test App',
        },
      }
      const app = new ZyteApp(config)
      expect(app).toBeInstanceOf(ZyteApp)
    })

    it('should accept HTML content', () => {
      const config: AppConfig = {
        html: '<h1>Test</h1>',
      }
      const app = new ZyteApp(config)
      expect(app).toBeInstanceOf(ZyteApp)
    })

    it('should accept URL', () => {
      const config: AppConfig = {
        url: 'http://localhost:3000',
      }
      const app = new ZyteApp(config)
      expect(app).toBeInstanceOf(ZyteApp)
    })
  })

  describe('Window options', () => {
    it('should handle all boolean flags', () => {
      const options: WindowOptions = {
        frameless: true,
        transparent: true,
        alwaysOnTop: true,
        fullscreen: true,
        resizable: false,
        darkMode: true,
        hotReload: true,
        devTools: true,
        systemTray: true,
      }
      const app = new ZyteApp({ window: options })
      expect(app).toBeInstanceOf(ZyteApp)
    })

    it('should handle position and size options', () => {
      const options: WindowOptions = {
        x: 100,
        y: 200,
        width: 1920,
        height: 1080,
      }
      const app = new ZyteApp({ window: options })
      expect(app).toBeInstanceOf(ZyteApp)
    })
  })

  describe('close', () => {
    it('should not throw when closing app with no process', () => {
      const app = new ZyteApp()
      expect(() => app.close()).not.toThrow()
    })
  })
})

describe('Helper functions', () => {
  describe('createApp', () => {
    it('should create ZyteApp instance', () => {
      const app = createApp()
      expect(app).toBeInstanceOf(ZyteApp)
    })

    it('should accept config', () => {
      const config: AppConfig = {
        window: { title: 'Helper Test' },
      }
      const app = createApp(config)
      expect(app).toBeInstanceOf(ZyteApp)
    })
  })
})

describe('Type exports', () => {
  it('should export WindowOptions type', () => {
    const options: WindowOptions = {
      title: 'Test',
      width: 800,
      height: 600,
    }
    expect(options.title).toBe('Test')
  })

  it('should export AppConfig type', () => {
    const config: AppConfig = {
      html: '<h1>Test</h1>',
      window: {
        title: 'Test',
      },
    }
    expect(config.html).toBe('<h1>Test</h1>')
  })
})

describe('Configuration validation', () => {
  it('should handle empty config', () => {
    const app = new ZyteApp({})
    expect(app).toBeInstanceOf(ZyteApp)
  })

  it('should handle partial window config', () => {
    const app = new ZyteApp({
      window: {
        width: 1200,
      },
    })
    expect(app).toBeInstanceOf(ZyteApp)
  })

  it('should handle custom zytePath', () => {
    const app = new ZyteApp({
      zytePath: '/custom/path/to/zyte',
    })
    expect(app).toBeInstanceOf(ZyteApp)
  })
})
