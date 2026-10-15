import { describe, expect, it } from 'bun:test'
import { createBrowserStorage } from '../browser/storage'

function storage(): Storage {
  const data = new Map<string, string>()
  return { get length() { return data.size }, key: index => [...data.keys()][index] ?? null, getItem: key => data.get(key) ?? null, setItem: (key, value) => { data.set(key, String(value)) }, removeItem: key => { data.delete(key) }, clear: () => data.clear() }
}
async function fixture() {
  const saved = storage()
  const changes: string[] = []
  const browser = await createBrowserStorage({ storage: saved, namespace: 'app', tokenKey: 'auth_token', accountKeys: ['auth_user'], hash: async value => `hash-${value}`, changed: name => changes.push(name) })
  return { saved, browser, changes }
}
describe('browser account persistence', () => {
  it('retains only the current account and shares the configured sign-in key', async () => {
    const { saved, browser, changes } = await fixture()
    await browser.craft.snapshots.set('app', { apiBase: '/api' })
    await browser.call('SecureStorage', 'set', ['auth.token', 'ava'])
    await browser.craft.snapshots.set('today', { user: 'Ava' })
    await browser.call('Storage', 'set', ['draft', { text: 'Private' }])
    expect(saved.getItem('auth_token')).toBe('ava')
    expect(browser.craft.storage.getSync('draft')).toEqual({ text: 'Private' })
    saved.setItem('auth_user', JSON.stringify({ name: 'Ava' }))
    await browser.call('SecureStorage', 'set', ['auth.token', 'ben'])
    expect(saved.getItem('auth_user')).toBeNull()
    expect(browser.craft.snapshots.get('today')).toBeNull()
    expect(browser.craft.storage.getSync('draft')).toBeNull()
    expect(browser.craft.snapshots.get('app')).toEqual({ apiBase: '/api' })
    expect([...Array(saved.length)].map((_, i) => saved.key(i)).join()).not.toContain('hash-ava')
    expect(changes).toContain('session')
  })
  it('blocks stale synchronous reads and writes during a cross-tab transition', async () => {
    const { saved, browser } = await fixture()
    await browser.call('SecureStorage', 'set', ['auth.token', 'ava'])
    await browser.craft.snapshots.set('today', { user: 'Ava' })
    saved.setItem('auth_token', 'ben')
    expect(browser.craft.snapshots.get('today')).toBeNull()
    expect(await browser.craft.snapshots.set('today', { user: 'Stale response' })).toBe(false)
    browser.craft.storage.setSync('draft', 'Stale edit')
    await browser.accountChanged()
    expect(browser.craft.storage.getSync('draft')).toBeNull()
    expect(browser.craft.snapshots.get('today')).toBeNull()
    expect(browser.scope()).toBe('hash-ben')
  })
  it('forgets credentials and snapshots on sign-out without clearing another app', async () => {
    const { saved, browser } = await fixture()
    saved.setItem('other-app', 'keep')
    await browser.call('SecureStorage', 'set', ['auth.token', 'ava'])
    await browser.call('SecureStorage', 'set', ['private-key', 'secret'])
    await browser.craft.snapshots.set('today', { user: 'Ava' })
    await browser.call('SecureStorage', 'clear', [])
    expect(browser.craft.secureStorage.getSync('auth.token')).toBeNull()
    expect(browser.craft.secureStorage.getSync('private-key')).toBeNull()
    expect(browser.craft.snapshots.keys()).toEqual([])
    expect(saved.getItem('other-app')).toBe('keep')
  })
})
