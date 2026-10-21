import { expect, test } from 'bun:test'
import { createBrowserLifecycle } from '../browser/lifecycle'

test('browser lifecycle reports background once and restores from bfcache with cleanup', () => {
  const page = Object.assign(new EventTarget(), { hidden: false })
  const host = new EventTarget()
  const events: string[] = []
  const states: string[] = []
  const lifecycle = createBrowserLifecycle(page as unknown as Document, host as Window, state => events.push(state))
  const unsubscribe = lifecycle.onStateChange(state => states.push(state))
  expect(lifecycle.getState()).toBe('active')
  page.hidden = true
  page.dispatchEvent(new Event('visibilitychange'))
  host.dispatchEvent(new Event('pagehide'))
  page.hidden = false
  host.dispatchEvent(new Event('pageshow'))
  expect(events).toEqual(['background', 'active'])
  expect(states).toEqual(events)
  unsubscribe()
  host.dispatchEvent(new Event('pagehide'))
  expect(states).toHaveLength(2)
  lifecycle.dispose()
  host.dispatchEvent(new Event('pageshow'))
  expect(events).toHaveLength(3)
  expect(lifecycle.getState()).toBe('background')
})
