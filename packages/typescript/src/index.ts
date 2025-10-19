/**
 * Zyte - Build desktop apps with web languages
 * TypeScript SDK powered by Bun
 */

import { spawn, type ChildProcess } from 'node:child_process'
import { existsSync } from 'node:fs'
import { join } from 'node:path'

export interface WindowOptions {
  /**
   * Window title
   */
  title?: string

  /**
   * Window width in pixels
   * @default 800
   */
  width?: number

  /**
   * Window height in pixels
   * @default 600
   */
  height?: number

  /**
   * X position of window
   */
  x?: number

  /**
   * Y position of window
   */
  y?: number

  /**
   * Whether window is resizable
   * @default true
   */
  resizable?: boolean

  /**
   * Whether window is frameless
   * @default false
   */
  frameless?: boolean

  /**
   * Whether window has transparency
   * @default false
   */
  transparent?: boolean

  /**
   * Whether window is always on top
   * @default false
   */
  alwaysOnTop?: boolean

  /**
   * Whether window starts in fullscreen
   * @default false
   */
  fullscreen?: boolean

  /**
   * Enable dark mode
   */
  darkMode?: boolean

  /**
   * Enable hot reload for development
   * @default false
   */
  hotReload?: boolean

  /**
   * Enable developer tools
   * @default false in production, true in development
   */
  devTools?: boolean

  /**
   * Enable system tray icon
   * @default false
   */
  systemTray?: boolean
}

export interface AppConfig {
  /**
   * HTML content to display
   */
  html?: string

  /**
   * URL to load
   */
  url?: string

  /**
   * Window options
   */
  window?: WindowOptions

  /**
   * Path to Zyte binary (auto-detected if not provided)
   */
  zytePath?: string
}

export class ZyteApp {
  private process?: ChildProcess
  private config: AppConfig

  constructor(config: AppConfig = {}) {
    this.config = {
      window: {
        title: 'Zyte App',
        width: 800,
        height: 600,
        resizable: true,
        frameless: false,
        transparent: false,
        alwaysOnTop: false,
        fullscreen: false,
        hotReload: process.env.NODE_ENV === 'development',
        devTools: process.env.NODE_ENV === 'development',
        systemTray: false,
        ...config.window,
      },
      ...config,
    }
  }

  /**
   * Create and show a window with HTML content
   */
  async show(html?: string): Promise<void> {
    if (html) {
      this.config.html = html
    }

    const args = this.buildArgs()
    const zytePath = await this.findZyteBinary()

    this.process = spawn(zytePath, args, {
      stdio: 'inherit',
    })

    return new Promise((resolve, reject) => {
      this.process?.on('error', reject)
      this.process?.on('exit', (code) => {
        if (code === 0) {
          resolve()
        }
        else {
          reject(new Error(`Zyte process exited with code ${code}`))
        }
      })
    })
  }

  /**
   * Load a URL in the window
   */
  async loadURL(url: string): Promise<void> {
    this.config.url = url
    return this.show()
  }

  /**
   * Close the window
   */
  close(): void {
    if (this.process) {
      this.process.kill()
    }
  }

  private buildArgs(): string[] {
    const args: string[] = []
    const { window, html, url } = this.config

    // URL takes precedence over HTML
    if (url) {
      args.push('--url', url)
    }
    else if (html) {
      args.push('--html', html)
    }

    // Window options
    if (window?.title)
      args.push('--title', window.title)
    if (window?.width)
      args.push('--width', String(window.width))
    if (window?.height)
      args.push('--height', String(window.height))
    if (window?.x !== undefined)
      args.push('--x', String(window.x))
    if (window?.y !== undefined)
      args.push('--y', String(window.y))

    // Boolean flags
    if (window?.frameless)
      args.push('--frameless')
    if (window?.transparent)
      args.push('--transparent')
    if (window?.alwaysOnTop)
      args.push('--always-on-top')
    if (window?.fullscreen)
      args.push('--fullscreen')
    if (!window?.resizable)
      args.push('--no-resize')
    if (window?.darkMode)
      args.push('--dark-mode')
    if (window?.hotReload)
      args.push('--hot-reload')
    if (window?.devTools)
      args.push('--dev-tools')
    if (window?.systemTray)
      args.push('--system-tray')

    return args
  }

  private async findZyteBinary(): Promise<string> {
    if (this.config.zytePath) {
      return this.config.zytePath
    }

    // Try common locations
    const possiblePaths = [
      // From monorepo zig package
      join(process.cwd(), 'packages/zig/zig-out/bin/zyte'),
      // From ts-zyte package (when in monorepo)
      join(process.cwd(), '../zig/zig-out/bin/zyte'),
      // Legacy location (for backward compatibility)
      join(process.cwd(), 'zig-out/bin/zyte'),
      join(process.cwd(), '../../zig-out/bin/zyte'),
      // In PATH
      'zyte',
    ]

    for (const path of possiblePaths) {
      if (path === 'zyte') {
        // Check if it's in PATH by trying to spawn it
        try {
          await this.checkBinaryExists(path)
          return path
        }
        catch {
          continue
        }
      }
      else if (existsSync(path)) {
        return path
      }
    }

    throw new Error('Zyte binary not found. Please build the project first with: bun run build:core')
  }

  private checkBinaryExists(path: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const proc = spawn(path, ['--version'], { stdio: 'ignore' })
      proc.on('error', reject)
      proc.on('exit', (code) => {
        if (code === 0 || code === null) {
          resolve()
        }
        else {
          reject(new Error(`Binary check failed with code ${code}`))
        }
      })
    })
  }
}

/**
 * Create a new Zyte app instance
 */
export function createApp(config?: AppConfig): ZyteApp {
  return new ZyteApp(config)
}

/**
 * Quick helper to show a window with HTML
 */
export async function show(html: string, options?: WindowOptions): Promise<void> {
  const app = new ZyteApp({ html, window: options })
  return app.show()
}

/**
 * Quick helper to load a URL
 */
export async function loadURL(url: string, options?: WindowOptions): Promise<void> {
  const app = new ZyteApp({ url, window: options })
  return app.loadURL(url)
}

// Export types
export type { AppConfig, WindowOptions }
