/**
 * Build Verification Script
 * Checks that all platform build outputs exist and are valid.
 */

import { existsSync, statSync } from 'node:fs'
import { join } from 'node:path'

const ROOT = join(import.meta.dir, '..')

interface BuildTarget {
  name: string
  path: string
  platform: 'desktop' | 'mobile' | 'web'
}

const targets: BuildTarget[] = [
  // Desktop (Zig core)
  { name: 'craft binary', path: 'packages/zig/zig-out/bin/craft', platform: 'desktop' },

  // TypeScript SDK
  { name: 'ts-craft SDK', path: 'packages/typescript/dist/index.js', platform: 'web' },

  // Mobile builders
  { name: 'iOS builder', path: 'packages/ios/dist/index.js', platform: 'mobile' },
  { name: 'Android builder', path: 'packages/android/dist/index.js', platform: 'mobile' },

  // Framework bindings
  { name: 'React bindings', path: 'packages/react/dist/index.mjs', platform: 'web' },
  { name: 'Vue bindings', path: 'packages/vue/dist/index.mjs', platform: 'web' },
  { name: 'Svelte bindings', path: 'packages/svelte/dist/index.mjs', platform: 'web' },
]

let passed = 0
let failed = 0

console.log('\n  Build Verification\n')

for (const target of targets) {
  const fullPath = join(ROOT, target.path)
  const exists = existsSync(fullPath)

  if (exists) {
    const stat = statSync(fullPath)
    const sizeKB = (stat.size / 1024).toFixed(1)
    console.log(`  [pass] ${target.name} (${sizeKB}KB) - ${target.platform}`)
    passed++
  }
  else {
    console.log(`  [fail] ${target.name} - ${target.path}`)
    failed++
  }
}

console.log(`\n  Results: ${passed} passed, ${failed} failed, ${targets.length} total\n`)

if (failed > 0) {
  console.log('  Run "bun run build:all" to build all targets.\n')
  process.exit(1)
}
