#!/usr/bin/env bun
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const zigRoot = join(root, 'packages/zig/src')
const allowed = new Set([
  'packages/zig/src/linux/dbus.zig',
  'packages/zig/src/linux/gtk4.zig',
])

const violations: string[] = []
const stack = [zigRoot]

while (stack.length > 0) {
  const dir = stack.pop()!
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry)
    const stat = statSync(path)
    if (stat.isDirectory()) {
      stack.push(path)
      continue
    }
    if (!entry.endsWith('.zig'))
      continue

    const rel = relative(root, path)
    const lines = readFileSync(path, 'utf-8').split('\n')
    lines.forEach((line, index) => {
      const code = line.split('//')[0]
      if (code.includes('@cImport') && !allowed.has(rel))
        violations.push(`${rel}:${index + 1}: ${line.trim()}`)
    })
  }
}

if (violations.length > 0) {
  console.error('Unexpected @cImport usage found:')
  for (const violation of violations)
    console.error(`  ${violation}`)
  process.exit(1)
}

console.log(`cImport audit passed (${allowed.size} documented Linux binding exceptions).`)
