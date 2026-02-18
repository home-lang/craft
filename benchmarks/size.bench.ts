#!/usr/bin/env bun

/**
 * Bundle Size Benchmark
 *
 * Measures actual binary/bundle sizes on disk for each framework's
 * Hello World app. Reports the minimal distributable size.
 *
 * This is NOT a mitata benchmark (sizes are static measurements).
 * It reports a formatted comparison table.
 */
import { existsSync, statSync } from 'node:fs'
import { join } from 'node:path'
import {
  dirSize,
  fileSize,
  findCraftBinary,
  findElectrobunApp,
  findElectrobunAppBundle,
  findRNMacOSAppBundle,
  findRNMacOSBinary,
  findTauriBinary,
  formatBytes,
  header,
  reportTable,
} from './utils'

const APPS = join(import.meta.dir, 'apps')

header('Hello World Bundle Size')

interface SizeEntry {
  framework: string
  binarySize: number
  bundleSize: number
  details: string
}

const entries: SizeEntry[] = []

// ---------------------------------------------------------------------------
// Craft
// ---------------------------------------------------------------------------
const craftBin = findCraftBinary()
if (craftBin && craftBin !== 'craft') {
  const binSize = fileSize(craftBin)
  entries.push({
    framework: 'Craft',
    binarySize: binSize,
    bundleSize: binSize, // Craft is a single static binary
    details: 'Single native binary (Zig)',
  })
} else if (craftBin === 'craft') {
  // In PATH — try to find the actual binary
  const which = Bun.spawnSync({ cmd: ['which', 'craft'], stdout: 'pipe' })
  const path = new TextDecoder().decode(which.stdout).trim()
  if (path && existsSync(path)) {
    const binSize = fileSize(path)
    entries.push({
      framework: 'Craft',
      binarySize: binSize,
      bundleSize: binSize,
      details: `Single native binary at ${path}`,
    })
  }
} else {
  console.log('  Craft: binary not found (build with: cd packages/zig && zig build)\n')
}

// ---------------------------------------------------------------------------
// Electron
// ---------------------------------------------------------------------------
const electronModules = join(APPS, 'electron/node_modules')
if (existsSync(electronModules)) {
  const electronPkg = join(electronModules, 'electron')
  const electronBin = join(electronModules, '.bin/electron')

  // Electron's real size = electron package + app code
  const electronPkgSize = dirSize(electronPkg)
  const appCodeSize = fileSize(join(APPS, 'electron/main.js')) +
    fileSize(join(APPS, 'hello.html'))

  entries.push({
    framework: 'Electron',
    binarySize: electronPkgSize,
    bundleSize: electronPkgSize + appCodeSize,
    details: 'Chromium + Node.js runtime + app',
  })
} else {
  console.log('  Electron: not installed (run: cd benchmarks/apps/electron && bun install)\n')
}

// ---------------------------------------------------------------------------
// Tauri
// ---------------------------------------------------------------------------
const tauriBin = findTauriBinary()
if (tauriBin) {
  const binSize = fileSize(tauriBin)
  const frontendSize = dirSize(join(APPS, 'tauri/src'))
  entries.push({
    framework: 'Tauri',
    binarySize: binSize,
    bundleSize: binSize + frontendSize,
    details: 'Rust binary + frontend assets',
  })
} else {
  console.log('  Tauri: binary not found (build with: cd benchmarks/apps/tauri/src-tauri && cargo build --release)\n')
}

// ---------------------------------------------------------------------------
// Electrobun
// ---------------------------------------------------------------------------
const electrobunBin = findElectrobunApp()
const electrobunBundle = findElectrobunAppBundle()
if (electrobunBin && electrobunBundle) {
  const bundleSize = dirSize(electrobunBundle)
  entries.push({
    framework: 'Electrobun',
    binarySize: fileSize(electrobunBin),
    bundleSize,
    details: 'Bun + native WebView .app bundle',
  })
} else {
  console.log('  Electrobun: app not found (build with: cd benchmarks/apps/electrobun && bun install && npx electrobun build)\n')
}

// ---------------------------------------------------------------------------
// React Native macOS
// ---------------------------------------------------------------------------
const rnBin = findRNMacOSBinary()
const rnBundle = findRNMacOSAppBundle()
if (rnBin && rnBundle) {
  const bundleSize = dirSize(rnBundle)
  entries.push({
    framework: 'React Native',
    binarySize: fileSize(rnBin),
    bundleSize,
    details: 'React Native macOS .app bundle',
  })
} else {
  console.log('  React Native macOS: app not found (build with xcodebuild)\n')
}

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------
if (entries.length > 0) {
  console.log('Binary Size (standalone executable):')
  reportTable(
    entries.map(e => ({
      label: e.framework,
      value: formatBytes(e.binarySize),
      note: e.details,
    })),
  )

  console.log()
  console.log('Total Bundle Size (distributable):')
  reportTable(
    entries.map(e => ({
      label: e.framework,
      value: formatBytes(e.bundleSize),
    })),
  )

  // Comparison ratios
  if (entries.length >= 2) {
    console.log()
    console.log('Comparison:')
    const smallest = entries.reduce((a, b) => (a.bundleSize < b.bundleSize ? a : b))
    for (const entry of entries) {
      if (entry === smallest) continue
      const ratio = (entry.bundleSize / smallest.bundleSize).toFixed(1)
      console.log(`  ${smallest.framework} is ${ratio}x smaller than ${entry.framework}`)
    }
  }
}

console.log()
