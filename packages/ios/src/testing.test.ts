import { afterAll, afterEach, describe, expect, it } from 'bun:test'
import { readFileSync, rmSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { init, restoreShell } from './index'
import type { SimulatorStep } from './testing'
import { createNativeMutationValidator, initSimulatorDriver, serializeSimulatorSteps } from './testing'
import { createTempDir, removeAllTempDirs } from '../../typescript/src/temp-dir'

// Every scratch directory this file made goes when the file is done (#357).
afterAll(removeAllTempDirs)

const folders: string[] = []
function folder(): string {
  const path = createTempDir('craft-shell-test-')
  folders.push(path)
  return path
}
afterEach(() => folders.splice(0).forEach(path => rmSync(path, { recursive: true, force: true })))

describe('package-owned iOS shells', () => {
  it('restores missing Swift for the app, widget and watch without rewriting project metadata', async () => {
    const output = folder()
    await init({ name: 'Zero Swift', bundleId: 'org.example.zero', output, runtimeDir: null, config: { enableWatchApp: true, enableLiveActivities: true } })
    const project = readFileSync(join(output, 'project.yml'), 'utf8')
    const sources = ['Sources/ZeroSwiftApp.swift', 'Shared/CraftActivityAttributes.swift', 'WidgetExtension/ZeroSwiftLiveActivity.swift', 'WatchExtension/ZeroSwiftWatchApp.swift']
    const original = sources.map(path => readFileSync(join(output, path), 'utf8'))
    for (const path of ['Sources', 'Shared', 'WidgetExtension', 'WatchExtension']) rmSync(join(output, path), { recursive: true })
    restoreShell(output)
    expect(sources.map(path => readFileSync(join(output, path), 'utf8'))).toEqual(original)
    expect(readFileSync(join(output, 'project.yml'), 'utf8')).toBe(project)
  })

  it('generates a driver configured for any app and preserves timestamps on a repeat run', () => {
    const output = folder()
    const options = { output, bundleId: 'org.example.app', tabs: ['One', 'A "quote"', 'A \\(literal)'], controlUrl: 'http://localhost:4444', projectName: 'ExampleDriver' }
    initSimulatorDriver(options)
    const file = join(output, 'UITests/DriverTests.swift')
    const source = readFileSync(file, 'utf8')
    expect(source).toContain('XCUIApplication(bundleIdentifier: "org.example.app")')
    expect(source).toContain('"CRAFT_TEST_CONTROL"')
    expect(source).toContain('XCTAssertTrue(ok, what)')
    expect(source).not.toContain('{{')
    expect(source).not.toContain('training.hq')
    const mtime = statSync(file).mtimeMs
    initSimulatorDriver(options)
    expect(statSync(file).mtimeMs).toBe(mtime)
    expect(readFileSync(join(output, 'project.yml'), 'utf8')).toContain('ExampleDriverUITests:')
    expect(() => initSimulatorDriver({ ...options, projectName: '../escape' })).toThrow()
    expect(() => initSimulatorDriver({ ...options, bundleId: 'bad"id' })).toThrow()
  })

  it('serializes typed journeys and rejects extra wire commands and invalid coordinates', () => {
    expect(serializeSimulatorSteps([
      { command: 'launch' }, { command: 'field', index: 0, text: 'demo@example.org' },
      { command: 'tap', text: 'Sign in' }, { command: 'expect', text: 'Today', seconds: 10 },
      { command: 'net', state: 'offline' }, { command: 'tabbar', state: 'shown' },
    ])).toBe('launch\nfield 0 demo@example.org\ntap Sign in\nexpect Today | 10\nnet offline\ntabbar shown\n')
    expect(() => serializeSimulatorSteps([{ command: 'tap', text: 'One\nterminate' }])).toThrow()
    expect(() => serializeSimulatorSteps([{ command: 'tapxy', x: 2, y: 0 }])).toThrow()
    expect(() => serializeSimulatorSteps([{ command: 'wait', seconds: NaN }])).toThrow()
    expect(() => serializeSimulatorSteps([{ command: 'typeid', id: 'two words', text: 'x' }])).toThrow()
  })

  it('serializes guarded steps and exact label checks', () => {
    expect(serializeSimulatorSteps([
      { command: 'ifid', id: 'welcome-skip', step: { command: 'tapid', text: 'welcome-skip' } },
      { command: 'ifid', id: 'consent', step: { command: 'ifid', id: 'consent-agree', step: { command: 'expect', text: 'Agree', seconds: 5 } } },
      { command: 'labelid', id: 'cart-count', text: '2 items' },
    ])).toBe('ifid welcome-skip tapid welcome-skip\nifid consent ifid consent-agree expect Agree | 5\nlabelid cart-count 2 items\n')
    expect(() => serializeSimulatorSteps([{ command: 'ifid', id: 'two words', step: { command: 'launch' } }])).toThrow()
    expect(() => serializeSimulatorSteps([{ command: 'ifid', id: 'x', step: { command: 'tap', text: 'a\nterminate' } }])).toThrow()
    expect(() => serializeSimulatorSteps([{ command: 'labelid', id: '', text: 'x' }])).toThrow()
  })

  it('serializes system journeys without allowing injected commands', () => {
    expect(serializeSimulatorSteps([
      { command: 'notifications' },
      { command: 'systemexpect', text: 'Workout paused', seconds: 15 },
      { command: 'systemtree', name: 'paused-activity' },
      { command: 'systemtap', text: 'Evening unwind' },
      { command: 'systemabsent', text: 'Workout paused' },
    ])).toBe('notifications\nsystemexpect Workout paused | 15\nsystemtree paused-activity\nsystemtap Evening unwind\nsystemabsent Workout paused\n')
    expect(() => serializeSimulatorSteps([{ command: 'systemtap', text: 'Workout\nterminate' }])).toThrow()
    expect(() => serializeSimulatorSteps([{ command: 'systemtree', name: 'two words' }])).toThrow()
  })

  it('handles every typed command in the driver template', () => {
    const output = folder()
    initSimulatorDriver({ output, bundleId: 'org.example.app' })
    const source = readFileSync(join(output, 'UITests/DriverTests.swift'), 'utf8')
    const handled = new Set([...source.matchAll(/case "([a-z]+)"/g)].map(match => match[1]))
    const commands: SimulatorStep['command'][] = ['launch', 'activate', 'terminate', 'home', 'back', 'return', 'unlabelled', 'background', 'wait', 'delay', 'net', 'swipe', 'edge', 'tabbar', 'tapxy', 'field', 'typeid', 'labelid', 'expect', 'expectexact', 'expectid', 'tap', 'tapif', 'tapid', 'tapexact', 'type', 'absent', 'absentid', 'selected', 'tab', 'scrollto', 'dismiss', 'log', 'shot', 'tree', 'audit', 'exec', 'openurl', 'ifid', 'notifications', 'systemexpect', 'systemabsent', 'systemtap', 'systemtree']
    expect(commands.filter(command => !handled.has(command))).toEqual([])
    // ifid re-enters the same dispatcher, so a guarded command is any command.
    expect(source).toContain('func run(_ line: String)')
    expect(source).toMatch(/case "ifid":[\s\S]*?run\(rest\[1\]\)/)
  })

  const macTest = process.platform === 'darwin' ? it : it.skip
  macTest('runs the real Swift mutation host and rejects an update to an absent node', () => {
    const validator = createNativeMutationValidator()
    try {
      const render = { type: 'RENDER', payload: { document: { id: 'root', type: 'View', props: {}, style: {}, events: {}, children: [] } } }
      const accepted = validator.validate([render])
      expect(accepted.exitCode, accepted.stdout + accepted.stderr).toBe(0)
      const rejected = validator.validate([render, { type: 'MUTATE', payload: { batchId: 'bad', version: 1, baseRevision: 0, revision: 1, operations: [{ op: 'updateNode', id: 'absent', patch: { props: { text: 'x' } } }] } }])
      expect(rejected.exitCode).not.toBe(0)
      expect(rejected.stdout).toContain('UNKNOWN_NODE')
    }
    finally { validator.dispose() }
    expect(() => validator.validate([])).toThrow('disposed')
  }, 60_000)
})
