#!/usr/bin/env bun

/**
 * Zyte CLI - TypeScript wrapper for Zyte binary
 */

import { spawn } from 'node:child_process'
import { existsSync } from 'node:fs'
import { join } from 'node:path'

async function main() {
  const args = process.argv.slice(2)

  // Find the Zyte binary
  const zytePath = await findZyteBinary()

  // Pass all arguments to the Zyte binary
  const proc = spawn(zytePath, args, {
    stdio: 'inherit',
  })

  proc.on('exit', (code) => {
    process.exit(code || 0)
  })

  proc.on('error', (error) => {
    console.error('Error running Zyte:', error.message)
    process.exit(1)
  })
}

async function findZyteBinary(): Promise<string> {
  const possiblePaths = [
    // From monorepo zig package
    join(process.cwd(), 'packages/zig/zig-out/bin/zyte'),
    // From ts-zyte package (when in monorepo)
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

main()
