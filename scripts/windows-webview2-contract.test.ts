import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'bun:test'

const windowsSource = readFileSync(join(import.meta.dir, '..', 'packages', 'zig', 'src', 'windows.zig'), 'utf8')

describe('Windows WebView2 COM contract', () => {
  it('initializes an STA apartment before creating the WebView2 environment', () => {
    expect(windowsSource).toContain('pub extern "ole32" fn CoInitializeEx')
    expect(windowsSource).toContain('pub const COINIT_APARTMENTTHREADED: DWORD = 0x2')
    expect(windowsSource).toContain('if (hr == RPC_E_CHANGED_MODE)')

    const initialize = windowsSource.indexOf('try initializeCom();')
    const createEnvironment = windowsSource.indexOf('const createEnv = loadWebView2()')
    expect(initialize).toBeGreaterThanOrEqual(0)
    expect(createEnvironment).toBeGreaterThan(initialize)
  })

  it('keeps COM alive until WebView2 controllers have been released', () => {
    expect(windowsSource).toContain('pub fn deinitializeCom() void')
    expect(windowsSource).toContain('pub fn runApp() void')
    expect(windowsSource).toContain('deinitializeCom();')
  })
})
