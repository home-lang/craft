import { expect, test } from 'bun:test'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const root = join(import.meta.dir, '..')
const table = readFileSync(join(root, 'docs/api/mobile/ios-validation-conformance.md'), 'utf8')
const swift = readFileSync(join(root, 'packages/ios/templates/CraftApp.swift'), 'utf8')

// The table uses public native capability names; the legacy Swift shim uses
// its older page-bridge action names. Keep the translation explicit so a
// renamed action fails review instead of leaving a plausible-looking row.
const legacyActions = new Map([
  ['notifications.cancel', 'cancelNotification'],
  ['background.schedule', 'scheduleBackgroundTask'],
  ['background.cancel', 'cancelBackgroundTask'],
  ['files.saveFile', 'saveFile'],
  ['files.pickFile', 'pickFile'],
])

function rows(): string[][] {
  return table
    .split('\n')
    .filter(line => line.startsWith('| `'))
    .map(line => line.split('|').slice(1, -1).map(cell => cell.trim()))
}

test('every iOS validation divergence row names a real action and evidence', () => {
  const entries = rows()
  expect(entries.length).toBeGreaterThan(0)
  for (const [actionCell, input, zigResult, swiftBehavior, platform, evidence] of entries) {
    expect(input.length).toBeGreaterThan(0)
    expect(zigResult.length).toBeGreaterThan(0)
    expect(swiftBehavior.length).toBeGreaterThan(0)
    expect(platform.length).toBeGreaterThan(0)
    expect(evidence.length).toBeGreaterThan(0)

    const actions = actionCell.match(/`([^`]+)`/g)?.map(action => action.slice(1, -1)) ?? []
    expect(actions.length).toBeGreaterThan(0)
    for (const action of actions.flatMap(value => value.split(/\s*\/\s*/))) {
      const legacy = legacyActions.get(action)
      expect(legacy).toBeDefined()
      expect(swift).toContain(`case "${legacy}"`)
    }

    const evidencePaths = [...evidence.matchAll(/`(packages\/[^`:]+\.(?:zig|swift))/g)].map(match => match[1])
    expect(evidencePaths.length).toBeGreaterThan(0)
    for (const path of evidencePaths) expect(existsSync(join(root, path))).toBe(true)

    if (platform.includes('No simulator required')) expect(platform).toContain('validation')
  }
})

test('the table keeps simulator-only work visibly separate from host-neutral checks', () => {
  const entries = rows()
  expect(entries.some(([, , , , platform]) => platform.includes('No simulator required'))).toBe(true)
  expect(entries.some(([, , , , platform]) => platform.includes('simulator/device'))).toBe(true)
})
