/**
 * Zyte - Build desktop apps with web languages
 * TypeScript SDK powered by Bun
 */

import { spawn, type ChildProcess } from 'node:child_process'
import { existsSync } from 'node:fs'
import { join } from 'node:path'
import type { AppConfig, WindowOptions } from './types'

// Export packaging API
export { packageApp, pack, type PackageConfig, type PackageResult } from './package'

export class ZyteApp {
  private process?: ChildProcess
  private config: AppConfig

  constructor(config: AppConfig = {}) {
    // Validate window dimensions
    if (config.window?.width !== undefined && (config.window.width < 100 || config.window.width > 10000)) {
      throw new Error(`Invalid window width: ${config.window.width}. Must be between 100 and 10000 pixels.`)
    }
    if (config.window?.height !== undefined && (config.window.height < 100 || config.window.height > 10000)) {
      throw new Error(`Invalid window height: ${config.window.height}. Must be between 100 and 10000 pixels.`)
    }

    // Validate that either html or url is provided, not both
    if (config.html && config.url) {
      console.warn('⚠️  Both html and url provided. URL will take precedence.')
    }

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

    // Validate that we have something to show
    if (!this.config.html && !this.config.url) {
      throw new Error(
        'No content to display. Provide either html or url:\n' +
        '  show(html, options) or loadURL(url, options)'
      )
    }

    const args = this.buildArgs()
    const zytePath = await this.findZyteBinary()

    this.process = spawn(zytePath, args, {
      stdio: 'inherit',
    })

    return new Promise((resolve, reject) => {
      this.process?.on('error', (error: Error & { code?: string }) => {
        const errorMessage = [
          `❌ Failed to start Zyte process: ${error.message}`,
          '',
        ]

        // Provide platform-specific troubleshooting
        if (error.code === 'EACCES') {
          errorMessage.push(
            'Permission denied. Try making the binary executable:',
            `  chmod +x ${zytePath}`,
          )
        }
        else if (error.code === 'ENOENT') {
          errorMessage.push(
            'Binary not found or not executable.',
            'Ensure Zyte core is built:',
            '  bun run build:core',
          )
        }
        else {
          errorMessage.push(
            'For troubleshooting, visit:',
            '  https://github.com/stacksjs/zyte/issues',
          )
        }

        reject(new Error(errorMessage.join('\n')))
      })

      this.process?.on('exit', (code) => {
        if (code === 0 || code === null) {
          resolve()
        }
        else {
          reject(new Error(
            `❌ Zyte process exited with code ${code}\n\n` +
            'This may indicate:\n' +
            '  • Invalid window configuration\n' +
            '  • Malformed HTML content\n' +
            '  • System resource constraints\n\n' +
            'Check the console output above for more details.'
          ))
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
    if (window?.hideDockIcon)
      args.push('--hide-dock-icon')

    return args
  }

  private async findZyteBinary(): Promise<string> {
    if (this.config.zytePath) {
      if (!existsSync(this.config.zytePath)) {
        throw new Error(
          `Custom Zyte binary path not found: ${this.config.zytePath}\n\n` +
          'Please ensure the path is correct or build the Zyte core:\n' +
          '  bun run build:core'
        )
      }
      return this.config.zytePath
    }

    // Try common locations
    const possiblePaths = [
      // From monorepo zig package (current binary names)
      join(process.cwd(), 'packages/zig/zig-out/bin/zyte-minimal'),
      join(process.cwd(), 'packages/zig/zig-out/bin/zyte-example'),
      join(process.cwd(), 'packages/zig/zig-out/bin/zyte'),
      // From ts-zyte package (when in monorepo)
      join(process.cwd(), '../zig/zig-out/bin/zyte-minimal'),
      join(process.cwd(), '../zig/zig-out/bin/zyte-example'),
      join(process.cwd(), '../zig/zig-out/bin/zyte'),
      // Legacy locations (for backward compatibility)
      join(process.cwd(), 'zig-out/bin/zyte-minimal'),
      join(process.cwd(), 'zig-out/bin/zyte'),
      join(process.cwd(), '../../zig-out/bin/zyte'),
      // In PATH
      'zyte-minimal',
      'zyte',
    ]

    for (const path of possiblePaths) {
      if (path === 'zyte' || path === 'zyte-minimal') {
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

    // Provide helpful error message with troubleshooting steps
    const errorMessage = [
      '❌ Zyte binary not found',
      '',
      'Tried the following locations:',
      ...possiblePaths.map(p => `  • ${p}`),
      '',
      'To fix this issue:',
      '',
      '1. Build the Zyte core:',
      '   bun run build:core',
      '',
      '2. Or install Zyte globally:',
      '   bun install -g ts-zyte',
      '',
      '3. Or specify a custom binary path:',
      '   createApp({ zytePath: "/path/to/zyte" })',
      '',
      'For more help, visit: https://github.com/stacksjs/zyte',
    ].join('\n')

    throw new Error(errorMessage)
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

export * from './types'