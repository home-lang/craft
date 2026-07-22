import { describe, expect, it } from 'bun:test'
import { dmgCapacityMegabytes, dmgCreateArguments, formatPackagingCommandError, renderWixSource, windowsExecutableName } from './package'

describe('Windows MSI packaging', () => {
  it('renders a deterministic major-upgrade installer without shell interpolation', () => {
    const first = renderWixSource({ name: 'Craft App', version: '1.2.3', manufacturer: 'Stacks & Co' }, 'Craft_App.exe')
    expect(renderWixSource({ name: 'Craft App', version: '1.2.3', manufacturer: 'Stacks & Co' }, 'Craft_App.exe')).toBe(first)
    expect(first).toContain('MajorUpgrade')
    expect(first).toContain('AllowDowngrades="yes"')
    expect(first).toContain('Stacks &amp; Co')
    expect(first).toContain('Source="Craft_App.exe"')
    expect(first).not.toContain('exec(')
  })

  it('rejects versions WiX cannot compare', () => {
    expect(() => renderWixSource({ name: 'Craft', version: 'next', manufacturer: 'Craft' }, 'craft.exe')).toThrow('MSI version')
  })

  it('preserves valid application names independently of WiX identifiers', () => {
    expect(windowsExecutableName('craft-lifecycle')).toBe('craft-lifecycle.exe')
    expect(windowsExecutableName('Craft App')).toBe('Craft App.exe')
    expect(() => windowsExecutableName('craft/app')).toThrow('Invalid Windows application name')
    expect(() => windowsExecutableName('CON')).toThrow('Reserved Windows application name')
  })
})

describe('macOS packaging diagnostics', () => {
  it('retains hdiutil output in a failed package result', () => {
    expect(formatPackagingCommandError('hdiutil', 1, '', 'create failed - Resource temporarily unavailable\n'))
      .toBe('hdiutil exited with code 1: create failed - Resource temporarily unavailable')
    expect(formatPackagingCommandError('hdiutil', 1, '', '')).toBe('hdiutil exited with code 1')
  })

  it('overrides source-folder sizing with filesystem headroom', () => {
    expect(dmgCapacityMegabytes(0)).toBe(64)
    expect(dmgCapacityMegabytes(100 * 1024 * 1024)).toBe(157)
    expect(() => dmgCapacityMegabytes(-1)).toThrow('non-negative safe integer')
    expect(dmgCreateArguments({
      appBundlePath: '/tmp/Craft.app',
      outputPath: '/tmp/Craft.dmg',
      volumeName: 'Craft',
    }, 100 * 1024 * 1024)).toEqual([
      'create',
      '-volname', 'Craft',
      '-srcfolder', '/tmp/Craft.app',
      '-size', '157m',
      '-ov',
      '-format', 'UDZO',
      '/tmp/Craft.dmg',
    ])
  })
})
