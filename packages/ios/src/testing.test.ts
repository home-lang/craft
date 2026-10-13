import { afterEach, describe, expect, it } from 'bun:test'
import { mkdtempSync, readFileSync, rmSync, statSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { init, restoreShell } from './index'
import { createNativeMutationValidator, initSimulatorDriver, serializeSimulatorSteps } from './testing'

const folders: string[] = []
function folder(): string {
  const path = mkdtempSync(join(tmpdir(), 'craft-shell-test-'))
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
