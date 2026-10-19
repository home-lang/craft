import { expect, test } from 'bun:test'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

const root = join(import.meta.dir, '..')
const ownership = readFileSync(join(root, 'docs/architecture/multi-window-ownership.md'), 'utf8')
const sourceContracts = [
  ['packages/zig/src/macos_theme.zig', 'getGlobalWebView'],
  ['packages/zig/src/bridge_screen.zig', 'getGlobalWebView'],
  ['packages/zig/src/macos_deep_link.zig', 'getGlobalWebView'],
  ['packages/zig/src/bridge_location.zig', 'getGlobalWebView'],
  ['packages/zig/src/bridge_iap.zig', 'getGlobalWebView'],
  ['packages/zig/src/bridge_local_server.zig', 'getGlobalWebView'],
  ['packages/zig/src/bridge_screen_sharing.zig', 'getGlobalWebView'],
  ['packages/ios/templates/CraftApp.swift', 'class CraftEventManager'],
] as const
const sources = [
  'Theme changes (`macos_theme.zig`)',
  'Screen configuration changes (`bridge_screen.zig`)',
  'Deep links (`macos_deep_link.zig`)',
  'Location updates (`bridge_location.zig`)',
  'In-app purchase updates (`bridge_iap.zig`)',
  'Local-server requests (`bridge_local_server.zig`)',
  'Screen-sharing changes (`bridge_screen_sharing.zig`)',
  'Tray and application-menu actions',
]

function policyRows(): string[][] {
  return ownership
    .split('\n')
    .filter(line => line.startsWith('| ') && line.includes('Primary-only'))
    .map(line => line.split('|').slice(1, -1).map(cell => cell.trim()))
}

test('keeps every process-global source explicitly primary-only', () => {
  const rows = policyRows()
  expect(rows).toHaveLength(sources.length)
  expect(new Set(rows.map(row => row[0])).size).toBe(rows.length)
  expect(rows.map(row => row[0])).toEqual(sources)
  for (const row of rows) {
    expect(row).toHaveLength(4)
    expect(row[1]).toBe('Primary-only')
    expect(row[2]).toContain('Primary page')
    expect(row[3].length).toBeGreaterThan(20)
  }
})

test('requires an explicit migration contract before changing delivery policy', () => {
  expect(ownership).toContain('subscriber identity')
  expect(ownership).toContain('navigation/close/destroy/orphan adoption')
  expect(ownership).toContain('unrelated-page exclusion')
  expect(ownership).toContain('Opening a child must never implicitly make it the new sink.')
})

test('keeps the primary-only source implementations anchored to their owner', () => {
  for (const [relativePath, marker] of sourceContracts) {
    const source = readFileSync(join(root, relativePath), 'utf8')
    expect(source, relativePath).toContain(marker)
  }
})
