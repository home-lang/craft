import { describe, expect, it } from 'bun:test'
import { appShortcutsSwift } from './app-shortcuts'

const shortcut = { id: 'saved-trails', title: 'Saved trails', subtitle: 'Your favorites', symbol: 'heart.fill', url: 'outdoors://profile?tab=saved', phrases: ['Show my saved trails in {app}'] }
describe('configured iOS App Intents', () => {
  it('generates real Siri interpolation and opens the configured native destination', () => {
    const source = appShortcutsSwift([shortcut], ['outdoors'])
    expect(source).toContain('struct CraftShortcutSavedTrailsIntent: AppIntent')
    expect(source).toContain('"Show my saved trails in \\(.applicationName)"')
    expect(source).toContain('URL(string: "outdoors://profile?tab=saved")')
    expect(source).toContain('@available(iOS 16.4, *)')
    expect(appShortcutsSwift()).not.toContain('AppShortcutsProvider')
  })
  it('refuses shortcuts whose scheme the app does not own or phrases Siri cannot index', () => {
    expect(() => appShortcutsSwift([shortcut])).toThrow('registered app URL scheme')
    expect(() => appShortcutsSwift([{ ...shortcut, phrases: ['No app name'] }], ['outdoors'])).toThrow('exactly one {app}')
    expect(() => appShortcutsSwift([shortcut, shortcut], ['outdoors'])).toThrow('duplicate')
  })
})
