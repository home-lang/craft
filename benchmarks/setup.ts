#!/usr/bin/env bun

/**
 * Benchmark Setup
 *
 * Installs dependencies for each framework's Hello World app.
 * Run this before running benchmarks.
 *
 * Usage: bun run setup
 */
import { existsSync } from 'node:fs'
import { join } from 'node:path'

const APPS = join(import.meta.dir, 'apps')

console.log('Setting up benchmark apps...\n')

// ---------------------------------------------------------------------------
// Electron
// ---------------------------------------------------------------------------
console.log('1. Electron')
const electronDir = join(APPS, 'electron')
if (existsSync(join(electronDir, 'node_modules/electron'))) {
  console.log('   Already installed.\n')
} else {
  console.log('   Installing electron...')
  const result = Bun.spawnSync({
    cmd: ['bun', 'install'],
    cwd: electronDir,
    stdout: 'inherit',
    stderr: 'inherit',
  })
  if (result.exitCode === 0) {
    console.log('   Done.\n')
  } else {
    console.log('   Failed to install. You may need to run manually:\n')
    console.log(`   cd ${electronDir} && bun install\n`)
  }
}

// ---------------------------------------------------------------------------
// Craft
// ---------------------------------------------------------------------------
console.log('2. Craft')
const craftBinaryPaths = [
  join(import.meta.dir, '..', 'packages/zig/zig-out/bin/craft'),
  join(import.meta.dir, '..', 'zig-out/bin/craft'),
]
const craftFound = craftBinaryPaths.some(p => existsSync(p))
if (craftFound) {
  console.log('   Binary found.\n')
} else {
  console.log('   Binary not found. Build with:')
  console.log('   cd packages/zig && zig build\n')
}

// ---------------------------------------------------------------------------
// Tauri
// ---------------------------------------------------------------------------
console.log('3. Tauri')
const tauriBinaryPaths = [
  join(APPS, 'tauri/src-tauri/target/release/tauri-hello-world'),
  join(APPS, 'tauri/src-tauri/target/debug/tauri-hello-world'),
]
const tauriFound = tauriBinaryPaths.some(p => existsSync(p))
if (tauriFound) {
  console.log('   Binary found.\n')
} else {
  console.log('   Binary not found. Build with:')
  console.log('   cd benchmarks/apps/tauri/src-tauri && cargo build --release')
  console.log('   (Requires Rust toolchain)\n')
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
console.log('Setup complete.')
console.log('Run benchmarks with: bun run bench\n')
