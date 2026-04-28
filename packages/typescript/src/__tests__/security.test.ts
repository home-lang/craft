import { describe, expect, it } from 'bun:test'

/**
 * Tests for Round 2 Security & Reliability Improvements
 */

describe('Fix #2: eval() replaced with sandboxed Function', () => {
  it('devtools should not use raw eval', async () => {
    const devtoolsSource = await Bun.file(
      new URL('../dev/devtools.ts', import.meta.url),
    ).text()

    // Should NOT contain raw eval() calls (except in comments)
    const lines = devtoolsSource.split('\n')
    const evalLines = lines.filter(
      (line) =>
        line.includes('eval(') && !line.trim().startsWith('//') && !line.trim().startsWith('*'),
    )

    // If eval is used, it should be the sandboxed version (new Function)
    for (const line of evalLines) {
      // Allow 'sandboxedEval' variable name but not raw eval()
      expect(line).not.toMatch(/\beval\s*\(/)
    }
  })
})

describe('Fix #3: XSS prevention via escapeHtml', () => {
  it('devtools should have escapeHtml function', async () => {
    const devtoolsSource = await Bun.file(
      new URL('../dev/devtools.ts', import.meta.url),
    ).text()

    expect(devtoolsSource).toContain('function escapeHtml')
    expect(devtoolsSource).toContain('&amp;')
    expect(devtoolsSource).toContain('&lt;')
    expect(devtoolsSource).toContain('&gt;')
  })
})

describe('Fix #7: Bridge core has no empty catches', () => {
  it('bridge/core.ts should log errors in catch blocks', async () => {
    const bridgeSource = await Bun.file(
      new URL('../bridge/core.ts', import.meta.url),
    ).text()

    // Should not have empty catch blocks
    const emptyCatchPattern = /catch\s*\{[\s\n]*return[\s\n]*\}/g
    const matches = bridgeSource.match(emptyCatchPattern) || []
    expect(matches.length).toBe(0)
  })
})

describe('Fix #8: Path traversal protection in fs API', () => {
  it('fs module should have validatePath function', async () => {
    const fsSource = await Bun.file(new URL('../api/fs.ts', import.meta.url)).text()

    expect(fsSource).toContain('function validatePath')
    expect(fsSource).toContain('..')
    expect(fsSource).toContain('traversal')
  })

  it('fs module should validate paths in read/write operations', async () => {
    const fsSource = await Bun.file(new URL('../api/fs.ts', import.meta.url)).text()

    // validatePath should be called in key functions
    expect(fsSource).toContain('validatePath(path)')
  })
})

describe('Fix #9: No unsafe any casts in crypto', () => {
  it('security module should use type-safe auth tag access', async () => {
    const securitySource = await Bun.file(
      new URL('../security/index.ts', import.meta.url),
    ).text()

    // Should NOT cast cipher/decipher to any for auth tag
    expect(securitySource).not.toContain('(cipher as any)')
    expect(securitySource).not.toContain('(decipher as any)')

    // Should use type-safe feature detection
    expect(securitySource).toContain("'getAuthTag' in cipher")
    expect(securitySource).toContain("'setAuthTag' in decipher")
  })
})

describe('Fix #10: No O(n^2) string concatenation', () => {
  it('hot-reload should not use string concatenation in loops', async () => {
    const hrSource = await Bun.file(
      new URL('../dev/hot-reload.ts', import.meta.url),
    ).text()

    // Should not have the O(n^2) pattern: binary += String.fromCharCode
    const lines = hrSource.split('\n')
    const concatInLoop = lines.filter(
      (line) => line.includes('+= String.fromCharCode') && !line.trim().startsWith('//'),
    )
    expect(concatInLoop.length).toBe(0)
  })
})

describe('Fix #11: No workspace:* in create-craft', () => {
  it('create-craft should use versioned dependencies', async () => {
    const cliSource = await Bun.file(
      new URL('../../../create-craft/bin/cli.ts', import.meta.url),
    ).text()

    // Should NOT contain workspace:* references
    expect(cliSource).not.toContain("'workspace:*'")
    expect(cliSource).not.toContain('"workspace:*"')
  })
})

describe('Fix #13: Platform detection prefers native bridge', () => {
  it('process module should check craft bridge before user-agent', async () => {
    const processSource = await Bun.file(
      new URL('../api/process.ts', import.meta.url),
    ).text()

    // Should check craft._platform before falling back to user-agent
    expect(processSource).toContain('craft?._platform')
  })
})

describe('Fix #16: Clipboard errors are logged', () => {
  it('clipboard module should not silently swallow errors', async () => {
    const clipSource = await Bun.file(
      new URL('../api/clipboard.ts', import.meta.url),
    ).text()

    // Should not have bare `.catch(() => undefined)`
    expect(clipSource).not.toContain('.catch(() => undefined)')
  })
})
