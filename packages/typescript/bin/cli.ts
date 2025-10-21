#!/usr/bin/env bun

/**
 * Zyte CLI - Build desktop apps with web languages
 */

import { CLI } from '@stacksjs/clapp'
import { spawn } from 'node:child_process'
import { existsSync } from 'node:fs'
import { join } from 'node:path'
import process from 'node:process'
import { version } from '../package.json'

const cli = new CLI('zyte')

// Helper to find and run the Zyte binary
async function runZyteBinary(args: string[]): Promise<void> {
  const zytePath = await findZyteBinary()

  return new Promise((resolve, reject) => {
    const proc = spawn(zytePath, args, {
      stdio: 'inherit',
    })

    proc.on('exit', (code) => {
      if (code === 0 || code === null) {
        resolve()
      }
      else {
        reject(new Error(`Zyte exited with code ${code}`))
      }
    })

    proc.on('error', (error) => {
      reject(error)
    })
  })
}

async function findZyteBinary(): Promise<string> {
  const possiblePaths = [
    // From monorepo zig package
    join(process.cwd(), 'packages/zig/zig-out/bin/zyte'),
    // From typescript package (when in monorepo)
    join(process.cwd(), '../zig/zig-out/bin/zyte'),
    join(import.meta.dir, '../../zig/zig-out/bin/zyte'),
    // Legacy locations
    join(process.cwd(), 'zig-out/bin/zyte'),
    join(process.cwd(), '../../zig-out/bin/zyte'),
    join(import.meta.dir, '../../../zig-out/bin/zyte'),
    // Global install
    'zyte',
  ]

  for (const path of possiblePaths) {
    if (path === 'zyte') {
      // Check if it's in PATH
      try {
        await checkBinaryExists(path)
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

  throw new Error(
    'Zyte binary not found. Please build the project first with: bun run build:core',
  )
}

function checkBinaryExists(path: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const proc = spawn(path, ['--version'], { stdio: 'ignore' })
    proc.on('error', reject)
    proc.on('exit', (code) => {
      if (code === 0 || code === null) {
        resolve()
      }
      else {
        reject(new Error(`Binary check failed`))
      }
    })
  })
}

// Default command - launch app with URL
cli
  .command('[url]', 'Launch a Zyte desktop app')
  .option('--title <title>', 'Window title')
  .option('--width <width>', 'Window width', { default: 800 })
  .option('--height <height>', 'Window height', { default: 600 })
  .option('--x <x>', 'Window x position')
  .option('--y <y>', 'Window y position')
  .option('--frameless', 'Frameless window')
  .option('--transparent', 'Transparent window')
  .option('--always-on-top', 'Always on top')
  .option('--fullscreen', 'Start in fullscreen')
  .option('--dark-mode', 'Enable dark mode')
  .option('--hot-reload', 'Enable hot reload')
  .option('--dev-tools', 'Enable developer tools')
  .option('--no-resize', 'Disable window resizing')
  .example('zyte http://localhost:3000')
  .example('zyte http://localhost:3000 --title "My App" --width 1200 --height 800')
  .example('zyte http://localhost:3000 --frameless --transparent --always-on-top')
  .action(async (url?: string, options?: any) => {
    const args: string[] = []

    if (url) {
      args.push('--url', url)
    }

    if (options?.title)
      args.push('--title', options.title)
    if (options?.width)
      args.push('--width', String(options.width))
    if (options?.height)
      args.push('--height', String(options.height))
    if (options?.x)
      args.push('--x', String(options.x))
    if (options?.y)
      args.push('--y', String(options.y))
    if (options?.frameless)
      args.push('--frameless')
    if (options?.transparent)
      args.push('--transparent')
    if (options?.alwaysOnTop)
      args.push('--always-on-top')
    if (options?.fullscreen)
      args.push('--fullscreen')
    if (options?.darkMode)
      args.push('--dark-mode')
    if (options?.hotReload)
      args.push('--hot-reload')
    if (options?.devTools)
      args.push('--dev-tools')
    if (options?.noResize)
      args.push('--no-resize')

    try {
      await runZyteBinary(args)
    }
    catch (error: any) {
      console.error('Error:', error.message)
      process.exit(1)
    }
  })

// Version command
cli
  .command('version', 'Show the version')
  .action(() => {
    console.log(`v${version}`)
  })

// Build command
cli
  .command('build', 'Build the Zyte core binary')
  .option('--release', 'Build in release mode', { default: false })
  .action(async (options?: any) => {
    const buildCmd = options?.release
      ? 'bun run build:core'
      : 'cd packages/zig && zig build'

    console.log('Building Zyte core...')
    try {
      await runZyteBinary([buildCmd])
      console.log('✓ Build complete')
    }
    catch (error: any) {
      console.error('Build failed:', error.message)
      process.exit(1)
    }
  })

// Dev command - launch with hot reload and dev tools enabled
cli
  .command('dev [url]', 'Launch in development mode with hot reload')
  .option('--title <title>', 'Window title', { default: 'Zyte Dev' })
  .option('--width <width>', 'Window width', { default: 1200 })
  .option('--height <height>', 'Window height', { default: 800 })
  .example('zyte dev http://localhost:3000')
  .action(async (url?: string, options?: any) => {
    const args = [
      '--url',
      url || 'http://localhost:3000',
      '--title',
      options?.title || 'Zyte Dev',
      '--width',
      String(options?.width || 1200),
      '--height',
      String(options?.height || 800),
      '--hot-reload',
      '--dev-tools',
      '--dark-mode',
    ]

    try {
      await runZyteBinary(args)
    }
    catch (error: any) {
      console.error('Error:', error.message)
      process.exit(1)
    }
  })

// Package command - create installers
cli
  .command('package', 'Create installers for your Zyte application')
  .option('--name <name>', 'Application name')
  .option('--version <version>', 'Application version')
  .option('--binary <path>', 'Path to application binary')
  .option('--description <text>', 'Application description')
  .option('--author <name>', 'Author/Maintainer name')
  .option('--bundle-id <id>', 'Bundle identifier (macOS/iOS)')
  .option('--out <dir>', 'Output directory (default: ./dist)')
  .option('--icon <path>', 'Application icon path')
  .option('--platforms <list>', 'Comma-separated platforms (macos,windows,linux)')
  .option('--config <path>', 'Load config from JSON file')
  .option('--dmg', 'Create DMG installer (macOS)')
  .option('--pkg', 'Create PKG installer (macOS)')
  .option('--msi', 'Create MSI installer (Windows)')
  .option('--zip', 'Create ZIP archive (Windows)')
  .option('--deb', 'Create DEB package (Linux)')
  .option('--rpm', 'Create RPM package (Linux)')
  .option('--appimage', 'Create AppImage (Linux)')
  .example('zyte package --name "My App" --version "1.0.0" --binary ./build/myapp')
  .example('zyte package --config package.json')
  .example('zyte package --name "My App" --version "1.0.0" --binary ./build/myapp --platforms macos,windows,linux')
  .action(async (options?: any) => {
    const packageModule = await import('../src/package.js')
    const { packageApp } = packageModule

    let config: any

    // Load config from file or CLI args
    if (options?.config) {
      if (!existsSync(options.config)) {
        console.error(`❌ Config file not found: ${options.config}`)
        process.exit(1)
      }

      const configContent = await Bun.file(options.config).text()
      config = JSON.parse(configContent)
    }
    else {
      // Build config from CLI options
      if (!options?.name) {
        console.error('❌ --name is required')
        process.exit(1)
      }
      if (!options?.version) {
        console.error('❌ --version is required')
        process.exit(1)
      }
      if (!options?.binary) {
        console.error('❌ --binary is required')
        process.exit(1)
      }

      config = {
        name: options.name,
        version: options.version,
        binaryPath: options.binary,
        description: options.description,
        author: options.author,
        bundleId: options.bundleId,
        outDir: options.out,
        iconPath: options.icon,
        platforms: options.platforms?.split(','),
      }

      // Platform-specific options
      if (options.dmg || options.pkg) {
        config.macos = {
          dmg: options.dmg,
          pkg: options.pkg,
        }
      }

      if (options.msi || options.zip) {
        config.windows = {
          msi: options.msi,
          zip: options.zip,
        }
      }

      if (options.deb || options.rpm || options.appimage) {
        config.linux = {
          deb: options.deb,
          rpm: options.rpm,
          appImage: options.appimage,
        }
      }
    }

    console.log('📦 Zyte Packaging Tool\n')
    console.log(`Application: ${config.name} v${config.version}`)
    console.log(`Platforms: ${(config.platforms || ['current']).join(', ')}\n`)

    try {
      const results = await packageApp(config)

      console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
      console.log('📊 Packaging Results\n')

      for (const result of results) {
        const status = result.success ? '✅' : '❌'
        const format = result.format.toUpperCase()

        console.log(`${status} ${result.platform}/${format}`)

        if (result.success && result.outputPath) {
          console.log(`   📁 ${result.outputPath}`)
        }
        else if (result.error) {
          console.log(`   ⚠️  ${result.error}`)
        }
      }

      const successCount = results.filter(r => r.success).length
      const totalCount = results.length

      console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
      console.log(`\n✨ Complete: ${successCount}/${totalCount} packages created\n`)

      process.exit(successCount === totalCount ? 0 : 1)
    }
    catch (error: any) {
      console.error(`\n❌ Error: ${error.message}\n`)
      process.exit(1)
    }
  })

cli.version(version)
cli.help()
cli.parse()
