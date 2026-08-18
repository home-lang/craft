/**
 * Coverage for the pantry-aligned binary resolver.
 *
 * The contract: `resolveCraftBinary` always returns *something*
 * spawnable, and never probes a matrix of paths. The path-of-least-
 * surprise is `'craft'` (PATH lookup, populated by `pantry install
 * craft`); the only escape hatches are an explicit caller-supplied
 * path or `CRAFT_BIN`.
 */

import { afterEach, beforeEach, describe, expect, it } from 'bun:test'
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

import { craftBinaryIsCliShimMessage, craftBinaryNotFoundMessage, resolveCraftBinary } from '../binary-resolver'

describe('resolveCraftBinary', () => {
  let savedEnv: string | undefined

  beforeEach(() => {
    savedEnv = process.env.CRAFT_BIN
    delete process.env.CRAFT_BIN
  })

  afterEach(() => {
    if (savedEnv !== undefined) process.env.CRAFT_BIN = savedEnv
    else delete process.env.CRAFT_BIN
  })

  it('returns the bare `craft` so PATH (pantry-installed) wins by default', () => {
    expect(resolveCraftBinary()).toBe('craft')
  })

  it('honours an explicit caller-supplied path when it exists', () => {
    const dir = mkdtempSync(join(tmpdir(), 'craft-resolver-'))
    const bin = join(dir, 'craft-fake')
    writeFileSync(bin, '#!/bin/sh\necho hi\n', { mode: 0o755 })
    try {
      expect(resolveCraftBinary(bin)).toBe(bin)
    }
    finally {
      rmSync(dir, { recursive: true, force: true })
    }
  })

  it('throws when an explicit path does not exist', () => {
    expect(() => resolveCraftBinary('/no/such/file')).toThrow(/not found/)
  })

  it('honours CRAFT_BIN when no explicit path is given', () => {
    const dir = mkdtempSync(join(tmpdir(), 'craft-resolver-'))
    const bin = join(dir, 'craft-fake-env')
    writeFileSync(bin, '#!/bin/sh\necho hi\n', { mode: 0o755 })
    process.env.CRAFT_BIN = bin
    try {
      expect(resolveCraftBinary()).toBe(bin)
    }
    finally {
      rmSync(dir, { recursive: true, force: true })
    }
  })

  it('throws when CRAFT_BIN points at a missing path', () => {
    process.env.CRAFT_BIN = '/no/such/file'
    expect(() => resolveCraftBinary()).toThrow(/CRAFT_BIN/)
  })

  it('explicit path wins over CRAFT_BIN', () => {
    const dir = mkdtempSync(join(tmpdir(), 'craft-resolver-'))
    const explicit = join(dir, 'explicit')
    const env = join(dir, 'env')
    writeFileSync(explicit, 'x', { mode: 0o755 })
    writeFileSync(env, 'x', { mode: 0o755 })
    process.env.CRAFT_BIN = env
    try {
      expect(resolveCraftBinary(explicit)).toBe(explicit)
    }
    finally {
      rmSync(dir, { recursive: true, force: true })
    }
  })
})

describe('craftBinaryNotFoundMessage', () => {
  it('mentions the pantry install command', () => {
    const msg = craftBinaryNotFoundMessage('craft')
    expect(msg).toContain('pantry install craft')
  })

  it('mentions deps.yaml / pantry.jsonc for project-level install', () => {
    const msg = craftBinaryNotFoundMessage('craft')
    expect(msg).toContain('deps.yaml')
    expect(msg).toContain('pantry.jsonc')
  })

  it('echoes the path that was tried so the user knows which binary was looked up', () => {
    const msg = craftBinaryNotFoundMessage('/custom/path/craft')
    expect(msg).toContain('/custom/path/craft')
  })

  it('does not advertise the legacy "build:core" workflow that pantry replaced', () => {
    const msg = craftBinaryNotFoundMessage('craft')
    expect(msg).not.toContain('bun run build:core')
    expect(msg).not.toContain('zig-out/bin/craft')
  })
})

describe('SDK and CLI both delegate to the shared resolver', () => {
  it('src/index.ts no longer probes monorepo zig-out paths', async () => {
    const src = await Bun.file(new URL('../index.ts', import.meta.url)).text()
    expect(src).toContain('resolveCraftBinary')
    // The old probing matrix must be gone.
    expect(src).not.toContain('packages/zig/zig-out/bin/craft')
    expect(src).not.toContain('zig-out/bin/craft')
    expect(src).not.toContain("Searched:\\n")
  })

  it('bin/cli.ts no longer probes monorepo zig-out paths', async () => {
    const src = await Bun.file(new URL('../../bin/cli.ts', import.meta.url)).text()
    expect(src).toContain('resolveCraftBinary')
    expect(src).not.toContain('packages/zig/zig-out/bin/craft')
    expect(src).not.toContain('zig-out/bin/craft')
  })

  it('error path uses the shared pantry-pointing message', async () => {
    const idx = await Bun.file(new URL('../index.ts', import.meta.url)).text()
    const cli = await Bun.file(new URL('../../bin/cli.ts', import.meta.url)).text()
    expect(idx).toContain('craftBinaryNotFoundMessage')
    expect(cli).toContain('craftBinaryNotFoundMessage')
  })
})

describe('CLI shim re-entry', () => {
  it('marks spawned children so a re-entered CLI can recognise itself', async () => {
    const cli = await Bun.file(new URL('../../bin/cli.ts', import.meta.url)).text()
    // The marker has to be set on the spawn and checked at startup; either
    // half alone leaves the loop undiagnosed.
    expect(cli).toContain('CRAFT_CLI_SPAWN_MARKER')
    expect(cli).toContain('craftBinaryIsCliShimMessage')
    expect(cli.indexOf('craftBinaryIsCliShimMessage')).toBeLessThan(cli.indexOf('const cli = new CLI'))
  })

  it('names the offending PATH entry, since nothing else points at PATH', () => {
    const message = craftBinaryIsCliShimMessage('/Users/me/.bun/bin/craft')
    expect(message).toContain('/Users/me/.bun/bin/craft')
    expect(message).toContain('CRAFT_BIN')
    expect(message).toContain('pantry install craft')
    // Explains the symptom the user actually saw, not just the cause.
    expect(message).toContain('--url')
  })

  it('still resolves to the bare PATH name — the guard adds no probing', () => {
    const previous = process.env.CRAFT_BIN
    delete process.env.CRAFT_BIN
    try {
      expect(resolveCraftBinary()).toBe('craft')
    }
    finally {
      if (previous !== undefined) process.env.CRAFT_BIN = previous
    }
  })
})
