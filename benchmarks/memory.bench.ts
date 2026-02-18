#!/usr/bin/env bun

/**
 * Memory Benchmark
 *
 * Measures REAL process memory (RSS) for each framework's Hello World app.
 *
 * Methodology:
 *   1. Spawn the actual framework binary
 *   2. Wait for the window to render and stabilize (3 seconds)
 *   3. Read RSS (Resident Set Size) from the OS via `ps`
 *   4. Kill the process
 *   5. Repeat 3 times and report median
 *
 * This is an objective measurement — no synthetic simulations.
 */
import { join } from 'node:path'
import {
  checkFrameworks,
  findCraftBinary,
  findElectrobunApp,
  findRNMacOSBinary,
  findTauriBinary,
  formatBytes,
  getProcessRSS,
  header,
  reportTable,
} from './utils'

const APPS = join(import.meta.dir, 'apps')
const SAMPLES = 3
const STABILIZE_MS = 3000

header('Hello World Process Memory (RSS)')

const frameworks = checkFrameworks()
const available = frameworks.filter(f => f.available)
const missing = frameworks.filter(f => !f.available)

if (missing.length > 0) {
  console.log('  Skipping (not installed):')
  for (const f of missing) {
    console.log(`    ${f.name}: ${f.reason}`)
  }
  console.log()
}

if (available.length === 0) {
  console.log('  No frameworks available for process measurement.')
  console.log('  Install at least one framework to measure RSS.\n')
  process.exit(0)
}

console.log(`  Benchmarking: ${available.map(f => f.name).join(', ')}`)
console.log(`  Samples per framework: ${SAMPLES}`)
console.log(`  Stabilization wait: ${STABILIZE_MS}ms\n`)

// ---------------------------------------------------------------------------
// Measurement
// ---------------------------------------------------------------------------

interface MemoryResult {
  framework: string
  samples: number[] // RSS in KB
  median: number
}

async function measureRSS(
  cmd: string[],
  opts: { cwd?: string } = {},
): Promise<number> {
  const proc = Bun.spawn({
    cmd,
    cwd: opts.cwd,
    env: { ...process.env },
    stdout: 'pipe',
    stderr: 'pipe',
  })

  // Wait for window to render and stabilize
  await new Promise(r => setTimeout(r, STABILIZE_MS))

  let rss = 0
  try {
    rss = await getProcessRSS(proc.pid)
  } catch {
    // Process may have already exited
  }

  proc.kill()
  await proc.exited

  return rss
}

function median(arr: number[]): number {
  const sorted = [...arr].sort((a, b) => a - b)
  const mid = Math.floor(sorted.length / 2)
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
}

const results: MemoryResult[] = []

// --- Craft ---
const craftBin = findCraftBinary()
if (craftBin && craftBin !== 'craft') {
  const html = '<html><body><h1>Hello World</h1></body></html>'
  const samples: number[] = []
  for (let i = 0; i < SAMPLES; i++) {
    const rss = await measureRSS([craftBin, '--html', html, '--title', 'Bench', '--width', '400', '--height', '300'])
    if (rss > 0) samples.push(rss)
    process.stdout.write(`  Craft sample ${i + 1}/${SAMPLES}: ${formatBytes(rss * 1024)}\n`)
  }
  if (samples.length > 0) {
    results.push({ framework: 'Craft', samples, median: median(samples) })
  }
}

// --- Electron ---
if (frameworks.find(f => f.name === 'Electron')?.available) {
  const electronBin = join(APPS, 'electron/node_modules/.bin/electron')
  const samples: number[] = []
  for (let i = 0; i < SAMPLES; i++) {
    // Do NOT set BENCHMARK=1 — we want the window to stay open so we can measure RSS
    const rss = await measureRSS([electronBin, '.'], { cwd: join(APPS, 'electron') })
    if (rss > 0) samples.push(rss)
    process.stdout.write(`  Electron sample ${i + 1}/${SAMPLES}: ${formatBytes(rss * 1024)}\n`)
  }
  if (samples.length > 0) {
    results.push({ framework: 'Electron', samples, median: median(samples) })
  }
}

// --- Tauri ---
const tauriBin = findTauriBinary()
if (tauriBin) {
  const samples: number[] = []
  for (let i = 0; i < SAMPLES; i++) {
    // Do NOT set BENCHMARK=1 — we want the window to stay open so we can measure RSS
    const rss = await measureRSS([tauriBin])
    if (rss > 0) samples.push(rss)
    process.stdout.write(`  Tauri sample ${i + 1}/${SAMPLES}: ${formatBytes(rss * 1024)}\n`)
  }
  if (samples.length > 0) {
    results.push({ framework: 'Tauri', samples, median: median(samples) })
  }
}

// --- Electrobun ---
const electrobunBin = findElectrobunApp()
if (electrobunBin) {
  const samples: number[] = []
  for (let i = 0; i < SAMPLES; i++) {
    const rss = await measureRSS([electrobunBin])
    if (rss > 0) samples.push(rss)
    process.stdout.write(`  Electrobun sample ${i + 1}/${SAMPLES}: ${formatBytes(rss * 1024)}\n`)
  }
  if (samples.length > 0) {
    results.push({ framework: 'Electrobun', samples, median: median(samples) })
  }
}

// --- React Native macOS ---
const rnBin = findRNMacOSBinary()
if (rnBin) {
  const samples: number[] = []
  for (let i = 0; i < SAMPLES; i++) {
    const rss = await measureRSS([rnBin])
    if (rss > 0) samples.push(rss)
    process.stdout.write(`  React Native sample ${i + 1}/${SAMPLES}: ${formatBytes(rss * 1024)}\n`)
  }
  if (samples.length > 0) {
    results.push({ framework: 'React Native', samples, median: median(samples) })
  }
}

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------
console.log()

if (results.length === 0) {
  console.log('  No results collected.\n')
  process.exit(0)
}

console.log('Median RSS (Resident Set Size):')
reportTable(
  results.map(r => ({
    label: r.framework,
    value: formatBytes(r.median * 1024),
    note: `median of ${r.samples.length} samples`,
  })),
)

if (results.length >= 2) {
  console.log()
  console.log('Comparison:')
  const smallest = results.reduce((a, b) => (a.median < b.median ? a : b))
  for (const r of results) {
    if (r === smallest) continue
    const ratio = (r.median / smallest.median).toFixed(1)
    console.log(`  ${smallest.framework} uses ${ratio}x less memory than ${r.framework}`)
  }
}

console.log()
