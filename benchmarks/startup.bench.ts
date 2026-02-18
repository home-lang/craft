#!/usr/bin/env bun

/**
 * Startup Time Benchmark
 *
 * Measures real cold-start time for Hello World apps across frameworks.
 *
 * Methodology:
 *   Each app is launched in benchmark mode and auto-quits after initialization.
 *   We measure wall-clock time from spawn to exit.
 *
 *   - Craft:    --benchmark flag: creates window, prints "ready", exits immediately
 *   - Electron: BENCHMARK=1 env: quits after `did-finish-load` (HTML fully parsed)
 *   - Tauri:    BENCHMARK=1 env: quits ~50ms after setup() (window created)
 *
 * Requirements:
 *   Craft:    Build the Zig binary (cd packages/zig && zig build)
 *   Electron: Install deps (cd benchmarks/apps/electron && bun install)
 *   Tauri:    Build binary (cd benchmarks/apps/tauri/src-tauri && cargo build --release)
 */
import { join } from 'node:path'
import {
  checkFrameworks,
  findCraftBinary,
  findTauriBinary,
  header,
} from './utils'

const APPS = join(import.meta.dir, 'apps')
const ITERATIONS = 10

header('Hello World Startup Time')

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
  console.log('  No frameworks available. Install at least one to benchmark.\n')
  process.exit(0)
}

console.log(`  Benchmarking: ${available.map(f => f.name).join(', ')}`)
console.log(`  Iterations: ${ITERATIONS}\n`)

// ---------------------------------------------------------------------------
// Measurement helpers
// ---------------------------------------------------------------------------

interface TimingResult {
  framework: string
  times: number[]
  note?: string
}

/**
 * Measure startup by spawning a process that auto-quits.
 * Measures wall-clock time from Bun.spawn() to process exit.
 */
async function measureAutoQuit(
  framework: string,
  cmd: string[],
  opts: { cwd?: string; env?: Record<string, string> } = {},
): Promise<TimingResult> {
  const times: number[] = []

  for (let i = 0; i < ITERATIONS; i++) {
    const start = performance.now()

    const proc = Bun.spawn({
      cmd,
      cwd: opts.cwd,
      env: { ...process.env, ...opts.env },
      stdout: 'pipe',
      stderr: 'pipe',
    })

    // Safety timeout in case the app doesn't quit
    const timeout = setTimeout(() => proc.kill(), 15_000)
    await proc.exited
    clearTimeout(timeout)

    times.push(performance.now() - start)
  }

  return { framework, times }
}

/**
 * Measure startup for a process that doesn't auto-quit.
 * Spawns the process, waits for window to render, then kills.
 * The kill delay adds fixed overhead to the measurement.
 */
async function measureWithKill(
  framework: string,
  cmd: string[],
  killDelayMs: number,
  opts: { cwd?: string } = {},
): Promise<TimingResult> {
  const times: number[] = []

  for (let i = 0; i < ITERATIONS; i++) {
    const start = performance.now()

    const proc = Bun.spawn({
      cmd,
      cwd: opts.cwd,
      env: { ...process.env },
      stdout: 'pipe',
      stderr: 'pipe',
    })

    await new Promise(r => setTimeout(r, killDelayMs))
    proc.kill()
    await proc.exited

    times.push(performance.now() - start)
  }

  return {
    framework,
    times,
    note: `includes ~${killDelayMs}ms kill delay (no auto-quit support)`,
  }
}

function stats(times: number[]) {
  const sorted = [...times].sort((a, b) => a - b)
  const avg = times.reduce((a, b) => a + b, 0) / times.length
  return {
    avg,
    min: sorted[0],
    max: sorted[sorted.length - 1],
    p50: sorted[Math.floor(sorted.length * 0.5)],
    p95: sorted[Math.floor(sorted.length * 0.95)],
  }
}

function fmtMs(ms: number): string {
  return `${ms.toFixed(2)} ms`
}

// ---------------------------------------------------------------------------
// Run measurements
// ---------------------------------------------------------------------------
const results: TimingResult[] = []

// --- Craft ---
const craftBin = findCraftBinary()
if (craftBin) {
  const html = '<html><body><h1>Hello World</h1></body></html>'
  console.log('  Measuring Craft...')
  const r = await measureAutoQuit(
    'Craft',
    [craftBin, '--html', html, '--title', 'Bench', '--width', '400', '--height', '300', '--benchmark'],
  )
  results.push(r)
}

// --- Electron ---
const electronInfo = frameworks.find(f => f.name === 'Electron')
if (electronInfo?.available) {
  console.log('  Measuring Electron...')
  const electronBin = join(APPS, 'electron/node_modules/.bin/electron')
  const r = await measureAutoQuit('Electron', [electronBin, '.'], {
    cwd: join(APPS, 'electron'),
    env: { BENCHMARK: '1' },
  })
  results.push(r)
}

// --- Tauri ---
const tauriBin = findTauriBinary()
if (tauriBin) {
  console.log('  Measuring Tauri...')
  const r = await measureAutoQuit('Tauri', [tauriBin], {
    env: { BENCHMARK: '1' },
  })
  results.push(r)
}

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------
console.log()

if (results.length === 0) {
  console.log('  No results collected.\n')
  process.exit(0)
}

const maxName = Math.max(...results.map(r => r.framework.length))

console.log(`${'Framework'.padEnd(maxName)}    avg          p50          p95          min          max`)
console.log('-'.repeat(maxName + 65))

for (const r of results) {
  const s = stats(r.times)
  console.log(
    `${r.framework.padEnd(maxName)}    ${fmtMs(s.avg).padStart(10)}   ${fmtMs(s.p50).padStart(10)}   ${fmtMs(s.p95).padStart(10)}   ${fmtMs(s.min).padStart(10)}   ${fmtMs(s.max).padStart(10)}`,
  )
  if (r.note) {
    console.log(`${''.padEnd(maxName)}    * ${r.note}`)
  }
}

// Comparison
if (results.length >= 2) {
  console.log()
  console.log('Comparison:')
  const fastest = results.reduce((a, b) =>
    stats(a.times).p50 < stats(b.times).p50 ? a : b,
  )
  for (const r of results) {
    if (r === fastest) continue
    const ratio = (stats(r.times).p50 / stats(fastest.times).p50).toFixed(1)
    console.log(`  ${fastest.framework} is ${ratio}x faster than ${r.framework} (p50)`)
  }
}

console.log()
