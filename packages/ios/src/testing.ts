import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { spawnSync } from 'node:child_process'

const templates = join(dirname(import.meta.dir), 'templates/testing')

export interface SimulatorDriverOptions {
  output: string
  /** The installed app to drive; the test host is a separate application. */
  bundleId: string
  projectName?: string
  bundleIdPrefix?: string
  deploymentTarget?: string
  controlUrl?: string
  tabs?: readonly string[]
}

function bundleIdentifier(value: string): void {
  if (!/^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$/.test(value))
    throw new Error(`Invalid bundle identifier: ${value}`)
}

function swiftString(value: string): string {
  return JSON.stringify(value).replace(/\\u([a-f\d]{4})/gi, '\\u{$1}')
}

/** Generate the reusable XCUITest shell from package templates. No app-owned Swift. */
export function initSimulatorDriver(options: SimulatorDriverOptions): void {
  const { output, bundleId } = options
  const name = options.projectName ?? 'CraftDriver'
  const prefix = options.bundleIdPrefix ?? `${bundleId}.driver`
  const version = options.deploymentTarget ?? '17.0'
  const control = options.controlUrl ?? 'http://127.0.0.1:3401'
  bundleIdentifier(bundleId)
  bundleIdentifier(prefix)
  if (!/^[A-Za-z][A-Za-z0-9]*$/.test(name)) throw new Error('projectName must be an alphanumeric Xcode name starting with a letter')
  if (!/^\d+\.\d+$/.test(version) || Number(version) < 17) throw new Error('The simulator driver requires iOS 17.0 or newer')
  if (!['http:', 'https:'].includes(new URL(control).protocol)) throw new Error('controlUrl must use HTTP or HTTPS')
  const replacements: Record<string, string> = {
    PROJECT_NAME: name,
    BUNDLE_PREFIX: prefix,
    IOS_VERSION: version,
    BUNDLE_ID: swiftString(bundleId),
    CONTROL_URL: swiftString(control),
    TABS: `[${(options.tabs ?? []).map(swiftString).join(', ')}]`,
  }
  for (const [source, destination] of [
    ['HostApp.swift', 'Host/HostApp.swift'],
    ['DriverTests.swift.template', 'UITests/DriverTests.swift'],
    ['project.yml.template', 'project.yml'],
  ]) {
    const path = join(output, destination)
    mkdirSync(dirname(path), { recursive: true })
    const content = readFileSync(join(templates, source), 'utf8').replace(/\{\{([A-Z_]+)\}\}/g, (_, key: string) => replacements[key])
    // Keep timestamps stable so a repeat run reuses build-for-testing output.
    let previous: string | undefined
    try { previous = readFileSync(path, 'utf8') }
    catch { /* First generation. */ }
    if (previous !== content) writeFileSync(path, content)
  }
}

export type SimulatorStep =
  | { command: 'launch' | 'activate' | 'terminate' | 'home' | 'back' | 'return' | 'unlabelled' }
  | { command: 'background' | 'wait', seconds: number }
  | { command: 'delay', milliseconds: number }
  | { command: 'net', state: 'online' | 'offline' }
  | { command: 'swipe', direction: 'up' | 'down' | 'left' | 'right' }
  /** The system back-swipe: a drag in from the left edge (or the right). */
  | { command: 'edge', direction: 'left' | 'right' }
  | { command: 'tabbar', state: 'shown' | 'hidden' }
  | { command: 'tapxy', x: number, y: number }
  | { command: 'field', index: number, text: string }
  | { command: 'typeid' | 'labelid', id: string, text: string }
  | { command: 'expect' | 'expectexact' | 'expectid', text: string, seconds?: number }
  | { command: 'tap' | 'tapif' | 'tapid' | 'tapexact' | 'type' | 'absent' | 'absentid' | 'selected' | 'tab' | 'scrollto' | 'dismiss' | 'log', text: string }
  | { command: 'shot' | 'tree' | 'audit' | 'exec', name: string }
  | { command: 'openurl', url: string }
  /** Runs `step` only when the element with this identifier is there (a screen shown the first time). */
  | { command: 'ifid', id: string, step: SimulatorStep }

/** Typed journeys use the same wire protocol as existing line-based scripts. */
export function serializeSimulatorSteps(steps: readonly SimulatorStep[]): string {
  const number = (value: number): number => {
    if (!Number.isFinite(value) || value < 0) throw new Error('Simulator values must be finite and nonnegative')
    return value
  }
  const token = (value: string): string => {
    if (!value || /\s/.test(value)) throw new Error('Simulator identifiers must be nonempty single tokens')
    return value
  }
  const line = (step: SimulatorStep): string => {
    let arg = ''
    if ('step' in step) arg = `${token(step.id)} ${line(step.step)}`
    else if ('seconds' in step && !('text' in step)) arg = String(number(step.seconds!))
    else if ('milliseconds' in step) arg = String(number(step.milliseconds))
    else if ('state' in step) arg = step.state
    else if ('direction' in step) arg = step.direction
    else if ('x' in step) {
      if (number(step.x) > 1 || number(step.y) > 1) throw new Error('tapxy coordinates must be between 0 and 1')
      arg = `${step.x} ${step.y}`
    }
    else if ('index' in step) {
      if (!Number.isInteger(number(step.index))) throw new Error('field index must be an integer')
      arg = `${step.index} ${step.text}`
    }
    else if ('id' in step) arg = `${token(step.id)} ${step.text}`
    else if ('text' in step) {
      arg = step.text
      if ('seconds' in step && step.seconds !== undefined) {
        if (arg.includes('|')) throw new Error('A timed expectation cannot contain |')
        arg += ` | ${number(step.seconds)}`
      }
    }
    else if ('name' in step) arg = token(step.name)
    else if ('url' in step) arg = step.url
    if (/[\r\n]/.test(arg)) throw new Error('Simulator arguments cannot contain newlines')
    return `${step.command}${arg ? ` ${arg}` : ''}`
  }
  return `${steps.map(line).join('\n')}\n`
}

export interface NativeValidationResult {
  exitCode: number
  stdout: string
  stderr: string
}

export interface NativeMutationValidator {
  validate(messages: readonly { type: string, payload?: unknown }[]): NativeValidationResult
  dispose(): void
}

/** Compile the actual Foundation mutation host once, then validate captured STX messages. Requires macOS and swiftc. */
export function createNativeMutationValidator(): NativeMutationValidator {
  const output = mkdtempSync(join(tmpdir(), 'craft-native-mutation-'))
  const binary = join(output, 'validate')
  try {
    writeFileSync(join(output, 'main.swift'), readFileSync(join(templates, 'MutationValidator.swift')))
    const build = Bun.spawnSync(['swiftc', join(templates, '../CraftNativeMutation.swift'), join(output, 'main.swift'), '-o', binary])
    if (build.exitCode !== 0) throw new Error(build.stderr.toString())
  }
  catch (error) {
    rmSync(output, { recursive: true, force: true })
    throw error
  }
  let disposed = false
  return {
    validate(messages) {
      if (disposed) throw new Error('The native mutation validator has been disposed')
      const input = join(output, 'messages.json')
      writeFileSync(input, JSON.stringify(messages))
      const report = join(output, 'result.txt')
      rmSync(report, { force: true })
      const result = spawnSync(binary, [input, report], { encoding: 'utf8' })
      let stdout = result.stdout ?? ''
      try { stdout = readFileSync(report, 'utf8') }
      catch { /* A compiler/runtime failure did not produce a validation report. */ }
      return { exitCode: result.status ?? 1, stdout, stderr: result.stderr || result.error?.message || (result.signal ? `Validator terminated by ${result.signal}` : '') }
    },
    dispose() {
      disposed = true
      rmSync(output, { recursive: true, force: true })
    },
  }
}
