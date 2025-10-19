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

cli.version(version)
cli.help()
cli.parse()
