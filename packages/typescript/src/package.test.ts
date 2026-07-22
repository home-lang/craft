import { describe, expect, it } from 'bun:test'
import { renderWixSource } from './package'

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
})
