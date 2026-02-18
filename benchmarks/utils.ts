/**
 * Benchmark utilities for measuring real framework performance.
 */
import { existsSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'

const ROOT = join(import.meta.dir, '..')
const APPS = join(import.meta.dir, 'apps')

// ---------------------------------------------------------------------------
// Framework binary/availability detection
// ---------------------------------------------------------------------------

export interface FrameworkInfo {
  name: string
  available: boolean
  binary?: string
  appBundle?: string
  reason?: string
}

/** Locate the Craft native binary. */
export function findCraftBinary(): string | null {
  const candidates = [
    join(ROOT, 'packages/zig/zig-out/bin/craft'),
    join(ROOT, 'zig-out/bin/craft'),
    'craft', // in PATH
  ]
  for (const p of candidates) {
    if (p === 'craft') {
      try {
        Bun.spawnSync({ cmd: ['which', 'craft'], stdout: 'pipe' })
        return 'craft'
      } catch {
        continue
      }
    } else if (existsSync(p)) {
      return p
    }
  }
  return null
}

/** Check if Electron is installed in the apps/electron directory. */
export function electronAvailable(): boolean {
  return existsSync(join(APPS, 'electron/node_modules/electron'))
}

/** Check if Tauri binary is built. */
export function findTauriBinary(): string | null {
  const candidates = [
    join(APPS, 'tauri/src-tauri/target/release/tauri-hello-world'),
    join(APPS, 'tauri/src-tauri/target/debug/tauri-hello-world'),
  ]
  for (const p of candidates) {
    if (existsSync(p)) return p
  }
  return null
}

/** Check if Electrobun app is built. */
export function findElectrobunApp(): string | null {
  const appPath = join(APPS, 'electrobun/build/dev-macos-arm64')
  // Find the .app directory inside
  if (existsSync(appPath)) {
    try {
      const entries = readdirSync(appPath)
      const app = entries.find(e => e.endsWith('.app'))
      if (app) return join(appPath, app, 'Contents/MacOS/launcher')
    } catch {}
  }
  return null
}

/** Check if React Native macOS app is built. */
export function findRNMacOSBinary(): string | null {
  const candidates = [
    join(APPS, 'react-native-macos/build/Build/Products/Release/RNMacBench.app/Contents/MacOS/RNMacBench'),
    join(APPS, 'react-native-macos/build/Build/Products/Debug/RNMacBench.app/Contents/MacOS/RNMacBench'),
  ]
  for (const p of candidates) {
    if (existsSync(p)) return p
  }
  return null
}

/** Find the React Native macOS .app bundle for size measurement. */
export function findRNMacOSAppBundle(): string | null {
  const candidates = [
    join(APPS, 'react-native-macos/build/Build/Products/Release/RNMacBench.app'),
    join(APPS, 'react-native-macos/build/Build/Products/Debug/RNMacBench.app'),
  ]
  for (const p of candidates) {
    if (existsSync(p)) return p
  }
  return null
}

/** Find the Electrobun .app bundle for size measurement. */
export function findElectrobunAppBundle(): string | null {
  const appPath = join(APPS, 'electrobun/build/dev-macos-arm64')
  if (existsSync(appPath)) {
    try {
      const entries = readdirSync(appPath)
      const app = entries.find(e => e.endsWith('.app'))
      if (app) return join(appPath, app)
    } catch {}
  }
  return null
}

/** Get availability status of all frameworks. */
export function checkFrameworks(): FrameworkInfo[] {
  const craft = findCraftBinary()
  const electron = electronAvailable()
  const tauri = findTauriBinary()
  const electrobun = findElectrobunApp()
  const rnMacOS = findRNMacOSBinary()

  return [
    {
      name: 'Craft',
      available: craft !== null,
      binary: craft ?? undefined,
      reason: craft ? undefined : 'Build with: cd packages/zig && zig build -Doptimize=ReleaseSmall',
    },
    {
      name: 'Electron',
      available: electron,
      binary: electron ? join(APPS, 'electron/node_modules/.bin/electron') : undefined,
      reason: electron ? undefined : 'Install with: cd benchmarks/apps/electron && bun install',
    },
    {
      name: 'Tauri',
      available: tauri !== null,
      binary: tauri ?? undefined,
      reason: tauri ? undefined : 'Build with: cd benchmarks/apps/tauri/src-tauri && cargo build --release',
    },
    {
      name: 'Electrobun',
      available: electrobun !== null,
      binary: electrobun ?? undefined,
      reason: electrobun ? undefined : 'Build with: cd benchmarks/apps/electrobun && bun install && npx electrobun build',
    },
    {
      name: 'React Native',
      available: rnMacOS !== null,
      binary: rnMacOS ?? undefined,
      reason: rnMacOS ? undefined : 'Build with: cd benchmarks/apps/react-native-macos && bun install && pod install --project-directory=macos && xcodebuild ...',
    },
  ]
}

// ---------------------------------------------------------------------------
// Process measurement
// ---------------------------------------------------------------------------

export interface StartupResult {
  framework: string
  timeMs: number
  exitCode: number | null
}

/**
 * Spawn a process and measure time until it exits.
 * The process is expected to auto-quit in benchmark mode.
 * Falls back to killing after timeoutMs.
 */
export async function measureProcess(
  cmd: string[],
  opts: {
    cwd?: string
    env?: Record<string, string>
    timeoutMs?: number
  } = {},
): Promise<{ timeMs: number; exitCode: number | null; stdout: string }> {
  const timeoutMs = opts.timeoutMs ?? 10_000
  const start = performance.now()

  const proc = Bun.spawn({
    cmd,
    cwd: opts.cwd,
    env: { ...process.env, ...opts.env },
    stdout: 'pipe',
    stderr: 'pipe',
  })

  const timeout = setTimeout(() => proc.kill(), timeoutMs)

  const exitCode = await proc.exited
  clearTimeout(timeout)

  const timeMs = performance.now() - start
  const stdout = await new Response(proc.stdout).text()

  return { timeMs, exitCode, stdout }
}

// ---------------------------------------------------------------------------
// Size measurement
// ---------------------------------------------------------------------------

/** Recursively calculate directory size in bytes. */
export function dirSize(dirPath: string): number {
  if (!existsSync(dirPath)) return 0
  let total = 0
  const entries = readdirSync(dirPath, { withFileTypes: true })
  for (const entry of entries) {
    const fullPath = join(dirPath, entry.name)
    if (entry.isDirectory()) {
      total += dirSize(fullPath)
    } else {
      total += statSync(fullPath).size
    }
  }
  return total
}

/** Get file size in bytes (0 if not found). */
export function fileSize(filePath: string): number {
  if (!existsSync(filePath)) return 0
  return statSync(filePath).size
}

/** Format bytes as human-readable string. */
export function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(1024))
  return `${(bytes / 1024 ** i).toFixed(2)} ${units[i]}`
}

// ---------------------------------------------------------------------------
// Memory measurement (macOS/Linux)
// ---------------------------------------------------------------------------

/**
 * Get total RSS (Resident Set Size) of a process tree in KB.
 *
 * Sums RSS of the process AND all its descendants. This is important
 * because frameworks like Electron spawn multiple child processes
 * (main, renderer, GPU) and WebView-based apps (Craft, Tauri) may
 * also have helper processes.
 */
export async function getProcessRSS(pid: number): Promise<number> {
  // Get RSS of the main process
  const mainResult = Bun.spawnSync({
    cmd: ['ps', '-o', 'rss=', '-p', String(pid)],
    stdout: 'pipe',
  })
  const mainRSS = Number.parseInt(
    new TextDecoder().decode(mainResult.stdout).trim(),
    10,
  ) || 0

  // Find all child PIDs recursively
  const childPids = getDescendantPids(pid)
  let childRSS = 0
  for (const cpid of childPids) {
    const result = Bun.spawnSync({
      cmd: ['ps', '-o', 'rss=', '-p', String(cpid)],
      stdout: 'pipe',
    })
    childRSS += Number.parseInt(
      new TextDecoder().decode(result.stdout).trim(),
      10,
    ) || 0
  }

  return mainRSS + childRSS
}

/** Recursively find all descendant PIDs of a process. */
function getDescendantPids(parentPid: number): number[] {
  const result = Bun.spawnSync({
    cmd: ['pgrep', '-P', String(parentPid)],
    stdout: 'pipe',
  })
  const output = new TextDecoder().decode(result.stdout).trim()
  if (!output) return []

  const children = output.split('\n').map(s => Number.parseInt(s, 10)).filter(n => !isNaN(n))
  const descendants = [...children]
  for (const child of children) {
    descendants.push(...getDescendantPids(child))
  }
  return descendants
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

export function header(title: string): void {
  const line = '='.repeat(60)
  console.log(`\n${line}`)
  console.log(`  ${title}`)
  console.log(`${line}\n`)
}

export function reportTable(
  rows: Array<{ label: string; value: string; note?: string }>,
): void {
  const maxLabel = Math.max(...rows.map(r => r.label.length))
  const maxValue = Math.max(...rows.map(r => r.value.length))

  for (const row of rows) {
    const label = row.label.padEnd(maxLabel)
    const value = row.value.padStart(maxValue)
    const note = row.note ? `  (${row.note})` : ''
    console.log(`  ${label}  ${value}${note}`)
  }
}
