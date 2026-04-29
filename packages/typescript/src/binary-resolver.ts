/**
 * Locate the `craft` native binary.
 *
 * The shipping contract is: **Craft is distributed via the pantry
 * registry**. `pantry install craft` (or any pantry-managed environment
 * that includes craft) puts the binary on PATH; the SDK and CLI then
 * just spawn `'craft'` directly. The previous "look in zig-out, then
 * fall back to PATH" probing is gone — it was load-bearing in the
 * monorepo dev loop, but consumers of the SDK / CLI should never see it.
 *
 * Two escape hatches remain, in order of precedence:
 *
 *   1. `config.craftPath` (SDK only): an explicit absolute path the
 *      caller pinned. Validated to exist; otherwise we throw.
 *   2. `CRAFT_BIN` env var: same idea, useful for tests and for the
 *      monorepo dev loop where the binary lives at
 *      `packages/zig/zig-out/bin/craft` and isn't yet a registry build.
 *
 * Everything else delegates to `'craft'` and lets the OS resolve PATH.
 * If the spawn produces ENOENT we surface a single, deterministic error
 * pointing at pantry — no path probing, no matrix of "we tried these
 * locations" output, just one canonical answer.
 */

import { existsSync } from 'node:fs'

/**
 * Resolve a `craft` binary path.
 *
 * @param explicit Optional caller-supplied absolute path (e.g. SDK
 *   `AppConfig.craftPath`). Required to exist when present.
 * @returns The string to pass to `spawn(...)`. Either `explicit`,
 *   `process.env.CRAFT_BIN`, or the bare `'craft'` for PATH lookup.
 */
export function resolveCraftBinary(explicit?: string): string {
  if (explicit) {
    if (!existsSync(explicit)) {
      throw new Error(`Custom Craft binary path not found: ${explicit}`)
    }
    return explicit
  }
  const fromEnv = typeof process !== 'undefined' ? process.env.CRAFT_BIN : undefined
  if (fromEnv) {
    if (!existsSync(fromEnv)) {
      throw new Error(`CRAFT_BIN points to ${fromEnv}, which does not exist`)
    }
    return fromEnv
  }
  // PATH lookup. The OS resolves `'craft'` to whatever pantry installed.
  return 'craft'
}

/**
 * Build a deterministic, pantry-aware error for the case where the
 * spawn errored with ENOENT (binary not found on PATH). Used as the
 * `process.on('error', …)` handler in both the SDK and the CLI.
 */
export function craftBinaryNotFoundMessage(triedPath: string): string {
  return [
    `Craft native binary not found (tried "${triedPath}").`,
    '',
    'Craft ships through the pantry package registry. Install it with:',
    '',
    '  pantry install craft',
    '',
    'or, in a project, declare it in deps.yaml / pantry.jsonc and run',
    '  pantry install',
    '',
    'See https://pantry.dev/quickstart for pantry installation instructions.',
    'For monorepo development you can also point CRAFT_BIN at a local build.',
  ].join('\n')
}
