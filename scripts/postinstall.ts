#!/usr/bin/env bun

import { spawnSync } from 'bun'
import { platform, arch } from 'node:os'
import { existsSync } from 'node:fs'
import { join } from 'node:path'

console.log('Building Zyte for your platform...')

// Check if zig is installed
const zigCheck = spawnSync('zig', ['version'], { stdio: 'pipe' })

if (zigCheck.exitCode !== 0) {
  console.error('Error: Zig is not installed.')
  console.error('Please install Zig 0.15.1 from: https://ziglang.org/download/')
  console.error('')
  console.error('Alternatively, you can download pre-built binaries from:')
  console.error('https://github.com/stacksjs/zyte/releases')
  process.exit(1)
}

console.log(`Zig version: ${zigCheck.stdout.toString().trim()}`)

// Build the project
const buildResult = spawnSync('zig', ['build', '-Doptimize=ReleaseSafe'], {
  stdio: 'inherit',
})

if (buildResult.exitCode !== 0) {
  console.error('Build failed!')
  process.exit(1)
}

// Copy binary to bin directory
const platformMap = {
  darwin: 'darwin',
  linux: 'linux',
  win32: 'windows',
}

const archMap = {
  x64: 'x64',
  arm64: 'arm64',
}

const currentPlatform = platformMap[platform()]
const currentArch = archMap[arch()]

if (!currentPlatform || !currentArch) {
  console.error(`Unsupported platform: ${platform()}-${arch()}`)
  process.exit(1)
}

const sourceBinary = platform() === 'win32'
  ? 'zig-out/bin/zyte-minimal.exe'
  : 'zig-out/bin/zyte-minimal'

const targetBinary = platform() === 'win32'
  ? `bin/zyte-${currentPlatform}-${currentArch}.exe`
  : `bin/zyte-${currentPlatform}-${currentArch}`

if (existsSync(sourceBinary)) {
  const { copyFileSync, chmodSync } = await import('fs')
  copyFileSync(sourceBinary, targetBinary)
  if (platform() !== 'win32') {
    chmodSync(targetBinary, 0o755)
  }
  console.log(`✓ Binary installed: ${targetBinary}`)
} else {
  console.error(`Error: Built binary not found at ${sourceBinary}`)
  process.exit(1)
}

console.log('✓ Zyte installed successfully!')
