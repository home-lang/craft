import { describe, expect, it } from 'bun:test'
import mobile, { background, DEFAULT_SESSION_TOKEN_KEY, session, SESSION_EVENT, SESSION_MESSAGE } from '../api/mobile'

async function withWindow(window: Record<string, unknown> | undefined, run: () => Promise<void> | void): Promise<void> {
  const previous = (globalThis as any).window
  ;(globalThis as any).window = window
  try { await run() }
  finally { (globalThis as any).window = previous }
}

describe('session', () => {
  it('names the event, the bridge message and the default key', () => {
    expect(SESSION_EVENT).toBe('craftsession')
    expect(SESSION_MESSAGE).toBe('SESSION_CHANGED')
    expect(DEFAULT_SESSION_TOKEN_KEY).toBe('auth.token')
    expect(mobile.session).toBe(session)
  })

  it('reads and follows the host session, normalising empty tokens to null', async () => {
    const listeners: Array<(token: unknown, previous: unknown) => void> = []
    let current: unknown = 'ava'
    const craft = {
      session: {
        token: () => current,
        onChange: (callback: (token: unknown, previous: unknown) => void) => {
          listeners.push(callback)
          return () => listeners.splice(listeners.indexOf(callback), 1)
        },
      },
    }
    await withWindow({ craft }, () => {
      expect(session.token()).toBe('ava')
      current = ''
      expect(session.token()).toBeNull()
      const heard: unknown[] = []
      const stop = session.onChange((token, previous) => heard.push([token, previous]))
      listeners.forEach(listener => listener('ben', ''))
      listeners.forEach(listener => listener(null, 'ben'))
      stop()
      expect(listeners).toHaveLength(0)
      expect(heard).toEqual([['ben', null], [null, 'ben']])
    })
  })

  it('falls back to the craftsession event, and reports no token off a Craft host', async () => {
    const heard: unknown[] = []
    const target = new EventTarget()
    const previous = { add: globalThis.addEventListener, remove: globalThis.removeEventListener }
    globalThis.addEventListener = target.addEventListener.bind(target) as any
    globalThis.removeEventListener = target.removeEventListener.bind(target) as any
    try {
      await withWindow({}, () => {
        expect(session.token()).toBeNull()
        const stop = session.onChange((token, before) => heard.push([token, before]))
        target.dispatchEvent(new CustomEvent('craftsession', { detail: { key: 'auth.token', token: 'ava', previous: null } }))
        stop()
        target.dispatchEvent(new CustomEvent('craftsession', { detail: { key: 'auth.token', token: 'ben', previous: 'ava' } }))
      })
    }
    finally {
      globalThis.addEventListener = previous.add
      globalThis.removeEventListener = previous.remove
    }
    expect(heard).toEqual([['ava', null]])
    expect(() => session.onChange(undefined as any)).toThrow(TypeError)
  })
})

describe('background', () => {
  it('passes the wake id through to the shell', async () => {
    const calls: unknown[][] = []
    const craft = { background: { complete: async (...args: unknown[]) => { calls.push(args); return true } } }
    await withWindow({ craft }, async () => {
      expect(await background.complete(false, 'refresh-7')).toBe(true)
      expect(await background.complete()).toBe(true)
    })
    expect(calls).toEqual([[false, 'refresh-7'], [true, undefined]])
  })
})
