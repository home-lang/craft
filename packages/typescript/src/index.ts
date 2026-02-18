/**
 * Craft - Build desktop apps with web languages
 * TypeScript SDK powered by Bun
 */

import { spawn, type ChildProcess } from 'node:child_process'
import { existsSync } from 'node:fs'
import { join } from 'node:path'
import type { AppConfig, WindowOptions } from './types'

// Export packaging API
export { packageApp, pack, type PackageConfig, type PackageResult } from './package'

// Export utilities
export * from './utils'

// Export API modules
export * from './api'

// Export component abstractions (React Native-style primitives)
// Use explicit exports to avoid conflicts with names from './api':
// Excluded duplicates: Sidebar, createSidebar, SidebarItem, SidebarSection,
// SidebarConfig, TouchBarItem, TableColumn, Platform
export {
  // Sidebar (component variants, aliased to avoid conflict with api/sidebar)
  createTahoeSidebar,
  createArcSidebar,
  createOrbStackSidebar,
  sidebarItem,
  sidebarSection,
  sidebarSeparator,
  tahoeStyle,
  arcStyle,
  orbstackStyle,

  // Native UI Components
  createSplitView,
  SplitViewInstance,
  createFileBrowser,
  FileBrowserInstance,
  createOutlineView,
  OutlineViewInstance,
  createTableView,
  TableViewInstance,
  showQuickLook,
  hideQuickLook,
  canQuickLook,
  showColorPicker,
  showFontPicker,
  showDatePicker,
  createProgress,
  ProgressInstance,
  setToolbar,
  updateToolbarItem,
  setToolbarVisible,
  setTouchBar,
  updateTouchBarItem,

  // Animated & StyleSheet
  StyleSheet,
  Animated,
} from './components'
export type {
  // Sidebar types (excluding duplicates with api)
  ContextMenuItem,
  SidebarStyle,
  SidebarPosition,
  SidebarHeaderConfig,
  SidebarFooterConfig,
  SidebarEventType,
  SidebarEventMap,
  SidebarEventHandler,

  // Native component types (excluding duplicates with api)
  ComponentProps,
  ComponentInstance,
  SplitViewOrientation,
  SplitViewDividerStyle,
  SplitViewConfig,
  FileBrowserConfig,
  FileBrowserSelection,
  OutlineItem,
  OutlineViewConfig,
  TableRow,
  TableViewConfig,
  QuickLookConfig,
  ColorPickerConfig,
  FontPickerConfig,
  FontResult,
  DatePickerConfig,
  ProgressConfig,
  ToolbarItem,
  ToolbarConfig,
  TouchBarConfig,

  // Style types
  FlexStyle,
  LayoutStyle,
  SpacingStyle,
  BorderStyle,
  ColorStyle,
  ShadowStyle,
  TransformStyle,
  ViewStyle,
  TextStyleProps,
  TextStyle,
  ImageStyleProps,
  ImageStyle,

  // Component props
  BaseProps,
  ViewProps,
  TextProps,
  ImageSource,
  ImageProps,
  ScrollViewProps,
  PressableProps,
  TextInputProps,
  FlatListProps,

  // Events
  LayoutEvent,
  ScrollEvent,
} from './components'

// Export styling utilities (Headwind CSS integration + Sidebar styles)
export * from './styles/headwind'
export * from './styles'

// Export framework-specific optimizations
export * from './optimizations'

export class CraftApp {
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
        title: 'Craft App',
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

    // Validate that we have something to show (unless it's menubar-only mode)
    if (!this.config.window?.menubarOnly && !this.config.html && !this.config.url) {
      throw new Error(
        'No content to display. Provide either html or url:\n' +
        '  show(html, options) or loadURL(url, options)'
      )
    }

    const args = this.buildArgs()
    const craftPath = await this.findCraftBinary()

    this.process = spawn(craftPath, args, {
      stdio: 'inherit',
    })

    return new Promise((resolve, reject) => {
      this.process?.on('error', (error: Error & { code?: string }) => {
        const errorMessage = [
          `❌ Failed to start Craft process: ${error.message}`,
          '',
        ]

        // Provide platform-specific troubleshooting
        if (error.code === 'EACCES') {
          errorMessage.push(
            'Permission denied. Try making the binary executable:',
            `  chmod +x ${craftPath}`,
          )
        }
        else if (error.code === 'ENOENT') {
          errorMessage.push(
            'Binary not found or not executable.',
            'Ensure Craft core is built:',
            '  bun run build:core',
          )
        }
        else {
          errorMessage.push(
            'For troubleshooting, visit:',
            '  https://github.com/stacksjs/craft/issues',
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
            `❌ Craft process exited with code ${code}\n\n` +
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

    // Menubar-only mode doesn't need content
    if (!window?.menubarOnly) {
      // URL takes precedence over HTML
      if (url) {
        args.push('--url', url)
      }
      else if (html) {
        args.push('--html', html)
      }
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
      args.push('--dark')
    if (window?.hotReload)
      args.push('--hot-reload')
    if (window?.devTools === false)
      args.push('--no-devtools')
    if (window?.systemTray)
      args.push('--system-tray')
    if (window?.hideDockIcon)
      args.push('--hide-dock-icon')
    if (window?.menubarOnly)
      args.push('--menubar-only')
    if (window?.titlebarHidden)
      args.push('--titlebar-hidden')
    if (window?.nativeSidebar) {
      args.push('--native-sidebar')
      if (window?.sidebarWidth)
        args.push('--sidebar-width', String(window.sidebarWidth))
      if (window?.sidebarConfig)
        args.push('--sidebar-config', JSON.stringify(window.sidebarConfig))
    }

    return args
  }

  private async findCraftBinary(): Promise<string> {
    if (this.config.craftPath) {
      if (!existsSync(this.config.craftPath)) {
        throw new Error(
          `Custom Craft binary path not found: ${this.config.craftPath}\n\n` +
          'Please ensure the path is correct or build the Craft core:\n' +
          '  bun run build:core'
        )
      }
      return this.config.craftPath
    }

    // Try common locations
    const possiblePaths = [
      // From monorepo zig package
      join(process.cwd(), 'packages/zig/zig-out/bin/craft'),
      // From ts-craft package (when in monorepo)
      join(process.cwd(), '../zig/zig-out/bin/craft'),
      // Direct build output
      join(process.cwd(), 'zig-out/bin/craft'),
      join(process.cwd(), '../../zig-out/bin/craft'),
      // In PATH
      'craft',
    ]

    for (const path of possiblePaths) {
      if (path === 'craft') {
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
      '❌ Craft binary not found',
      '',
      'Tried the following locations:',
      ...possiblePaths.map(p => `  • ${p}`),
      '',
      'To fix this issue:',
      '',
      '1. Build the Craft core:',
      '   bun run build:core',
      '',
      '2. Or install Craft globally:',
      '   bun install -g ts-craft',
      '',
      '3. Or specify a custom binary path:',
      '   createApp({ craftPath: "/path/to/craft" })',
      '',
      'For more help, visit: https://github.com/stacksjs/craft',
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
 * Create a new Craft app instance
 */
export function createApp(config?: AppConfig): CraftApp {
  return new CraftApp(config)
}

/**
 * Quick helper to show a window with HTML
 */
export async function show(html: string, options?: WindowOptions): Promise<void> {
  const app = new CraftApp({ html, window: options })
  return app.show()
}

/**
 * Quick helper to load a URL
 */
export async function loadURL(url: string, options?: WindowOptions): Promise<void> {
  const app = new CraftApp({ url, window: options })
  return app.loadURL(url)
}

// Export types explicitly, excluding names already exported by './api'
// Excluded duplicates: SidebarItem, SidebarSection, SidebarConfig, SidebarSelectEvent,
// TrayClickEvent, MenuItem, AppInfo, NotificationOptions, DeviceInfo,
// PermissionStatus, ShareOptions, DisplayInfo
export type {
  WindowOptions,
  CraftSidebarAPI,
  AppConfig,
  CraftTrayAPI,
  CraftWindowAPI,
  CraftAppAPI,
  CraftBridgeAPI,
  Permission,
  HapticType,
  CameraOptions,
  PhotoPickerOptions,
  CraftMobileAPI,
  CraftFileSystemAPI,
  CraftDatabaseAPI,
  CraftHttpAPI,
  CraftCryptoAPI,
  CraftEventType,
  CraftEventMap,
  CraftEventHandler,
  CraftEventEmitter,
  IOSConfig,
  AndroidConfig,
  MacOSConfig,
  WindowsConfig,
  LinuxConfig,
  CraftAppConfig,
} from './types'